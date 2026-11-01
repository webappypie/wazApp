// lib/features/status/data/status_access_service.dart
//
// Dart side of the native status-access bridge (Android only).
// iOS cannot read another app's storage, so there [UnsupportedStatusAccessService]
// is used and the UI offers Photos/Files import instead.

import 'dart:io' show Platform;

import 'package:flutter/services.dart';

import '../../../core/error/app_error.dart';
import '../../library/domain/library_models.dart';
import '../domain/status_models.dart';

abstract interface class StatusAccessService {
  /// True when this platform can read WhatsApp status folders at all.
  bool get isSupported;

  Future<Map<StatusApp, bool>> installedApps();
  Future<bool> hasAccess(StatusApp app);

  /// Why access is (not) available; re-checks the real grant and folder every call.
  Future<StatusFolderState> folderState(StatusApp app);

  /// Launches the installed WhatsApp app (launcher intent only). False when it cannot be opened.
  Future<bool> openApp(StatusApp app);
  Future<AccessRequestResult> requestAccess(StatusApp app);
  Future<void> revokeAccess(StatusApp app);
  Future<List<StatusItem>> listStatuses(StatusApp app);

  /// Copies, size-verifies and decodes a status into [destPath].
  Future<FileInfo> copyToFile(StatusItem item, String destPath);
}

/// Helpers that work on any content URI or file path (thumbnails, metadata, gallery export).
abstract interface class MediaTools {
  /// JPEG bytes no larger than [size] px on the long edge, or null if undecodable.
  Future<Uint8List?> thumbnail(
    String uriOrPath,
    MediaKind kind, {
    int size = 360,
  });

  /// Throws [MediaAccessError] with [MediaFailure.corrupt] when unreadable.
  Future<FileInfo> describeFile(String path, MediaKind kind);

  /// Copies [path] into the public gallery (Pictures/WazApp or Movies/WazApp).
  Future<void> exportToGallery({
    required String path,
    required String mimeType,
    required String displayName,
    required MediaKind kind,
  });
}

MediaAccessError _mapError(PlatformException e) {
  switch (e.code) {
    case 'no_access':
      return MediaAccessError(
        MediaFailure.noAccess,
        message:
            'Access to the status folder is missing. Choose the folder again.',
        cause: e,
      );
    case 'wrong_folder':
      return MediaAccessError(
        MediaFailure.wrongFolder,
        message: 'That is not the status folder. Choose the folder again.',
        cause: e,
      );
    case 'source_unavailable':
    case 'missing':
      return MediaAccessError(
        MediaFailure.sourceUnavailable,
        message: 'This item is no longer available.',
        cause: e,
      );
    case 'low_storage':
      return MediaAccessError(
        MediaFailure.lowStorage,
        message: 'Not enough free storage on this device.',
        cause: e,
      );
    case 'corrupt':
      return MediaAccessError(
        MediaFailure.corrupt,
        message: 'This file is damaged or in an unsupported format.',
        cause: e,
      );
    case 'verify_failed':
    case 'copy_failed':
      return MediaAccessError(
        MediaFailure.verifyFailed,
        message: 'The copy could not be verified. Nothing was saved.',
        cause: e,
      );
    case 'unsupported_os':
      return MediaAccessError(
        MediaFailure.unsupported,
        message: e.message ?? 'Not supported on this Android version.',
        cause: e,
      );
    default:
      return MediaAccessError(
        MediaFailure.unknown,
        message: 'Something went wrong. Please try again.',
        cause: e,
      );
  }
}

class ChannelStatusAccessService implements StatusAccessService, MediaTools {
  ChannelStatusAccessService({MethodChannel? channel})
    : _channel =
          channel ?? const MethodChannel('com.webappypie.wazapp/status_access');

  final MethodChannel _channel;

  @override
  bool get isSupported => true;

  Future<T> _call<T>(String method, [Map<String, Object?>? args]) async {
    try {
      final r = await _channel.invokeMethod<T>(method, args);
      return r as T;
    } on PlatformException catch (e) {
      throw _mapError(e);
    } on MissingPluginException catch (e) {
      throw MediaAccessError(
        MediaFailure.unsupported,
        message: 'This feature is not available on this device.',
        cause: e,
      );
    }
  }

  @override
  Future<Map<StatusApp, bool>> installedApps() async {
    final m = await _call<Map<Object?, Object?>>('installedApps');
    return {
      StatusApp.whatsapp: m['whatsapp'] == true,
      StatusApp.business: m['business'] == true,
    };
  }

  @override
  Future<bool> hasAccess(StatusApp app) async =>
      (await _call<bool>('hasAccess', {'app': app.key})) == true;

  @override
  Future<bool> openApp(StatusApp app) async =>
      (await _call<bool>('openApp', {'app': app.key})) == true;

  @override
  Future<StatusFolderState> folderState(StatusApp app) async {
    final m = await _call<Map<Object?, Object?>>('accessState', {
      'app': app.key,
    });
    return switch (m['state']) {
      'granted' => StatusFolderState.granted,
      'revoked' => StatusFolderState.revoked,
      'folder_missing' => StatusFolderState.folderMissing,
      _ => StatusFolderState.notConfigured,
    };
  }

