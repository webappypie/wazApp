// lib/features/clean/domain/blur_detector.dart
//
// Domain models and evaluation logic for Blur Detection (REQ-BLR-01).
//
// RULES:
//   - REQ-BLR-01: Two confidence tiers: "Very blurry" (high confidence)
//     and "Possibly blurry" (moderate confidence).
//   - Shallow depth of field (DoF) / portrait bokeh / intentional motion
//     must NOT be flagged as blurry.
//   - Items are tagged with their confidence tier, NEVER "Safe to delete".

import 'dart:math' as math;

/// Confidence tier for blur detection (REQ-BLR-01).
enum BlurConfidence {
  /// High-confidence blur: entire image is blurry, no sharp focal region.
  veryBlurry,

  /// Moderate-confidence blur: mildly soft or borderline.
  possiblyBlurry,

  /// Sharp image or intentional bokeh with a sharp focal subject.
  sharp;

  String get displayName {
    switch (this) {
      case BlurConfidence.veryBlurry:
        return 'Very Blurry';
      case BlurConfidence.possiblyBlurry:
        return 'Possibly Blurry';
      case BlurConfidence.sharp:
        return 'Sharp';
    }
  }

  bool get isBlurry => this == veryBlurry || this == possiblyBlurry;
}

/// Evaluation result for an image.
class BlurEvaluation {
  const BlurEvaluation({
    required this.globalVariance,
    required this.maxBlockVariance,
    required this.confidence,
    this.isShallowDoF = false,
  });

  final double globalVariance;
  final double maxBlockVariance;
  final BlurConfidence confidence;
  final bool isShallowDoF;

  @override
  String toString() =>
      'BlurEvaluation(global: ${globalVariance.toStringAsFixed(1)}, maxBlock: ${maxBlockVariance.toStringAsFixed(1)}, confidence: $confidence, shallowDoF: $isShallowDoF)';
}

/// Evaluates blur metrics against calibrated thresholds.
class BlurDetector {
  const BlurDetector._();

  static const double defaultVeryBlurryThreshold = 100.0;
  static const double defaultPossiblyBlurryThreshold = 250.0;
  static const double defaultShallowDoFSharpThreshold = 500.0;

  /// Evaluates blur metrics into a [BlurEvaluation].
  ///
  /// Protects against false positives on shallow depth-of-field (portrait mode,
  /// macro photography) by checking [maxBlockVariance].
  static BlurEvaluation evaluate({
    required double globalVariance,
    required double maxBlockVariance,
    double veryBlurryThreshold = defaultVeryBlurryThreshold,
    double possiblyBlurryThreshold = defaultPossiblyBlurryThreshold,
    double shallowDoFSharpThreshold = defaultShallowDoFSharpThreshold,
  }) {
    // REQ-BLR-01: Shallow depth-of-field protection.
    // If a regional focal area is sharp while overall background is blurry,
    // this is intentional bokeh / portrait mode -> classify as sharp!
    final bool isShallowDoF = maxBlockVariance >= shallowDoFSharpThreshold &&
        globalVariance < possiblyBlurryThreshold;

    if (isShallowDoF) {
      return BlurEvaluation(
        globalVariance: globalVariance,
        maxBlockVariance: maxBlockVariance,
        confidence: BlurConfidence.sharp,
        isShallowDoF: true,
      );
    }

    if (globalVariance < veryBlurryThreshold &&
        maxBlockVariance < veryBlurryThreshold * 1.5) {
      return BlurEvaluation(
        globalVariance: globalVariance,
        maxBlockVariance: maxBlockVariance,
        confidence: BlurConfidence.veryBlurry,
        isShallowDoF: false,
      );
    }

    if (globalVariance < possiblyBlurryThreshold &&
        maxBlockVariance < possiblyBlurryThreshold * 1.5) {
      return BlurEvaluation(
        globalVariance: globalVariance,
        maxBlockVariance: maxBlockVariance,
        confidence: BlurConfidence.possiblyBlurry,
        isShallowDoF: false,
      );
    }

    return BlurEvaluation(
      globalVariance: globalVariance,
      maxBlockVariance: maxBlockVariance,
      confidence: BlurConfidence.sharp,
      isShallowDoF: false,
    );
  }

