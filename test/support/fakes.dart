// Test doubles for the platform adapters. These replace the Android bridge only;
// LibraryService, Drift and the file system run for real in tests.

import 'dart:io';
import 'dart:typed_data';

import 'package:wazapp/core/error/app_error.dart';
import 'package:wazapp/features/library/data/media_probe.dart';
import 'package:wazapp/features/library/domain/library_models.dart';
import 'package:wazapp/features/status/data/status_access_service.dart';
import 'package:wazapp/features/status/domain/status_models.dart';

/// Simulates the SAF bridge: "statuses" are real files in a temp directory and
/// copyToFile really copies them (so size/rollback behaviour is exercised).
class FakeStatusAccess implements StatusAccessService, MediaTools {
  FakeStatusAccess({
    this.supported = true,
    Map<StatusApp, bool>? installed,
    Map<StatusApp, bool>? access,
  })  : installed = installed ?? {StatusApp.whatsapp: true, StatusApp.business: false},
        access = access ?? {StatusApp.whatsapp: true, StatusApp.business: false};

  final bool supported;
  final Map<StatusApp, bool> installed;
  final Map<StatusApp, bool> access;
  final Map<StatusApp, List<StatusItem>> statuses = {};

  /// Source uri -> real file backing it.
  final Map<String, File> backing = {};

  /// URIs for which copy fails with the given failure.
  final Map<String, MediaFailure> copyFailures = {};

  /// When set, listStatuses fails with this failure (e.g. folder cleared by WhatsApp).
  MediaFailure? listFailure;

  /// Overrides [describeFile] (e.g. to describe an exported video).
  FileInfo Function(String path, MediaKind kind)? describe;

  AccessRequestResult nextRequestResult = AccessRequestResult.granted;
  int requestCount = 0;
  final List<Map<String, String>> exported = [];
  MediaFailure? exportFailure;

  StatusItem addStatus(
    Directory dir,
    String name, {
    StatusApp app = StatusApp.whatsapp,
    MediaKind kind = MediaKind.image,
    List<int>? bytes,
    DateTime? modified,
  }) {
    final file = File('${dir.path}/$name')..writeAsBytesSync(bytes ?? List.filled(2048, 7));
    final item = StatusItem(
      app: app,
      uri: 'content://fake/${app.key}/$name',
      name: name,
      kind: kind,
      mimeType: kind == MediaKind.video ? 'video/mp4' : 'image/jpeg',
      sizeBytes: file.lengthSync(),
      modified: modified ?? DateTime(2026, 10, 24, 12),
    );
    backing[item.uri] = file;
    statuses.putIfAbsent(app, () => []).add(item);
    return item;
  }

  @override
  bool get isSupported => supported;

  @override
  Future<Map<StatusApp, bool>> installedApps() async => installed;

  @override
  Future<bool> hasAccess(StatusApp app) async => access[app] ?? false;

  @override
  Future<AccessRequestResult> requestAccess(StatusApp app) async {
    requestCount++;
    if (nextRequestResult == AccessRequestResult.granted) access[app] = true;
    return nextRequestResult;
  }

  @override
  Future<void> revokeAccess(StatusApp app) async => access[app] = false;

  @override
  Future<List<StatusItem>> listStatuses(StatusApp app) async {
    if (listFailure != null) {
      throw MediaAccessError(listFailure!, message: 'The status folder cannot be read.');
    }
    if (access[app] != true) {
      throw const MediaAccessError(MediaFailure.noAccess, message: 'no access');
    }
    return statuses[app] ?? const [];
  }

  @override
  Future<FileInfo> copyToFile(StatusItem item, String destPath) async {
    final failure = copyFailures[item.uri];
    if (failure != null) {
      throw MediaAccessError(failure, message: 'copy failed: ${failure.name}');
    }
    final src = backing[item.uri];
    if (src == null || !src.existsSync()) {
      throw const MediaAccessError(MediaFailure.sourceUnavailable, message: 'gone');
    }
    await src.copy(destPath);
    return FileInfo(
      sizeBytes: await File(destPath).length(),
      width: 720,
      height: 1280,
      durationMs: item.kind == MediaKind.video ? 5000 : 0,
    );
  }

  @override
  Future<Uint8List?> thumbnail(String uriOrPath, MediaKind kind, {int size = 360}) async =>
      kind == MediaKind.video ? Uint8List.fromList([1, 2, 3]) : null;

  @override
  Future<FileInfo> describeFile(String path, MediaKind kind) async =>
      describe?.call(path, kind) ?? FileInfo(sizeBytes: await File(path).length(), width: 10, height: 10);

  @override
  Future<void> exportToGallery({
    required String path,
    required String mimeType,
    required String displayName,
    required MediaKind kind,
  }) async {
    if (exportFailure != null) {
      throw MediaAccessError(exportFailure!, message: 'export failed');
    }
    exported.add({'path': path, 'name': displayName});
  }
}

/// Probe that accepts everything except files containing the byte marker 0xFF 0xFF 0xFF.
class FakeProbe implements MediaProbe {
  @override
  Future<FileInfo> probe(String path, MediaKind kind) async {
    final bytes = await File(path).readAsBytes();
    final corrupt = bytes.length >= 3 && bytes[0] == 0xFF && bytes[1] == 0xFF && bytes[2] == 0xFF;
    if (corrupt) {
      throw const MediaAccessError(MediaFailure.corrupt, message: 'corrupt');
    }
    return FileInfo(
      sizeBytes: bytes.length,
      width: 100,
      height: 100,
      durationMs: kind == MediaKind.video ? 3000 : 0,
    );
  }
}
