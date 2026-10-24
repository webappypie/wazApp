// lib/core/services/media_access/real_media_access_service.dart
//
// Real implementation of MediaAccessService for Android.
// Handles Android runtime permissions via permission_handler and file operations
// via platform channel com.wapptidy/media_actions.

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

import '../../../../features/clean/domain/action_models.dart';
import 'media_access_service.dart';
import 'media_item.dart';

class RealMediaAccessService implements MediaAccessService {
  RealMediaAccessService({
    MethodChannel? actionsChannel,
  }) : _actionsChannel = actionsChannel ?? const MethodChannel('com.wapptidy/media_actions');

  final MethodChannel _actionsChannel;

  @override
  Future<MediaPermissionState> checkPermission() async {
    if (!Platform.isAndroid) {
      return MediaPermissionState.granted;
    }

    try {
      // 1. Check Android 14+ visual user selected / partial access
      final photosStatus = await ph.Permission.photos.status;
      final videosStatus = await ph.Permission.videos.status;

      if (photosStatus.isLimited || videosStatus.isLimited) {
        return MediaPermissionState.limited;
      }

      // 2. Check Android 13+ granular media permissions
      if (photosStatus.isGranted || videosStatus.isGranted) {
        return MediaPermissionState.granted;
      }

      // 3. Check Android 12 and below storage permission
      final storageStatus = await ph.Permission.storage.status;
      if (storageStatus.isGranted) {
        return MediaPermissionState.granted;
      }
      if (storageStatus.isLimited) {
        return MediaPermissionState.limited;
      }

      if (photosStatus.isPermanentlyDenied || storageStatus.isPermanentlyDenied) {
        return MediaPermissionState.permanentlyDenied;
      }

      if (photosStatus.isRestricted || storageStatus.isRestricted) {
        return MediaPermissionState.restricted;
      }

      return MediaPermissionState.denied;
    } catch (_) {
      return MediaPermissionState.denied;
    }
  }

  @override
  Future<MediaPermissionState> requestPermission() async {
    if (!Platform.isAndroid) {
      return MediaPermissionState.granted;
    }

    try {
      // Request all relevant media and storage permissions across Android versions
      final statuses = await [
        ph.Permission.photos,
        ph.Permission.videos,
        ph.Permission.audio,
        ph.Permission.storage,
      ].request();

      final photos = statuses[ph.Permission.photos] ?? ph.PermissionStatus.denied;
      final videos = statuses[ph.Permission.videos] ?? ph.PermissionStatus.denied;
      final audio = statuses[ph.Permission.audio] ?? ph.PermissionStatus.denied;
      final storage = statuses[ph.Permission.storage] ?? ph.PermissionStatus.denied;

      if (photos.isLimited || videos.isLimited || storage.isLimited) {
        return MediaPermissionState.limited;
      }

      if (photos.isGranted || videos.isGranted || audio.isGranted || storage.isGranted) {
        return MediaPermissionState.granted;
      }

      if (photos.isPermanentlyDenied || storage.isPermanentlyDenied) {
        return MediaPermissionState.permanentlyDenied;
      }

      if (photos.isRestricted || storage.isRestricted) {
        return MediaPermissionState.restricted;
      }

      return MediaPermissionState.denied;
    } catch (_) {
      return MediaPermissionState.denied;
    }
  }

  @override
  Future<void> openAppSettings() async {
    await ph.openAppSettings();
  }

  @override
  Stream<List<MediaItem>> queryMedia(MediaQueryOptions options) async* {
    // Primary query is driven by MediaIndexer / RealIndexingRepository
    yield [];
  }

  @override
  Future<int> currentGeneration() async {
    try {
      final res = await _actionsChannel.invokeMethod<int>('currentGeneration');
      return res ?? 0;
    } catch (_) {
      return 0;
    }
  }

  @override
  Future<List<String>> trashItems(List<String> contentUris) async {
    try {
      final res = await _actionsChannel.invokeListMethod<String>('trashItems', {
        'uris': contentUris,
        'isTrash': true,
      });
      return res ?? [];
    } catch (_) {
      return [];
    }
  }

