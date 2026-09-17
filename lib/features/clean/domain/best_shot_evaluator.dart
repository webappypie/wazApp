// lib/features/clean/domain/best_shot_evaluator.dart
//
// Suggested-best-shot scoring engine based on resolution, sharpness, and exposure (REQ-SIM-02).
//
// RULE: The best shot is labeled "Suggested", NEVER "Safe to delete".

import 'category_models.dart';

class PhotoQualityMetrics {
  const PhotoQualityMetrics({
    this.sharpness = 1.0,
    this.exposureScore = 1.0,
  });

  /// Measured sharpness/detail (higher means clearer, less blur). Default 1.0.
  final double sharpness;

  /// Exposure quality (0.0 to 1.0; 1.0 represents balanced lighting).
  final double exposureScore;
}

class BestShotEvaluator {
  const BestShotEvaluator._();

  /// Evaluates a cluster of similar photos and returns the index of the suggested best shot.
  ///
  /// Criteria:
  ///   1. Resolution (pixels = width * height)
  ///   2. Sharpness / Detail
  ///   3. Exposure balance
  static int findSuggestedBestIndex(
    List<CategoryItem> items, {
    Map<String, PhotoQualityMetrics>? metricsMap,
  }) {
    if (items.isEmpty) return -1;
    if (items.length == 1) return 0;

    int bestIndex = 0;
    double bestScore = -1.0;

    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      final metrics = metricsMap?[item.id] ?? const PhotoQualityMetrics();

      final width = item.width > 0 ? item.width : 1080;
      final height = item.height > 0 ? item.height : 1920;
      final resolution = (width * height).toDouble();

      // Combined quality score: resolution * sharpness * exposure
      final score = resolution * metrics.sharpness * metrics.exposureScore;

      if (score > bestScore) {
        bestScore = score;
        bestIndex = i;
      }
    }

    return bestIndex;
  }

  /// Evaluates and decorates similar items in a cluster.
  ///
  /// The highest-scoring item is given `badgeLabel = 'Suggested'` (REQ-SIM-02).
  static List<CategoryItem> decorateCluster(
    List<CategoryItem> cluster, {
    Map<String, PhotoQualityMetrics>? metricsMap,
    required String groupTitle,
  }) {
    if (cluster.isEmpty) return [];

    final bestIdx = findSuggestedBestIndex(cluster, metricsMap: metricsMap);

    return List.generate(cluster.length, (i) {
      final item = cluster[i];
      final isSuggested = i == bestIdx;

      return item.copyWith(
        groupTitle: groupTitle,
        badgeLabel: isSuggested ? 'Suggested' : null,
      );
    });
  }
}
