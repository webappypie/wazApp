// lib/features/library/data/library_service.dart
//
// Application service for the local library: save a status, import a picked
// file, delete, favourite, export. Every write follows
//   source -> copy to temp -> verify -> finalise -> persist metadata,
// and any failure after the file exists rolls the file back, so the library
// never contains a row without a valid file (or the reverse).

import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;

import '../../../core/database/app_database.dart';
import '../../../core/error/app_error.dart';
import '../../../core/logging/app_logger.dart';
import '../../status/data/status_access_service.dart';
import '../../status/domain/status_models.dart';
import '../domain/library_models.dart';
import 'library_storage.dart';
import 'media_probe.dart';

/// A file picked by the user from Photos/Files.
class ImportCandidate {
  const ImportCandidate({required this.path, required this.name, this.mimeType});
  final String path;
  final String name;
  final String? mimeType;
}

class ItemFailure<T> {
  const ItemFailure(this.item, this.error);
  final T item;
  final AppError error;
}

class SaveBatchResult {
  const SaveBatchResult({
    required this.saved,
    required this.alreadySaved,
    required this.failed,
    required this.cancelled,
  });

  final List<SavedMedia> saved;
  final List<StatusItem> alreadySaved;
  final List<ItemFailure<StatusItem>> failed;
  final bool cancelled;

  bool get hasFailures => failed.isNotEmpty;
}

class ImportBatchResult {
  const ImportBatchResult({required this.imported, required this.failed});
  final List<SavedMedia> imported;
  final List<ItemFailure<ImportCandidate>> failed;
}

class DeleteResult {
  const DeleteResult({required this.deleted, required this.failedIds});
  final int deleted;
  final List<String> failedIds;
}

