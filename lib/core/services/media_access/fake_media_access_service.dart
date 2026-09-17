// lib/core/services/media_access/fake_media_access_service.dart
//
// In-memory media access service for tests and development.
// Starts with granted permission and an empty media list.
// Tests configure the permission state and seed media items as needed.

import 'dart:async';

import '../../../../features/clean/domain/action_models.dart';
import 'media_access_service.dart';
import 'media_item.dart';

final class FakeMediaAccessService implements MediaAccessService {
  /// Permission state returned by checkPermission / requestPermission.
  MediaPermissionState permissionState = MediaPermissionState.granted;

  /// Media items returned by queryMedia. Populate in tests.
  List<MediaItem> items = [];

  /// Trashed items returned by queryTrashedItems.
  List<MediaItem> trashedItems = [];

  /// Moved items recorded during move operations.
  List<MediaItem> movedItems = [];

  /// Copied items recorded during copy operations.
  List<MediaItem> copiedItems = [];

  /// Archived items recorded during archive operations.
  List<MediaItem> archivedItems = [];

  /// Simulated Android API level (30+ for Android 11+ / Trash, <= 29 for legacy delete).
  int simulatedApiLevel = 33;

  /// If true, operations throw to simulate permission loss mid-operation (REQ-ACT-04).
  bool simulatePermissionLossMidOperation = false;

  /// If true, simulate destination write failure (REQ-ACT-03).
  bool simulateWriteFailure = false;

  /// If true, simulate partial batch failure (REQ-ACT-04).
  bool simulatePartialFailure = false;

  int _generation = 1;

  @override
  Future<MediaPermissionState> checkPermission() async => permissionState;

  @override
  Future<MediaPermissionState> requestPermission() async => permissionState;

  @override
  Future<void> openAppSettings() async {
    // No-op in fake.
  }

  @override
  Stream<List<MediaItem>> queryMedia(MediaQueryOptions options) async* {
    yield items;
  }

  @override
  Future<int> currentGeneration() async => _generation;

  /// Increment generation to simulate new files appearing.
  void bumpGeneration() => _generation++;

  @override
  Future<List<String>> trashItems(List<String> contentUris) async {
    if (simulatePermissionLossMidOperation) {
      throw Exception('Permission lost mid-operation (simulated)');
    }
    final toTrash = items.where((i) => contentUris.contains(i.contentUri)).toList();
    items.removeWhere((i) => contentUris.contains(i.contentUri));
    trashedItems.addAll(toTrash);
    return contentUris;
  }

  @override
  Stream<List<MediaItem>> queryTrashedItems() async* {
    yield trashedItems;
  }

  @override
  Future<List<String>> restoreItems(List<String> contentUris) async {
    final toRestore = trashedItems.where((i) => contentUris.contains(i.contentUri)).toList();
    trashedItems.removeWhere((i) => contentUris.contains(i.contentUri));
    items.addAll(toRestore);
    return contentUris;
  }

  @override
  Future<List<String>> deletePermanently(List<String> contentUris) async {
    trashedItems.removeWhere((i) => contentUris.contains(i.contentUri));
    items.removeWhere((i) => contentUris.contains(i.contentUri));
    return contentUris;
  }

  @override
  Future<FileActionResult> moveOrCopyItems({
    required List<MediaItem> items,
    required bool isMove,
    bool isArchive = false,
    String? customDestination,
  }) async {
    if (simulatePermissionLossMidOperation) {
      throw Exception('Permission lost mid-operation (simulated)');
    }

    if (simulateWriteFailure) {
      // REQ-ACT-03: write fails -> destination removed, source untouched!
      return FileActionResult(
        failedIds: items.map((e) => e.mediaId.toString()).toList(),
        failureReasons: {
          for (final item in items) item.mediaId.toString(): 'Simulated destination write failure (byte mismatch)',
        },
      );
    }

    final succeededIds = <String>[];
    final failedIds = <String>[];
    final failureReasons = <String, String>{};
    var bytesProcessed = 0;

    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      final idStr = item.mediaId.toString();
      if (simulatePartialFailure && i >= items.length ~/ 2) {
        failedIds.add(idStr);
        failureReasons[idStr] = 'Storage full / write failed mid-batch';
        continue;
      }

      succeededIds.add(idStr);
      bytesProcessed += item.sizeBytes;

      if (isArchive) {
        archivedItems.add(item);
      } else if (isMove) {
        movedItems.add(item);
      } else {
        copiedItems.add(item);
      }

      // REQ-ACT-03: Remove from source only after verified write succeeded
      if (isMove) {
        this.items.removeWhere((it) => it.mediaId == item.mediaId);
      }
    }

    return FileActionResult(
      succeededIds: succeededIds,
      failedIds: failedIds,
      failureReasons: failureReasons,
      totalBytesProcessed: bytesProcessed,
    );
  }

  @override
  Future<int> getAndroidVersion() async => simulatedApiLevel;

  @override
  Future<bool> openMediaItem({required String contentUri, required String mimeType}) async {
    return true;
  }
}
