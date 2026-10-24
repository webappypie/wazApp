// lib/features/storage_manager/data/storage_service.dart
//
// Measures what WazApp stores and finds probable duplicates with explainable rules.
// It only ever looks at WazApp's own directories. Deleting is always a separate,
// explicit call made after the user confirmed the count and size.

import 'dart:io';
import 'dart:isolate';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;

import '../../../core/database/app_database.dart';
import '../../../core/logging/app_logger.dart';
import '../../library/data/library_service.dart';
import '../../library/data/library_storage.dart';
import '../../library/domain/library_models.dart';
import '../domain/storage_models.dart';

/// SHA-256 of a file, computed in a background isolate.
Future<String> sha256OfFile(String path) => Isolate.run(() async {
  final digest = await sha256.bind(File(path).openRead()).first;
  return digest.toString();
});

class DuplicateScan {
  const DuplicateScan({
    required this.groups,
    required this.filesHashed,
    required this.photosFingerprinted,
  });
  final List<DuplicateGroup> groups;
  final int filesHashed;
  final int photosFingerprinted;
}

class StorageService {
  StorageService({
    required this._db,
    required this._storage,
    required this._library,
    required this._tempDir,
    this.largeFileMinBytes = 1024 * 1024,
    this.largeFileLimit = 25,
  });

  final AppDatabase _db;
  final LibraryStorage _storage;
  final LibraryService _library;
  final Directory _tempDir;
  final int largeFileMinBytes;
  final int largeFileLimit;
  final Logger _log = AppLogger.get('StorageService');

  // ---------------------------------------------------------------------------
  // Usage report
  // ---------------------------------------------------------------------------

  Future<StorageReport> report() async {
    final rows = await _db.allRows();
    var photoCount = 0,
        photoBytes = 0,
        videoCount = 0,
        videoBytes = 0,
        privCount = 0,
        privBytes = 0;
    var thumbBytes = 0;
    final missing = <String>[];
    final bySource = <String, (int, int)>{};
    final large = <SavedMedia>[];
    final referenced = <String>{};

    for (final r in rows) {
      referenced.add(p.normalize(r.path));
      if (r.thumbnailPath != null) {
        referenced.add(p.normalize(r.thumbnailPath!));
        final t = File(r.thumbnailPath!);
        if (await t.exists()) thumbBytes += await t.length();
      }
      final f = File(r.path);
      if (!await f.exists()) {
        missing.add(r.id);
        continue;
      }
      final size = await f
          .length(); // real size on disk, not the stored metadata
      if (r.isPrivate) {
        privCount++;
        privBytes += size;
        continue;
      }
      if (r.mediaKind == MediaKind.video) {
        videoCount++;
        videoBytes += size;
      } else {
        photoCount++;
        photoBytes += size;
      }
      final prev = bySource[r.sourceType] ?? (0, 0);
      bySource[r.sourceType] = (prev.$1 + 1, prev.$2 + size);
      if (size >= largeFileMinBytes) large.add(r.copyWith(sizeBytes: size));
    }
    large.sort((a, b) => b.sizeBytes.compareTo(a.sizeBytes));

    final unreferenced = <UnreferencedFile>[];
    for (final dir in [
      _storage.mediaDir,
      _storage.privateDir,
      _storage.thumbsDir,
      _storage.privateThumbsDir,
    ]) {
      if (!await dir.exists()) continue;
      await for (final e in dir.list()) {
        if (e is! File) continue;
        if (!referenced.contains(p.normalize(e.path))) {
          unreferenced.add(UnreferencedFile(e.path, await e.length()));
        }
      }
    }

    return StorageReport(
      photos: SourceUsage(photoCount, photoBytes),
      videos: SourceUsage(videoCount, videoBytes),
      privateItems: SourceUsage(privCount, privBytes),
      thumbnailBytes: thumbBytes,
      tempBytes: await _dirBytes(_tempDir),
      unreferenced: unreferenced,
      missingIds: missing,
      bySource: {
        for (final e in bySource.entries)
          e.key: SourceUsage(e.value.$1, e.value.$2),
      },
      largeFiles: large.take(largeFileLimit).toList(),
    );
  }

