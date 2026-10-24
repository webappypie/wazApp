// Test doubles for the video pipeline.

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';
import 'package:wazapp/core/error/app_error.dart';
import 'package:wazapp/features/library/data/media_probe.dart';
import 'package:wazapp/features/library/domain/library_models.dart';
import 'package:wazapp/features/video_editor/data/video_encoder.dart';

/// Stand-in for the native encoder: records the request and writes a placeholder file.
class FakeEncoder implements VideoEncoder {
  VideoEncodeRequest? last;
  Uint8List? overlayBytes;
  bool cancelCalled = false;
  Object? failWith;
  Completer<void>? hold;

  /// What the "encoder produced".
  VideoEncodeResult Function(VideoEncodeRequest r)? produce;

  @override
  bool get isSupported => true;

  @override
  Future<VideoEncodeResult> encode(VideoEncodeRequest r, {void Function(double progress)? onProgress}) async {
    last = r;
    if (r.overlayPngPath != null) overlayBytes = File(r.overlayPngPath!).readAsBytesSync();
    onProgress?.call(0.5);
    if (hold != null) await hold!.future;
    if (cancelCalled) throw const OperationCancelled();
    if (failWith != null) throw failWith!;
    File(r.outputPath).writeAsBytesSync(List.filled(4096, 9));
    onProgress?.call(1);
    return produce?.call(r) ??
        VideoEncodeResult(
          outputPath: r.outputPath,
          width: r.plan.outWidth,
          height: r.plan.outHeight,
          durationMs: r.plan.durationMs,
        );
  }

  @override
  Future<void> cancel() async {
    cancelCalled = true;
    hold?.complete();
  }
}

class EchoProbe implements MediaProbe {
  EchoProbe(this.width, this.height, this.durationMs);
  int width, height, durationMs;
  @override
  Future<FileInfo> probe(String path, MediaKind kind) async =>
      FileInfo(sizeBytes: File(path).lengthSync(), width: width, height: height, durationMs: durationMs);
}


/// Fake `video_player` platform so VideoPlayerController works in widget tests.
class FakeVideoPlayerPlatform extends VideoPlayerPlatform {
  FakeVideoPlayerPlatform({this.duration = const Duration(seconds: 10), this.size = const ui.Size(1920, 1080)});

  final Duration duration;
  final ui.Size size;
  final Map<int, StreamController<VideoEvent>> _streams = {};
  int _next = 1;
  Duration position = Duration.zero;
  bool playing = false;
  final List<String> calls = [];

  @override
  Future<void> init() async {}

  @override
  Future<void> dispose(int playerId) async {
    calls.add('dispose');
    await _streams.remove(playerId)?.close();
  }

  @override
  Future<int?> create(DataSource dataSource) async {
    final id = _next++;
    final c = StreamController<VideoEvent>();
    _streams[id] = c;
    scheduleMicrotask(() {
      if (!c.isClosed) {
        c.add(VideoEvent(eventType: VideoEventType.initialized, duration: duration, size: size));
      }
    });
    return id;
  }

  @override
  Future<int?> createWithOptions(VideoCreationOptions options) => create(options.dataSource);

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) => _streams[playerId]!.stream;

  @override
  Future<void> setLooping(int playerId, bool looping) async {}

  @override
  Future<void> play(int playerId) async {
    playing = true;
    calls.add('play');
  }

  @override
  Future<void> pause(int playerId) async {
    playing = false;
    calls.add('pause');
  }

  @override
  Future<void> setVolume(int playerId, double volume) async {}

  @override
  Future<void> seekTo(int playerId, Duration position) async {
    this.position = position;
    calls.add('seek:${position.inMilliseconds}');
  }

  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}

  @override
  Future<Duration> getPosition(int playerId) async => position;

  @override
  Widget buildView(int playerId) => const SizedBox.expand();

  @override
  Widget buildViewWithOptions(VideoViewOptions options) => const SizedBox.expand();

  @override
  Future<void> setMixWithOthers(bool mixWithOthers) async {}
}

