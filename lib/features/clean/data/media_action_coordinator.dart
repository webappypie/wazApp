// lib/features/clean/data/media_action_coordinator.dart
//
// Single coordinator for safe media actions (REQ-ACT-01 to REQ-ACT-07).
// Enforces:
//   - REQ-ACT-03: Write first, verify bytes, only then mutate database or delete source.
//   - REQ-ACT-05: Protected items excluded from deletion without explicit unprotect.
//   - REQ-ACT-07: Cleanup session bookkeeping (recovered bytes, counts).

import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart' hide MediaItem;
import '../../../core/services/media_access/media_access_service.dart';
import '../../../core/services/media_access/media_item.dart';
import '../domain/action_models.dart';
import '../domain/category_models.dart';

class ProtectedFileException implements Exception {
  final String message;
  const ProtectedFileException([this.message = 'Protected files cannot be deleted. Unprotect first.']);
  @override
  String toString() => message;
}

class MediaActionCoordinator {
  MediaActionCoordinator({
    required this.mediaAccessService,
    this.db,
  });

  final MediaAccessService mediaAccessService;
  final AppDatabase? db;

  CleanupSessionSummary _sessionSummary = const CleanupSessionSummary();
  CleanupSessionSummary get sessionSummary => _sessionSummary;

  void resetSession() {
    _sessionSummary = const CleanupSessionSummary();
  }

  /// Trashes selected items via MediaStore (REQ-ACT-01, REQ-ACT-02).
  ///
  /// Enforces REQ-ACT-05: Throws [ProtectedFileException] if any item is protected.
  Future<CleanupSessionSummary> trashSelected(List<CategoryItem> items) async {
    final protectedItems = items.where((e) => e.isProtected).toList();
    if (protectedItems.isNotEmpty) {
      throw const ProtectedFileException();
    }

    final uris = items.map((e) => e.contentUri).toList();
    final trashedUris = await mediaAccessService.trashItems(uris);

    if (trashedUris.isNotEmpty && db != null) {
      final database = db!;
      await (database.delete(database.mediaItems)
            ..where((tbl) => tbl.contentUri.isIn(trashedUris)))
          .go();
    }

    final trashedItems = items.where((e) => trashedUris.contains(e.contentUri)).toList();
    final bytesRecovered = trashedItems.fold(0, (sum, e) => sum + e.sizeBytes);

    _sessionSummary = CleanupSessionSummary(
      recoveredBytes: _sessionSummary.recoveredBytes + bytesRecovered,
      reviewedCount: _sessionSummary.reviewedCount + items.length,
      removedCount: _sessionSummary.removedCount + trashedUris.length,
      movedCount: _sessionSummary.movedCount,
      protectedCount: _sessionSummary.protectedCount,
    );

    return _sessionSummary;
  }

  /// Permanently deletes selected items (REQ-BIN-02).
  Future<CleanupSessionSummary> deletePermanentlySelected(List<CategoryItem> items) async {
    final protectedItems = items.where((e) => e.isProtected).toList();
    if (protectedItems.isNotEmpty) {
      throw const ProtectedFileException();
    }

    final uris = items.map((e) => e.contentUri).toList();
    final deletedUris = await mediaAccessService.deletePermanently(uris);

    if (deletedUris.isNotEmpty && db != null) {
      final database = db!;
      await (database.delete(database.mediaItems)
            ..where((tbl) => tbl.contentUri.isIn(deletedUris)))
          .go();
    }

    final deletedItems = items.where((e) => deletedUris.contains(e.contentUri)).toList();
    final bytesRecovered = deletedItems.fold(0, (sum, e) => sum + e.sizeBytes);

    _sessionSummary = CleanupSessionSummary(
      recoveredBytes: _sessionSummary.recoveredBytes + bytesRecovered,
      reviewedCount: _sessionSummary.reviewedCount + items.length,
      removedCount: _sessionSummary.removedCount + deletedUris.length,
      movedCount: _sessionSummary.movedCount,
      protectedCount: _sessionSummary.protectedCount,
    );

    return _sessionSummary;
  }

  /// Toggles protection flag for items (REQ-ACT-05).
  Future<void> setProtection(List<CategoryItem> items, bool isProtected) async {
    if (items.isEmpty) return;

    if (db != null) {
      final database = db!;
      final uris = items.map((e) => e.contentUri).toList();
      await (database.update(database.mediaItems)
            ..where((tbl) => tbl.contentUri.isIn(uris)))
          .write(MediaItemsCompanion(isProtected: Value(isProtected)));
    }

    _sessionSummary = CleanupSessionSummary(
      recoveredBytes: _sessionSummary.recoveredBytes,
      reviewedCount: _sessionSummary.reviewedCount,
      removedCount: _sessionSummary.removedCount,
      movedCount: _sessionSummary.movedCount,
      protectedCount: _sessionSummary.protectedCount + (isProtected ? items.length : -items.length),
    );
  }

  /// Move, Copy, or Archive items with strict byte verification (REQ-ACT-03, REQ-ACT-04, REQ-ACT-06).
  Future<FileActionResult> moveOrCopySelected({
    required List<CategoryItem> items,
    required bool isMove,
    bool isArchive = false,
    String? customDestination,
  }) async {
    final mediaItems = items.map((cat) => MediaItem(
      mediaId: int.tryParse(cat.id) ?? 0,
      contentUri: cat.contentUri,
      mimeType: cat.mimeType,
      source: MediaSource.fromPackageName(cat.sourceApp),
      folderBucket: cat.bucketName,
      sizeBytes: cat.sizeBytes,
      width: cat.width,
      height: cat.height,
      durationMs: cat.durationMs,
      dateAddedEpochSec: cat.dateAddedSec,
      dateModifiedEpochSec: cat.dateModifiedSec,
    )).toList();

    final result = await mediaAccessService.moveOrCopyItems(
      items: mediaItems,
      isMove: isMove,
      isArchive: isArchive,
      customDestination: customDestination,
    );

    // REQ-ACT-03: Mutate database only for items whose writes succeeded and bytes verified
    if (isMove && result.succeededIds.isNotEmpty && db != null) {
      final database = db!;
      final succeededUris = items
          .where((cat) => result.succeededIds.contains(cat.id))
          .map((cat) => cat.contentUri)
          .toList();

      await (database.delete(database.mediaItems)
            ..where((tbl) => tbl.contentUri.isIn(succeededUris)))
          .go();
    }

    _sessionSummary = CleanupSessionSummary(
      recoveredBytes: _sessionSummary.recoveredBytes + (isMove ? result.totalBytesProcessed : 0),
      reviewedCount: _sessionSummary.reviewedCount + items.length,
      removedCount: _sessionSummary.removedCount,
      movedCount: _sessionSummary.movedCount + (isMove ? result.succeededCount : 0),
      protectedCount: _sessionSummary.protectedCount,
    );

    return result;
  }

  /// Restores items from the Recycle Bin (REQ-BIN-02, REQ-BIN-03).
  /// Note: Guaranteed never to depend on ad or purchase state.
  Future<List<String>> restoreSelected(List<CategoryItem> items) async {
    final uris = items.map((e) => e.contentUri).toList();
    return await mediaAccessService.restoreItems(uris);
  }

  /// Get device Android API version.
  Future<int> getAndroidVersion() async {
    return await mediaAccessService.getAndroidVersion();
  }

  /// Launches system viewer for a document or media item (P-01).
  Future<bool> openMediaItem({required String contentUri, required String mimeType}) async {
    return await mediaAccessService.openMediaItem(
      contentUri: contentUri,
      mimeType: mimeType,
    );
  }
}