  Future<int> _dirBytes(Directory d) async {
    if (!await d.exists()) return 0;
    var total = 0;
    await for (final e in d.list(recursive: true)) {
      if (e is File) total += await e.length();
    }
    return total;
  }

  // ---------------------------------------------------------------------------
  // Duplicates
  // ---------------------------------------------------------------------------

  /// Finds probable duplicates among NON-private items.
  ///  1. Group by kind + real file size (cheap).
  ///  2. Only files that share a size are hashed (SHA-256); equal hashes => [DuplicateReason.identical].
  ///  3. Photos not already in an identical group get a 64-bit visual fingerprint; photos with the same shape and
  ///     <= [kLookAlikeMaxHamming] differing bits => [DuplicateReason.lookAlike].
  /// Hashes are cached on the row (files are never edited in place).
  Future<DuplicateScan> findDuplicates({
    void Function(String stage, int done, int total)? onProgress,
    bool Function()? isCancelled,
  }) async {
    final rows = [
      for (final r in await _db.allRows())
        if (!r.isPrivate) r,
    ];
    final existing = <SavedMedia>[];
    final sizes = <String, int>{};
    for (final r in rows) {
      final f = File(r.path);
      if (await f.exists()) {
        existing.add(r);
        sizes[r.id] = await f.length();
      }
    }
    existing.sort((a, b) => a.savedAt.compareTo(b.savedAt));

    // 1+2: identical content.
    final bySize = <String, List<SavedMedia>>{};
    for (final r in existing) {
      bySize.putIfAbsent('${r.kind}:${sizes[r.id]}', () => []).add(r);
    }
    final candidates = [
      for (final g in bySize.values)
        if (g.length > 1) ...g,
    ];
    final byHash = <String, List<SavedMedia>>{};
    var hashed = 0;
    for (var i = 0; i < candidates.length; i++) {
      if (isCancelled?.call() ?? false) break;
      onProgress?.call('Comparing file contents', i, candidates.length);
      var r = candidates[i];
      var h = r.contentHash;
      if (h == null) {
        try {
          h = await sha256OfFile(r.path);
          await _db.setHashes(r.id, contentHash: h);
          hashed++;
        } on FileSystemException catch (e) {
          _log.warning('hash failed', e);
          continue;
        }
      }
      byHash.putIfAbsent('${r.kind}:$h', () => []).add(r);
    }
    final groups = <DuplicateGroup>[];
    final inIdentical = <String>{};
    for (final g in byHash.values) {
      if (g.length < 2) continue;
      groups.add(DuplicateGroup(reason: DuplicateReason.identical, items: g));
      inIdentical.addAll(g.map((m) => m.id));
    }

    // 3: look-alike photos (one representative per identical group so a triplicate is not double counted).
    final reps = <SavedMedia>[];
    final seenGroupRep = <String>{};
    for (final r in existing) {
      if (r.mediaKind != MediaKind.image) continue;
      if (inIdentical.contains(r.id)) {
        final key = byHash.entries
            .firstWhere((e) => e.value.any((m) => m.id == r.id))
            .key;
        if (!seenGroupRep.add(key)) {
          continue; // only the oldest of an identical group takes part
        }
      }
      reps.add(r);
    }
    final prints = <String, String>{};
    var fingerprinted = 0;
    for (var i = 0; i < reps.length; i++) {
      if (isCancelled?.call() ?? false) break;
      onProgress?.call('Comparing how photos look', i, reps.length);
      final r = reps[i];
      var v = r.visualHash;
      if (v == null) {
        v = await _visualHash(r.path);
        if (v == null) continue;
        await _db.setHashes(r.id, visualHash: v);
        fingerprinted++;
      }
      prints[r.id] = v;
    }
    // Union-find over pairs that match.
    final parent = {for (final r in reps) r.id: r.id};
    String find(String x) {
      while (parent[x] != x) {
        parent[x] = parent[parent[x]!]!;
        x = parent[x]!;
      }
      return x;
    }

    for (var i = 0; i < reps.length; i++) {
      for (var j = i + 1; j < reps.length; j++) {
        final a = reps[i], b = reps[j];
        final pa = prints[a.id], pb = prints[b.id];
        if (pa == null || pb == null) continue;
        if (!similarShape(a, b)) continue;
        if (hammingHex(pa, pb) <= kLookAlikeMaxHamming) {
          parent[find(a.id)] = find(b.id);
        }
      }
    }
    final clusters = <String, List<SavedMedia>>{};
    for (final r in reps) {
      if (prints[r.id] == null) continue;
      clusters.putIfAbsent(find(r.id), () => []).add(r);
    }
    for (final c in clusters.values) {
      if (c.length < 2) continue;
      // Only the oldest file of each identical group takes part, so a file is never suggested for deletion
      // twice (the identical extras are already covered by their own group).
      c.sort((a, b) => a.savedAt.compareTo(b.savedAt));
      groups.add(DuplicateGroup(reason: DuplicateReason.lookAlike, items: c));
    }

    groups.sort((a, b) => b.reclaimableBytes.compareTo(a.reclaimableBytes));
    return DuplicateScan(
      groups: groups,
      filesHashed: hashed,
      photosFingerprinted: fingerprinted,
    );
  }

