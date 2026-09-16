// lib/core/services/media_access/media_access_service.dart
//
// Media access service abstraction (PRD §5.2).
//
// MediaStore is the ONLY storage access strategy for v1.
// No MANAGE_EXTERNAL_STORAGE, no direct file path access (DEV_PROMPT rule 7).
//
// This interface is the single seam between Flutter UI/domain code and the
// Android MediaStore platform channel. It is fully mockable for tests.

import 'media_item.dart';

/// Permission state for media access.
enum MediaPermissionState {
  /// All requested permissions granted.
  granted,

  /// No permission granted.
  denied,

  /// User has permanently denied (show settings redirect).
  permanentlyDenied,

  /// Android 14+ partial access (selected photos/videos only).
  /// App must show the partial-access banner wherever media is displayed
  /// (REQ-ONB-05).
  partial,
}

/// MediaStore query options.
class MediaQueryOptions {
  const MediaQueryOptions({
    this.sourceApps = const [
      'com.whatsapp',
      'com.whatsapp.w4b',
    ],
    this.includeVideos = true,
    this.includeImages = true,
    this.includeAudio = true,
    this.sinceModifiedEpochMs,
    this.generationModifiedSince,
  });

  /// Source app package names to filter by (REQ-IDX-01).
  final List<String> sourceApps;
  final bool includeVideos;
  final bool includeImages;
  final bool includeAudio;

  /// Only return files with date_modified after this timestamp (incremental).
  final int? sinceModifiedEpochMs;

  /// MediaStore generation counter for incremental scans (REQ-IDX-03).
  final int? generationModifiedSince;
}

/// Media access service interface.
///
/// Implementations:
///   [FakeMediaAccessService] (tests/dev — returns in-memory MediaItem list)
///   NativeMediaAccessService (Phase 3 — platform channel to Kotlin MediaStore)
abstract interface class MediaAccessService {
  /// Check current media permission state.
  Future<MediaPermissionState> checkPermission();

  /// Request media permissions. Returns the resulting state.
  Future<MediaPermissionState> requestPermission();

  /// Open device system settings so the user can grant permissions manually.
  Future<void> openAppSettings();

  /// Query indexed media items matching [options].
  ///
  /// Yields items in batches for progress reporting (REQ-IDX-05).
  Stream<List<MediaItem>> queryMedia(MediaQueryOptions options);

  /// Read the current MediaStore generation counter.
  /// Used to detect any change since the last scan (REQ-IDX-03).
  Future<int> currentGeneration();

  /// Trash a batch of items via [MediaStore.createTrashRequest] (API 30+)
  /// or [createDeleteRequest] on older APIs (REQ-ACT-01).
  ///
  /// Returns the content URIs that were successfully trashed/deleted.
  Future<List<String>> trashItems(List<String> contentUris);

  /// List currently trashed items (Android 11+ MediaStore IS_TRASHED).
  Stream<List<MediaItem>> queryTrashedItems();

  /// Restore trashed items (REQ-BIN-02).
  Future<List<String>> restoreItems(List<String> contentUris);
}
