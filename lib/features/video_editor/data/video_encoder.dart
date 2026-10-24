// lib/features/video_editor/data/video_encoder.dart
//
// Dart side of the native video export bridge. Only Android has an encoder
// implementation (Media3 Transformer). Other platforms report unsupported so the
// UI never offers a video editor it cannot deliver.

import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/services.dart';

import '../../../core/error/app_error.dart';
import '../domain/video_edit_state.dart';

class VideoEncodeRequest {
  const VideoEncodeRequest({
    required this.id,
    required this.inputPath,
    required this.outputPath,
    required this.plan,
    this.overlayPngPath,
  });

  final String id;
  final String inputPath;
  final String outputPath;
  final VideoExportPlan plan;

  /// Transparent PNG exactly [plan.outWidth] x [plan.outHeight], composited over every frame.
  final String? overlayPngPath;
}

class VideoEncodeResult {
  const VideoEncodeResult({required this.outputPath, required this.width, required this.height, required this.durationMs});
  final String outputPath;
  final int width;
  final int height;
  final int durationMs;
}

abstract interface class VideoEncoder {
  bool get isSupported;

  /// Encodes [request]; [onProgress] receives 0..1. Throws [OperationCancelled] if [cancel] was called.
  Future<VideoEncodeResult> encode(VideoEncodeRequest request, {void Function(double progress)? onProgress});

  /// Stops the running export and discards partial output.
  Future<void> cancel();
}

class ChannelVideoEncoder implements VideoEncoder {
  ChannelVideoEncoder({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel('com.webappypie.wazapp/video_export') {
    _channel.setMethodCallHandler(_onCall);
  }

  final MethodChannel _channel;
  String? _activeId;
  void Function(double)? _onProgress;

  @override
  bool get isSupported => true;

  Future<dynamic> _onCall(MethodCall call) async {
    if (call.method == 'progress') {
      final m = call.arguments as Map<Object?, Object?>;
      if (m['id'] == _activeId) _onProgress?.call(((m['progress'] as num?) ?? 0).toDouble().clamp(0.0, 1.0));
    }
    return null;
  }

  @override
  Future<VideoEncodeResult> encode(VideoEncodeRequest r, {void Function(double progress)? onProgress}) async {
    _activeId = r.id;
    _onProgress = onProgress;
    try {
      final m = await _channel.invokeMapMethod<String, Object?>('export', {
        'id': r.id,
        'inputPath': r.inputPath,
        'outputPath': r.outputPath,
        'startMs': r.plan.startMs,
        'endMs': r.plan.endMs,
        'mute': r.plan.mute,
        'outWidth': r.plan.outWidth,
        'outHeight': r.plan.outHeight,
        'videoBitrate': r.plan.videoBitrate,
        'overlayPngPath': r.overlayPngPath,
        'crop': r.plan.crop == null
            ? null
            : {
                'left': r.plan.crop!.left,
                'top': r.plan.crop!.top,
                'right': r.plan.crop!.right,
                'bottom': r.plan.crop!.bottom,
              },
      });
      if (m == null) {
        throw const MediaAccessError(MediaFailure.unknown, message: 'The video could not be exported.');
      }
      return VideoEncodeResult(
        outputPath: m['outputPath'] as String,
        width: (m['width'] as num).toInt(),
        height: (m['height'] as num).toInt(),
        durationMs: (m['durationMs'] as num).toInt(),
      );
    } on PlatformException catch (e) {
      throw _map(e);
    } on MissingPluginException catch (e) {
      throw MediaAccessError(MediaFailure.unsupported,
          message: 'Video editing is not available on this device.', cause: e);
    } finally {
      _activeId = null;
      _onProgress = null;
    }
  }

  @override
  Future<void> cancel() async {
    try {
      await _channel.invokeMethod<bool>('cancel');
    } on PlatformException {
      // nothing running
    }
  }

  AppError _map(PlatformException e) {
    switch (e.code) {
      case 'cancelled':
        return const OperationCancelled();
      case 'low_storage':
        return MediaAccessError(MediaFailure.lowStorage,
            message: 'Not enough free storage to export this video.', cause: e);
      case 'source_unavailable':
        return MediaAccessError(MediaFailure.sourceUnavailable,
            message: 'The original video is no longer available.', cause: e);
      case 'unsupported':
        return MediaAccessError(MediaFailure.unsupported,
            message: 'This video format cannot be edited on this device.', cause: e);
      case 'busy':
        return MediaAccessError(MediaFailure.unknown, message: 'Another export is still running.', cause: e);
      default:
        return MediaAccessError(MediaFailure.unknown,
            message: 'The video could not be exported. Please try again.', cause: e);
    }
  }
}

/// Platforms without a verified encoder (iOS today).
class UnsupportedVideoEncoder implements VideoEncoder {
  const UnsupportedVideoEncoder();

  @override
  bool get isSupported => false;

  @override
  Future<VideoEncodeResult> encode(VideoEncodeRequest request, {void Function(double progress)? onProgress}) =>
      Future.error(const MediaAccessError(MediaFailure.unsupported,
          message: 'Video editing is not available on this platform yet.'));

  @override
  Future<void> cancel() async {}
}

VideoEncoder createPlatformVideoEncoder() =>
    Platform.isAndroid ? ChannelVideoEncoder() : const UnsupportedVideoEncoder();