  /// 8x8 difference hash of a photo (decoded at 9x8, so cheap and orientation-aware), or null if undecodable.
  Future<String?> _visualHash(String path) async {
    try {
      final bytes = await File(path).readAsBytes();
      final codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: 9,
        targetHeight: 8,
      );
      final image = (await codec.getNextFrame()).image;
      codec.dispose();
      try {
        final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
        if (data == null || image.width != 9 || image.height != 8) return null;
        final gray = List<int>.generate(72, (i) {
          final r = data.getUint8(i * 4),
              g = data.getUint8(i * 4 + 1),
              b = data.getUint8(i * 4 + 2);
          return (r * 299 + g * 587 + b * 114) ~/ 1000;
        });
        return dHashFromGray9x8(gray);
      } finally {
        image.dispose();
      }
    } catch (e) {
      _log.fine('visual hash skipped', e);
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Clean-up actions (each is called only after the user confirmed)
  // ---------------------------------------------------------------------------

  Future<DeleteResult> deleteItems(Iterable<String> ids) =>
      _library.delete(ids);

  /// Deletes files that no row refers to. Only paths inside WazApp's own directories are accepted.
  Future<({int deleted, int failed, int bytes})> deleteUnreferenced(
    Iterable<UnreferencedFile> files,
  ) async {
    final roots = [
      _storage.mediaDir,
      _storage.privateDir,
      _storage.thumbsDir,
      _storage.privateThumbsDir,
    ].map((d) => p.normalize(d.path)).toList();
    var deleted = 0, failed = 0, bytes = 0;
    for (final f in files) {
      final path = p.normalize(f.path);
      if (!roots.any((r) => p.isWithin(r, path))) {
        failed++;
        continue;
      }
      // Re-check: a row may have started to reference it since the report was made.
      final rows = await _db.allRows();
      if (rows.any(
        (r) =>
            p.normalize(r.path) == path ||
            (r.thumbnailPath != null && p.normalize(r.thumbnailPath!) == path),
      )) {
        failed++;
        continue;
      }
      try {
        final file = File(path);
        if (await file.exists()) {
          bytes += await file.length();
          await file.delete();
          deleted++;
        } // already gone: nothing was removed by this call, so it is not counted
      } on FileSystemException {
        failed++;
      }
    }
    return (deleted: deleted, failed: failed, bytes: bytes);
  }

  /// Removes library entries whose media file no longer exists (nothing on disk is touched).
  Future<int> removeBrokenEntries(Iterable<String> ids) async {
    var removed = 0;
    for (final id in ids) {
      final row = await _db.findById(id);
      if (row == null) continue;
      if (await File(row.path).exists()) continue; // came back; keep it
      removed += await _db.deleteByIds([id]);
    }
    return removed;
  }

  /// Deletes scratch files left by exports (safe: they are never library content).
  Future<int> clearTemp() async {
    if (!await _tempDir.exists()) return 0;
    var bytes = 0;
    await for (final e in _tempDir.list()) {
      try {
        if (e is File) bytes += await e.length();
        await e.delete(recursive: true);
      } on FileSystemException catch (err) {
        _log.warning('temp cleanup failed', err);
      }
    }
    return bytes;
  }
}