  /// Reference/testing implementation of discrete 3x3 Laplacian variance
  /// on a 2D grayscale matrix (values 0..255).
  static BlurEvaluation computeFromGrayscaleMatrix(
    List<List<int>> matrix, {
    double veryBlurryThreshold = defaultVeryBlurryThreshold,
    double possiblyBlurryThreshold = defaultPossiblyBlurryThreshold,
    double shallowDoFSharpThreshold = defaultShallowDoFSharpThreshold,
  }) {
    final height = matrix.length;
    if (height < 3) {
      return const BlurEvaluation(
        globalVariance: 0,
        maxBlockVariance: 0,
        confidence: BlurConfidence.veryBlurry,
      );
    }
    final width = matrix[0].length;
    if (width < 3) {
      return const BlurEvaluation(
        globalVariance: 0,
        maxBlockVariance: 0,
        confidence: BlurConfidence.veryBlurry,
      );
    }

    final lapWidth = width - 2;
    final lapHeight = height - 2;
    final laplacian = List<double>.filled(lapWidth * lapHeight, 0.0);

    double sum = 0.0;
    int idx = 0;
    for (int y = 1; y < height - 1; y++) {
      for (int x = 1; x < width - 1; x++) {
        final center = matrix[y][x];
        final top = matrix[y - 1][x];
        final bottom = matrix[y + 1][x];
        final left = matrix[y][x - 1];
        final right = matrix[y][x + 1];

        // Discrete 3x3 Laplacian kernel:
        // [ 0  1  0 ]
        // [ 1 -4  1 ]
        // [ 0  1  0 ]
        final val = (top + bottom + left + right - 4 * center).toDouble();
        laplacian[idx] = val;
        sum += val;
        idx++;
      }
    }

    final totalPixels = laplacian.length;
    final mean = sum / totalPixels;

    double varSum = 0.0;
    for (final v in laplacian) {
      final diff = v - mean;
      varSum += diff * diff;
    }
    final globalVariance = varSum / totalPixels;

    // 3x3 grid block variance
    final blockW = lapWidth ~/ 3;
    final blockH = lapHeight ~/ 3;
    double maxBlockVariance = 0.0;

    if (blockW > 0 && blockH > 0) {
      for (int by = 0; by < 3; by++) {
        for (int bx = 0; bx < 3; bx++) {
          double bSum = 0.0;
          final bStartX = bx * blockW;
          final bStartY = by * blockH;
          final count = blockW * blockH;

          for (int y = 0; y < blockH; y++) {
            for (int x = 0; x < blockW; x++) {
              final v = laplacian[(bStartY + y) * lapWidth + (bStartX + x)];
              bSum += v;
            }
          }
          final bMean = bSum / count;

          double bVarSum = 0.0;
          for (int y = 0; y < blockH; y++) {
            for (int x = 0; x < blockW; x++) {
              final v = laplacian[(bStartY + y) * lapWidth + (bStartX + x)];
              final d = v - bMean;
              bVarSum += d * d;
            }
          }
          final blockVar = bVarSum / count;
          maxBlockVariance = math.max(maxBlockVariance, blockVar);
        }
      }
    } else {
      maxBlockVariance = globalVariance;
    }

    return evaluate(
      globalVariance: globalVariance,
      maxBlockVariance: maxBlockVariance,
      veryBlurryThreshold: veryBlurryThreshold,
      possiblyBlurryThreshold: possiblyBlurryThreshold,
      shallowDoFSharpThreshold: shallowDoFSharpThreshold,
    );
  }
}
