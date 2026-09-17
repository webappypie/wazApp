// lib/features/clean/domain/compression_models.dart
//
// Domain models and estimation algorithms for Video Compression (REQ-ACT-09, REQ-CMP-01..04).
//
// RULES:
//   - REQ-ACT-09: Original is never removed until output is verified AND user confirmed replacement.
//   - REQ-CMP-01: Multiple quality profiles with clear resolution & bitrate targets.
//   - REQ-CMP-02: Clear labeling of "Estimated" savings before compression.
//   - REQ-CMP-04: Live progress and cancellable execution.

import 'dart:math' as math;
import 'category_models.dart';

/// Target quality profile for video compression (REQ-CMP-01).
enum VideoQualityProfile {
  highQuality(
    displayName: 'High Quality',
    description: '1080p • Light compression preserving maximum detail',
    targetHeight: 1080,
    targetVideoBitrateBps: 4500000, // 4.5 Mbps
    audioBitrateBps: 192000,        // 192 kbps
    defaultRatio: 0.70,
  ),
  balanced(
    displayName: 'Balanced',
    description: '720p • Recommended balance of quality and storage savings',
    targetHeight: 720,
    targetVideoBitrateBps: 2500000, // 2.5 Mbps
    audioBitrateBps: 128000,        // 128 kbps
    defaultRatio: 0.45,
  ),
  maximumSavings(
    displayName: 'Maximum Savings',
    description: '480p • Highest storage reduction for clips and memes',
    targetHeight: 480,
    targetVideoBitrateBps: 1000000, // 1.0 Mbps
    audioBitrateBps: 96000,         // 96 kbps
    defaultRatio: 0.25,
  );

  const VideoQualityProfile({
    required this.displayName,
    required this.description,
    required this.targetHeight,
    required this.targetVideoBitrateBps,
    required this.audioBitrateBps,
    required this.defaultRatio,
  });

  final String displayName;
  final String description;
  final int targetHeight;
  final int targetVideoBitrateBps;
  final int audioBitrateBps;
  final double defaultRatio;

  int get totalTargetBitrateBps => targetVideoBitrateBps + audioBitrateBps;
}

/// Estimated savings result before compression (REQ-CMP-02).
///
/// MUST always be labeled "Estimated" in UI until actual transcode finishes.
class CompressionEstimate {
  const CompressionEstimate({
    required this.profile,
    required this.originalBytes,
    required this.estimatedBytes,
  });

  final VideoQualityProfile profile;
  final int originalBytes;
  final int estimatedBytes;

  int get estimatedSavingsBytes => math.max(0, originalBytes - estimatedBytes);

  double get estimatedSavingsRatio =>
      originalBytes > 0 ? (estimatedSavingsBytes / originalBytes) : 0.0;

  int get estimatedSavingsPercentage => (estimatedSavingsRatio * 100).round();

  String get formattedOriginalSize => formatBytes(originalBytes);
  String get formattedEstimatedSize => formatBytes(estimatedBytes);
  String get formattedEstimatedSavings => formatBytes(estimatedSavingsBytes);

  /// Compute estimate based on video duration and profile bitrates, or fallback ratio.
  factory CompressionEstimate.compute({
    required int originalBytes,
    required int durationMs,
    required VideoQualityProfile profile,
  }) {
    int estBytes;
    if (durationMs > 0) {
      final durationSec = durationMs / 1000.0;
      final bytesFromBitrate =
          ((profile.totalTargetBitrateBps / 8.0) * durationSec).round();
      // Estimated output shouldn't exceed original size
      estBytes = math.min(originalBytes, math.max(1024 * 100, bytesFromBitrate));
    } else {
      estBytes = (originalBytes * profile.defaultRatio).round();
    }

    return CompressionEstimate(
      profile: profile,
      originalBytes: originalBytes,
      estimatedBytes: estBytes,
    );
  }
}

/// Lifecycle step for video compression transcode.
enum CompressionStep {
  idle,
  preparing,
  transcoding,
  verifying,
  completed,
  cancelled,
  error;

  bool get isActive =>
      this == preparing || this == transcoding || this == verifying;
  bool get isFinished =>
      this == completed || this == cancelled || this == error;
}

/// Live progress notification during video compression (REQ-CMP-04).
class CompressionProgress {
  const CompressionProgress({
    required this.step,
    required this.progressFraction,
    this.bytesWritten = 0,
    this.errorMessage,
  });

  final CompressionStep step;
  final double progressFraction; // 0.0 to 1.0
  final int bytesWritten;
  final String? errorMessage;

  int get progressPercentage => (progressFraction * 100).clamp(0, 100).round();

  static const idle = CompressionProgress(
    step: CompressionStep.idle,
    progressFraction: 0.0,
  );
}

/// Verified result of a completed video compression job (REQ-ACT-09, REQ-CMP-03).
class CompressionResult {
  const CompressionResult({
    required this.originalItem,
    required this.outputFilePath,
    required this.originalBytes,
    required this.compressedBytes,
    required this.isVerified,
    required this.qualityProfile,
  });

  final CategoryItem originalItem;
  final String outputFilePath;
  final int originalBytes;
  final int compressedBytes;
  final bool isVerified;
  final VideoQualityProfile qualityProfile;

  int get actualSavingsBytes => math.max(0, originalBytes - compressedBytes);

  double get actualSavingsRatio =>
      originalBytes > 0 ? (actualSavingsBytes / originalBytes) : 0.0;

  int get actualSavingsPercentage => (actualSavingsRatio * 100).round();

  String get formattedOriginalSize => formatBytes(originalBytes);
  String get formattedCompressedSize => formatBytes(compressedBytes);
  String get formattedActualSavings => formatBytes(actualSavingsBytes);
}
