// lib/features/clean/services/video_compression_service.dart
//
// Coordinates on-device video compression, progress streaming, and safe replacement (REQ-ACT-09, REQ-CMP-01..04).
//
// RULES:
//   - REQ-ACT-09: Original is NEVER removed until output is verified AND user confirmed replacement.
//   - REQ-CMP-02: Clear labeling of "Estimated" savings.
//   - REQ-CMP-04: Cancellable with immediate cleanup of partial files.

import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../data/media_action_coordinator.dart';
import '../domain/category_models.dart';
import '../domain/compression_models.dart';

final videoCompressionServiceProvider = Provider<VideoCompressionService>((ref) {
  final actionCoordinator = ref.watch(mediaActionCoordinatorProvider);
  return VideoCompressionService(actionCoordinator: actionCoordinator);
});

class VideoCompressionService {
  VideoCompressionService({
    required this.actionCoordinator,
    MethodChannel? methodChannel,
    EventChannel? eventChannel,
  })  : _methodChannel =
            methodChannel ?? const MethodChannel('com.wapptidy/video_compressor'),
        _eventChannel = eventChannel ??
            const EventChannel('com.wapptidy/video_compressor_events');

  final MediaActionCoordinator actionCoordinator;
  final MethodChannel _methodChannel;
  final EventChannel _eventChannel;

  StreamSubscription? _eventSubscription;

  /// Estimate storage savings for a given video and quality profile (REQ-CMP-02).
  CompressionEstimate estimateSavings({
    required CategoryItem item,
    required VideoQualityProfile profile,
  }) {
    return CompressionEstimate.compute(
      originalBytes: item.sizeBytes,
      durationMs: item.durationMs,
      profile: profile,
    );
  }

  /// Compress a video with live progress updates (REQ-CMP-04).
  ///
  /// The resulting video is written to a temporary cache file.
  /// The original video is NOT touched at this stage.
  Future<CompressionResult> compressVideo({
    required CategoryItem item,
    required VideoQualityProfile profile,
    void Function(CompressionProgress progress)? onProgress,
  }) async {
    onProgress?.call(
      const CompressionProgress(
        step: CompressionStep.preparing,
        progressFraction: 0.05,
      ),
    );

    // Listen to native progress events
    try {
      _eventSubscription?.cancel();
      _eventSubscription = _eventChannel.receiveBroadcastStream().listen(
        (event) {
          if (event is Map) {
            final p = (event['progress'] as num?)?.toDouble() ?? 0.0;
            onProgress?.call(
              CompressionProgress(
                step: CompressionStep.transcoding,
                progressFraction: (0.05 + (p * 0.90)).clamp(0.0, 0.95),
              ),
            );
          }
        },
        onError: (err) {
          // Handled via method invocation response
        },
      );
    } catch (_) {
      // Event stream fallback
    }

    try {
      final res = await _methodChannel.invokeMethod<Map<Object?, Object?>>(
        'compressVideo',
        {
          'uri': item.contentUri,
          'targetHeight': profile.targetHeight,
          'targetBitrateBps': profile.targetVideoBitrateBps,
        },
      );

      _eventSubscription?.cancel();

      if (res == null) {
        throw Exception('Transcode failed: null response from native compressor');
      }

      onProgress?.call(
        const CompressionProgress(
          step: CompressionStep.verifying,
          progressFraction: 0.98,
        ),
      );

      final outputPath = res['outputPath']?.toString() ?? '';
      final originalBytes = (res['originalBytes'] as num?)?.toInt() ?? item.sizeBytes;
      final compressedBytes = (res['compressedBytes'] as num?)?.toInt() ?? 0;
      final isVerified = res['isVerified'] == true;

      // REQ-ACT-09: Output must be verified before proceeding
      if (!isVerified || compressedBytes <= 0 || outputPath.isEmpty) {
        throw Exception('Transcode verification failed: invalid output file');
      }

      final result = CompressionResult(
        originalItem: item,
        outputFilePath: outputPath,
        originalBytes: originalBytes,
        compressedBytes: compressedBytes,
        isVerified: isVerified,
        qualityProfile: profile,
      );

      onProgress?.call(
        const CompressionProgress(
          step: CompressionStep.completed,
          progressFraction: 1.0,
        ),
      );

      return result;
    } catch (e) {
      _eventSubscription?.cancel();
      onProgress?.call(
        CompressionProgress(
          step: CompressionStep.error,
          progressFraction: 0.0,
          errorMessage: e.toString(),
        ),
      );
      rethrow;
    }
  }

  /// Cancel an ongoing compression job (REQ-CMP-04).
  Future<void> cancelCompression() async {
    _eventSubscription?.cancel();
    try {
      await _methodChannel.invokeMethod('cancelCompression');
    } catch (_) {}
  }

  /// Finalize video replacement choice (REQ-ACT-09, REQ-CMP-03).
  ///
  /// CRITICAL SAFETY RULE:
  ///   The original item is ONLY deleted/trashed if [replaceOriginal] is true
  ///   AND [result.isVerified] is true.
  Future<bool> finalizeReplacement({
    required CompressionResult result,
    required bool replaceOriginal,
  }) async {
    if (!result.isVerified) {
      throw StateError('Cannot finalize unverified compression result');
    }

    if (replaceOriginal) {
      // Move original to Bin / Scoped Storage Trash (REQ-ACT-09, REQ-ACT-01)
      final summary = await actionCoordinator.trashSelected([result.originalItem]);
      return summary.removedCount > 0;
    }

    // Keep both: do nothing to the original
    return true;
  }
}