  @override
  Future<AccessRequestResult> requestAccess(StatusApp app) async {
    final m = await _call<Map<Object?, Object?>>('requestAccess', {
      'app': app.key,
    });
    switch (m['status']) {
      case 'granted':
        return AccessRequestResult.granted;
      case 'cancelled':
        return AccessRequestResult.cancelled;
      case 'wrong_folder':
        return AccessRequestResult.wrongFolder;
      default:
        throw const MediaAccessError(
          MediaFailure.unknown,
          message: 'The folder could not be used. Please try again.',
        );
    }
  }

  @override
  Future<void> revokeAccess(StatusApp app) async {
    await _call<bool>('revokeAccess', {'app': app.key});
  }

  @override
  Future<List<StatusItem>> listStatuses(StatusApp app) async {
    final list = await _call<List<Object?>>('listStatuses', {'app': app.key});
    return list
        .whereType<Map<Object?, Object?>>()
        .map((m) {
          return StatusItem(
            app: app,
            uri: m['uri'] as String,
            name: m['name'] as String,
            kind: MediaKind.parse(m['kind'] as String),
            mimeType: m['mimeType'] as String,
            sizeBytes: (m['size'] as num).toInt(),
            modified: DateTime.fromMillisecondsSinceEpoch(
              (m['modifiedMs'] as num).toInt(),
            ),
          );
        })
        .toList(growable: false);
  }

  @override
  Future<FileInfo> copyToFile(StatusItem item, String destPath) async {
    final m = await _call<Map<Object?, Object?>>('copyToFile', {
      'uri': item.uri,
      'destPath': destPath,
      'isVideo': item.kind == MediaKind.video,
    });
    return _fileInfo(m);
  }

  FileInfo _fileInfo(Map<Object?, Object?> m) => FileInfo(
    sizeBytes: (m['size'] as num).toInt(),
    width: (m['width'] as num).toInt(),
    height: (m['height'] as num).toInt(),
    durationMs: (m['durationMs'] as num?)?.toInt() ?? 0,
    hasAudio: m['hasAudio'] == true,
  );

  @override
  Future<Uint8List?> thumbnail(
    String uriOrPath,
    MediaKind kind, {
    int size = 360,
  }) async {
    try {
      return await _call<Uint8List?>('thumbnail', {
        'uri': uriOrPath,
        'isVideo': kind == MediaKind.video,
        'size': size,
      });
    } on MediaAccessError {
      return null;
    }
  }

  @override
  Future<FileInfo> describeFile(String path, MediaKind kind) async {
    final m = await _call<Map<Object?, Object?>>('describeFile', {
      'path': path,
      'isVideo': kind == MediaKind.video,
    });
    return _fileInfo(m);
  }

  @override
  Future<void> exportToGallery({
    required String path,
    required String mimeType,
    required String displayName,
    required MediaKind kind,
  }) async {
    await _call<String>('exportToGallery', {
      'path': path,
      'mimeType': mimeType,
      'displayName': displayName,
      'isVideo': kind == MediaKind.video,
    });
  }
}

/// iOS / other platforms: no private status access exists, say so honestly.
class UnsupportedStatusAccessService implements StatusAccessService {
  const UnsupportedStatusAccessService();

  @override
  bool get isSupported => false;

  MediaAccessError get _err => const MediaAccessError(
    MediaFailure.unsupported,
    message: 'Status folders are not available on this platform. Import from Photos or Files instead.',
  );

  @override
  Future<Map<StatusApp, bool>> installedApps() async => {
    StatusApp.whatsapp: false,
    StatusApp.business: false,
  };

  @override
  Future<bool> hasAccess(StatusApp app) async => false;

  @override
  Future<StatusFolderState> folderState(StatusApp app) async =>
      StatusFolderState.notConfigured;

  @override
  Future<bool> openApp(StatusApp app) async => false;

  @override
  Future<AccessRequestResult> requestAccess(StatusApp app) =>
      Future.error(_err);

  @override
  Future<void> revokeAccess(StatusApp app) async {}

  @override
  Future<List<StatusItem>> listStatuses(StatusApp app) => Future.error(_err);

  @override
  Future<FileInfo> copyToFile(StatusItem item, String destPath) =>
      Future.error(_err);
}

/// Fallback [MediaTools] for platforms without the native bridge.
class UnsupportedMediaTools implements MediaTools {
  const UnsupportedMediaTools();

  @override
  Future<Uint8List?> thumbnail(
    String uriOrPath,
    MediaKind kind, {
    int size = 360,
  }) async => null;

  @override
  Future<FileInfo> describeFile(String path, MediaKind kind) => Future.error(
    const MediaAccessError(
      MediaFailure.unsupported,
      message: 'Not available on this platform.',
    ),
  );

  @override
  Future<void> exportToGallery({
    required String path,
    required String mimeType,
    required String displayName,
    required MediaKind kind,
  }) => Future.error(
    const MediaAccessError(
      MediaFailure.unsupported,
      message: 'Use Share to move this file to Photos.',
    ),
  );
}

bool get isAndroidPlatform => Platform.isAndroid;