class LibraryService {
  LibraryService({
    required this._db,
    required this._storage,
    required this._status,
    required this._tools,
    this._probe = const FlutterMediaProbe(),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final AppDatabase _db;
  final LibraryStorage _storage;
  final StatusAccessService _status;
  final MediaTools _tools;
  final MediaProbe _probe;
  final DateTime Function() _clock;
  final Logger _log = AppLogger.get('LibraryService');

  static const _imageExt = {'jpg', 'jpeg', 'png', 'webp', 'gif', 'heic', 'heif', 'bmp'};
  static const _videoExt = {'mp4', 'm4v', 'mov', '3gp', 'mkv', 'webm'};

  /// Detects the media kind from MIME type, falling back to the extension.
  static MediaKind? kindFor({String? mimeType, required String name}) {
    if (mimeType != null) {
      if (mimeType.startsWith('image/')) return MediaKind.image;
      if (mimeType.startsWith('video/')) return MediaKind.video;
    }
    final ext = p.extension(name).replaceFirst('.', '').toLowerCase();
    if (_imageExt.contains(ext)) return MediaKind.image;
    if (_videoExt.contains(ext)) return MediaKind.video;
    return null;
  }

  // ---------------------------------------------------------------------------
  // Save status
  // ---------------------------------------------------------------------------

  /// Saves one status into the library. Returns the existing row (and
  /// `created == false`) if this exact status was already saved.
  Future<({SavedMedia media, bool created})> saveStatus(StatusItem item) async {
    final existing = await _db.findBySourceKey(item.sourceKey);
    if (existing != null && await File(existing.path).exists()) {
      return (media: existing, created: false);
    }
    if (existing != null) {
      // Stale row (file vanished): drop it so the status can be saved again.
      await _db.deleteByIds([existing.id]);
    }

    await _storage.ensureCreated();
    final id = _storage.newId();
    final dest = _storage.mediaPath(id, item.extension);
    String? thumb;
    try {
      final info = await _status.copyToFile(item, dest);
      thumb = await _makeThumbnail(id, dest, item.kind);
      await _insert(
        id: id,
        path: dest,
        kind: item.kind,
        mimeType: item.mimeType,
        fileName: item.name,
        info: info,
        sourceType: SourceType.status,
        sourceApp: item.app.key,
        sourceKey: item.sourceKey,
        originalAt: item.modified,
        thumbnailPath: thumb,
      );
    } catch (e) {
      await _discard(dest, thumb);
      if (e is AppError) rethrow;
      _log.warning('saveStatus failed', e);
      throw DatabaseError(message: 'Could not save this item.', cause: e);
    }
    return (media: (await _db.findById(id))!, created: true);
  }

  /// Saves many statuses sequentially with progress and cooperative cancel.
  /// One failing item never aborts the rest (partial failure is reported).
  Future<SaveBatchResult> saveStatuses(
    List<StatusItem> items, {
    void Function(int done, int total)? onProgress,
    bool Function()? isCancelled,
  }) async {
    final saved = <SavedMedia>[];
    final already = <StatusItem>[];
    final failed = <ItemFailure<StatusItem>>[];
    var cancelled = false;
    for (var i = 0; i < items.length; i++) {
      if (isCancelled?.call() ?? false) {
        cancelled = true;
        break;
      }
      try {
        final r = await saveStatus(items[i]);
        (r.created ? saved : already).add(r.created ? r.media : items[i]);
      } on AppError catch (e) {
        failed.add(ItemFailure(items[i], e));
      }
      onProgress?.call(i + 1, items.length);
    }
    return SaveBatchResult(saved: saved, alreadySaved: already, failed: failed, cancelled: cancelled);
  }

  // ---------------------------------------------------------------------------
  // Import (Photos / Files pickers; works on Android and iOS)
  // ---------------------------------------------------------------------------

  Future<ImportBatchResult> importFiles(
    List<ImportCandidate> files, {
    void Function(int done, int total)? onProgress,
    bool Function()? isCancelled,
  }) async {
    final imported = <SavedMedia>[];
    final failed = <ItemFailure<ImportCandidate>>[];
    await _storage.ensureCreated();
    for (var i = 0; i < files.length; i++) {
      if (isCancelled?.call() ?? false) break;
      try {
        imported.add(await _importOne(files[i]));
      } on AppError catch (e) {
        failed.add(ItemFailure(files[i], e));
      }
      onProgress?.call(i + 1, files.length);
    }
    return ImportBatchResult(imported: imported, failed: failed);
  }

  Future<SavedMedia> _importOne(ImportCandidate c) async {
    final kind = kindFor(mimeType: c.mimeType, name: c.name);
    if (kind == null) {
      throw const MediaAccessError(MediaFailure.corrupt,
          message: 'This file type is not supported. Choose a photo or video.');
    }
    final src = File(c.path);
    if (!await src.exists()) {
      throw const MediaAccessError(MediaFailure.sourceUnavailable,
          message: 'This item is no longer available.');
    }
    final id = _storage.newId();
    var ext = p.extension(c.name).replaceFirst('.', '').toLowerCase();
    if (ext.isEmpty) ext = kind == MediaKind.video ? 'mp4' : 'jpg';
    final dest = _storage.mediaPath(id, ext);
    final tmp = File('$dest.part');
    String? thumb;
    try {
      final srcLen = await src.length();
      if (srcLen <= 0) {
        throw const MediaAccessError(MediaFailure.corrupt, message: 'The file is empty.');
      }
      await src.copy(tmp.path);
      if (await tmp.length() != srcLen) {
        throw const MediaAccessError(MediaFailure.verifyFailed,
            message: 'The copy could not be verified. Nothing was imported.');
      }
      await tmp.rename(dest);
      final info = await _probe.probe(dest, kind);
      thumb = await _makeThumbnail(id, dest, kind);
      await _insert(
        id: id,
        path: dest,
        kind: kind,
        mimeType: c.mimeType ?? _mimeFor(kind, ext),
        fileName: c.name,
        info: info,
        sourceType: SourceType.imported,
        thumbnailPath: thumb,
      );
    } on FileSystemException catch (e) {
      await _discard(dest, thumb);
      await _deleteQuietly(tmp);
      final low = (e.osError?.errorCode == 28) || e.message.contains('No space');
      throw MediaAccessError(
        low ? MediaFailure.lowStorage : MediaFailure.unknown,
        message: low ? 'Not enough free storage on this device.' : 'Could not import this item.',
        cause: e,
      );
    } catch (e) {
      await _discard(dest, thumb);
      await _deleteQuietly(tmp);
      if (e is AppError) rethrow;
      throw DatabaseError(message: 'Could not import this item.', cause: e);
    }
    return (await _db.findById(id))!;
  }

  // ---------------------------------------------------------------------------
  // Files produced by WazApp itself (edited photos, text statuses)
  // ---------------------------------------------------------------------------

  /// Moves a finished output at [tempPath] into the library after verifying it.
  ///
  /// The file is decoded; if [expectedWidth]/[expectedHeight] are given they must
  /// match exactly. On any failure nothing is added and the library copy is removed
  /// (the caller keeps ownership of [tempPath] and must delete it).
  Future<SavedMedia> addCreatedFile(
    String tempPath, {
    required String fileName,
    required String mimeType,
    required MediaKind kind,
    required SourceType sourceType,
    int? expectedWidth,
    int? expectedHeight,
  }) async {
    assert(sourceType == SourceType.created || sourceType == SourceType.edited);
    await _storage.ensureCreated();
    final id = _storage.newId();
    final ext = p.extension(tempPath).replaceFirst('.', '').toLowerCase();
    final dest = _storage.mediaPath(id, ext.isEmpty ? (kind == MediaKind.video ? 'mp4' : 'jpg') : ext);
    final part = File('$dest.part');
    String? thumb;
    try {
      await File(tempPath).copy(part.path);
      if (await part.length() != await File(tempPath).length()) {
        throw const MediaAccessError(MediaFailure.verifyFailed,
            message: 'The saved file could not be verified.');
      }
      await part.rename(dest);
      final info = await _probe.probe(dest, kind);
      if ((expectedWidth != null && info.width != expectedWidth) ||
          (expectedHeight != null && info.height != expectedHeight)) {
        throw const MediaAccessError(MediaFailure.verifyFailed,
            message: 'The exported file did not match the expected size.');
      }
      thumb = await _makeThumbnail(id, dest, kind);
      await _db.insertMedia(SavedMediaTableCompanion.insert(
        id: id,
        path: dest,
        kind: kind.name,
        mimeType: mimeType,
        fileName: fileName,
        sizeBytes: info.sizeBytes,
        savedAt: _clock(),
        sourceType: sourceType.name,
        width: Value(info.width),
        height: Value(info.height),
        durationMs: Value(info.durationMs),
        isEdited: Value(sourceType == SourceType.edited),
        thumbnailPath: Value(thumb),
      ));
    } on FileSystemException catch (e) {
      await _discard(dest, thumb);
      await _deleteQuietly(part);
      final low = (e.osError?.errorCode == 28) || e.message.contains('No space');
      throw MediaAccessError(
        low ? MediaFailure.lowStorage : MediaFailure.unknown,
        message: low ? 'Not enough free storage on this device.' : 'Could not save the result.',
        cause: e,
      );
    } catch (e) {
      await _discard(dest, thumb);
      await _deleteQuietly(part);
      if (e is AppError) rethrow;
      throw DatabaseError(message: 'Could not save the result.', cause: e);
    }
    return (await _db.findById(id))!;
  }

  // ---------------------------------------------------------------------------
  // Mutations
  // ---------------------------------------------------------------------------

  Future<void> setFavourite(Iterable<String> ids, bool value) => _db.setFavourite(ids, value);

  /// Deletes library items (files first, then rows). Only call after the user
  /// confirmed the count/scope. A row is kept if its file could not be removed.
  Future<DeleteResult> delete(Iterable<String> ids) async {
    final idList = ids.toList();
    var deleted = 0;
    final failed = <String>[];
    for (final id in idList) {
      final row = await _db.findById(id);
      if (row == null) continue;
      try {
        // The media file is the source of truth: if it cannot be removed the row stays,
        // so the library never shows a row without a file (or the reverse).
        await _deleteIfExists(File(row.path));
      } on FileSystemException catch (e) {
        _log.warning('delete failed', e);
        failed.add(id);
        continue;
      }
      await _db.deleteByIds([id]);
      deleted++;
      if (row.thumbnailPath != null) {
        // Best effort; orphaned thumbnails are swept by [reconcile].
        await _deleteQuietly(File(row.thumbnailPath!));
      }
    }
    return DeleteResult(deleted: deleted, failedIds: failed);
  }

  /// Explicit export to the public gallery (user action).
  Future<void> exportToGallery(SavedMedia media) async {
    if (!await File(media.path).exists()) {
      throw const MediaAccessError(MediaFailure.sourceUnavailable,
          message: 'This item is no longer available.');
    }
    await _tools.exportToGallery(
      path: media.path,
      mimeType: media.mimeType,
      displayName: media.fileName,
      kind: media.mediaKind,
    );
  }

  /// Rows whose file is gone (user cleared storage, interrupted write).
  Future<List<String>> findMissingFileIds() async {
    final rows = await _db.select(_db.savedMediaTable).get();
    return [
      for (final r in rows)
        if (!await File(r.path).exists()) r.id,
    ];
  }

  /// Removes metadata rows whose files no longer exist and stale temp files.
  Future<int> reconcile() async {
    await _storage.cleanPartialFiles();
    final missing = await findMissingFileIds();
    final removed = missing.isEmpty ? 0 : await _db.deleteByIds(missing);
    await _sweepOrphanThumbnails();
    return removed;
  }

  Future<void> _sweepOrphanThumbnails() async {
    if (!await _storage.thumbsDir.exists()) return;
    final known = {
      for (final r in await _db.select(_db.savedMediaTable).get())
        if (r.thumbnailPath != null) p.normalize(r.thumbnailPath!),
    };
    await for (final e in _storage.thumbsDir.list()) {
      if (e is File && !known.contains(p.normalize(e.path))) await _deleteQuietly(e);
    }
  }

  // ---------------------------------------------------------------------------
  // Internals
  // ---------------------------------------------------------------------------

  Future<String?> _makeThumbnail(String id, String path, MediaKind kind) async {
    if (kind != MediaKind.video) return null; // images are decoded with a bounded cacheWidth
    try {
      final bytes = await _tools.thumbnail(path, kind);
      if (bytes == null || bytes.isEmpty) return null;
      final out = File(_storage.thumbPath(id));
      await out.writeAsBytes(bytes, flush: true);
      return out.path;
    } catch (e) {
      _log.fine('thumbnail skipped', e);
      return null;
    }
  }

  Future<void> _insert({
    required String id,
    required String path,
    required MediaKind kind,
    required String mimeType,
    required String fileName,
    required FileInfo info,
    required SourceType sourceType,
    String? sourceApp,
    String? sourceKey,
    DateTime? originalAt,
    String? thumbnailPath,
  }) =>
      _db.insertMedia(SavedMediaTableCompanion.insert(
        id: id,
        path: path,
        kind: kind.name,
        mimeType: mimeType,
        fileName: fileName,
        sizeBytes: info.sizeBytes,
        savedAt: _clock(),
        sourceType: sourceType.name,
        originalAt: Value(originalAt),
        sourceApp: Value(sourceApp),
        sourceKey: Value(sourceKey),
        width: Value(info.width),
        height: Value(info.height),
        durationMs: Value(info.durationMs),
        thumbnailPath: Value(thumbnailPath),
      ));

  String _mimeFor(MediaKind kind, String ext) {
    if (kind == MediaKind.video) return ext == 'mov' ? 'video/quicktime' : 'video/$ext';
    return switch (ext) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'heic' || 'heif' => 'image/heic',
      _ => 'image/$ext',
    };
  }

  Future<void> _discard(String path, String? thumb) async {
    await _deleteQuietly(File(path));
    await _deleteQuietly(File('$path.part'));
    if (thumb != null) await _deleteQuietly(File(thumb));
  }

  Future<void> _deleteQuietly(File f) async {
    try {
      if (await f.exists()) await f.delete();
    } on FileSystemException catch (e) {
      _log.fine('cleanup failed', e);
    }
  }

  Future<void> _deleteIfExists(File f) async {
    if (await f.exists()) await f.delete();
  }
}