  @override
  Stream<List<MediaItem>> queryTrashedItems() async* {
    try {
      final raw = await _actionsChannel.invokeListMethod<Map<dynamic, dynamic>>('queryTrashedItems');
      if (raw != null) {
        final items = raw.map((m) {
          final map = Map<String, dynamic>.from(m);
          final sourceApp = map['sourceApp']?.toString() ?? 'com.whatsapp';
          return MediaItem(
            mediaId: (map['mediaStoreId'] as num?)?.toInt() ?? 0,
            contentUri: map['contentUri']?.toString() ?? '',
            mimeType: map['mimeType']?.toString() ?? '',
            sizeBytes: (map['sizeBytes'] as num?)?.toInt() ?? 0,
            dateAddedEpochSec: (map['dateAddedSec'] as num?)?.toInt() ?? 0,
            dateModifiedEpochSec: (map['dateModifiedSec'] as num?)?.toInt() ?? 0,
            folderBucket: map['bucketName']?.toString() ?? '',
            source: MediaSource.fromPackageName(sourceApp),
          );
        }).toList();
        yield items;
      } else {
        yield [];
      }
    } catch (_) {
      yield [];
    }
  }

  @override
  Future<List<String>> restoreItems(List<String> contentUris) async {
    try {
      final res = await _actionsChannel.invokeListMethod<String>('trashItems', {
        'uris': contentUris,
        'isTrash': false,
      });
      return res ?? [];
    } catch (_) {
      return [];
    }
  }

  @override
  Future<List<String>> deletePermanently(List<String> contentUris) async {
    try {
      final res = await _actionsChannel.invokeListMethod<String>('deletePermanently', {
        'uris': contentUris,
      });
      return res ?? [];
    } catch (_) {
      return [];
    }
  }

  @override
  Future<FileActionResult> moveOrCopyItems({
    required List<MediaItem> items,
    required bool isMove,
    bool isArchive = false,
    String? customDestination,
  }) async {
    try {
      final rawItems = items.map((it) => {
        'contentUri': it.contentUri,
        'displayName': it.contentUri.split('/').last,
        'mimeType': it.mimeType,
        'sizeBytes': it.sizeBytes,
        'dateModifiedSec': it.dateModifiedEpochSec,
        'sourceApp': it.source.packageName,
      }).toList();

      final res = await _actionsChannel.invokeMapMethod<String, dynamic>('moveOrCopyItems', {
        'items': rawItems,
        'isMove': isMove,
        'isArchive': isArchive,
        if (customDestination != null) 'customDestination': customDestination,
      });

      if (res != null) {
        final succeeded = (res['succeededUris'] as List<dynamic>?)?.cast<String>() ?? [];
        final failed = (res['failedUris'] as List<dynamic>?)?.cast<String>() ?? [];
        final rawReasons = (res['failureReasons'] as Map<dynamic, dynamic>?) ?? {};
        final failureReasons = rawReasons.map((k, v) => MapEntry(k.toString(), v.toString()));
        final bytes = (res['bytesProcessed'] as num?)?.toInt() ?? 0;

        return FileActionResult(
          succeededIds: succeeded,
          failedIds: failed,
          failureReasons: failureReasons,
          totalBytesProcessed: bytes,
        );
      }
    } catch (e) {
      return FileActionResult(
        failedIds: items.map((i) => i.contentUri).toList(),
        failureReasons: {for (final i in items) i.contentUri: e.toString()},
      );
    }

    return const FileActionResult();
  }

  @override
  Future<int> getAndroidVersion() async {
    try {
      final ver = await _actionsChannel.invokeMethod<int>('getAndroidVersion');
      return ver ?? 33;
    } catch (_) {
      return 33;
    }
  }

  @override
  Future<bool> openMediaItem({required String contentUri, required String mimeType}) async {
    try {
      final res = await _actionsChannel.invokeMethod<bool>('openMedia', {
        'uri': contentUri,
        'mimeType': mimeType,
      });
      return res ?? false;
    } catch (_) {
      return false;
    }
  }
}
