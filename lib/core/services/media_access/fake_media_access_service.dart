// lib/core/services/media_access/fake_media_access_service.dart
//
// In-memory media access service for tests and development.
// Starts with granted permission and an empty media list.
// Tests configure the permission state and seed media items as needed.

import 'dart:async';

import 'media_access_service.dart';
import 'media_item.dart';

final class FakeMediaAccessService implements MediaAccessService {
  /// Permission state returned by checkPermission / requestPermission.
  MediaPermissionState permissionState = MediaPermissionState.granted;

  /// Media items returned by queryMedia. Populate in tests.
  List<MediaItem> items = [];

  /// Trashed items returned by queryTrashedItems.
  List<MediaItem> trashedItems = [];

  /// If true, trashItems / restoreItems throw to simulate permission loss.
  bool simulatePermissionLossMidOperation = false;

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
    // Yield in one batch. Real impl yields in smaller batches for progress.
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
    items.removeWhere((i) => contentUris.contains(i.contentUri));
    return contentUris;
  }

  @override
  Stream<List<MediaItem>> queryTrashedItems() async* {
    yield trashedItems;
  }

  @override
  Future<List<String>> restoreItems(List<String> contentUris) async {
    return contentUris;
  }
}
