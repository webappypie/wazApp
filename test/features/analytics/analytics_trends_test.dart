// test/features/analytics/analytics_trends_test.dart
//
// Pure domain and calculation tests for AnalyticsTrends & TimeRange (REQ-ANL-01, REQ-ANL-03, REQ-ANL-04).

import 'package:flutter_test/flutter_test.dart';
import 'package:wapptidy/features/analytics/domain/analytics_models.dart';

void main() {
  group('REQ-ANL-03 & PRD §11.3: TimeRange Premium Entitlements', () {
    test('7D and 30D are free tier; 6M and All-time are Premium gated', () {
      expect(TimeRange.sevenDays.isPremiumOnly, isFalse);
      expect(TimeRange.thirtyDays.isPremiumOnly, isFalse);
      expect(TimeRange.sixMonths.isPremiumOnly, isTrue);
      expect(TimeRange.allTime.isPremiumOnly, isTrue);
    });

    test('Days durations are correctly configured', () {
      expect(TimeRange.sevenDays.days, 7);
      expect(TimeRange.thirtyDays.days, 30);
      expect(TimeRange.sixMonths.days, 180);
      expect(TimeRange.allTime.days, isNull);
    });
  });

  group('REQ-ANL-03 & REQ-ANL-04: Metrics Computation', () {
    test('AnalyticsTrends.compute calculates net growth, pct, and daily average', () {
      final now = DateTime(2026, 9, 17);
      final day1 = StorageSnapshotPoint(
        dateEpochDay: 100,
        date: now.subtract(const Duration(days: 9)),
        totalBytes: 1000 * 1024 * 1024, // 1000 MB
        videoBytes: 600 * 1024 * 1024,
        imageBytes: 300 * 1024 * 1024,
        audioBytes: 100 * 1024 * 1024,
      );
      final day10 = StorageSnapshotPoint(
        dateEpochDay: 109,
        date: now,
        totalBytes: 1500 * 1024 * 1024, // 1500 MB (+500MB over 10 days)
        videoBytes: 1000 * 1024 * 1024,
        imageBytes: 400 * 1024 * 1024,
        audioBytes: 100 * 1024 * 1024,
      );

      final trends = AnalyticsTrends.compute(
        range: TimeRange.thirtyDays,
        snapshots: [day1, day10],
      );

      expect(trends.currentTotalBytes, 1500 * 1024 * 1024);
      expect(trends.netGrowthBytes, 500 * 1024 * 1024);
      expect(trends.netGrowthPercentage, 50.0); // +50%
      expect(trends.dailyAverageBytes, (500 * 1024 * 1024 / 10).round());

      // Breakdown check
      final breakdown = trends.breakdown;
      expect(breakdown.videoBytes, 1000 * 1024 * 1024);
      expect(breakdown.imageBytes, 400 * 1024 * 1024);
      expect(breakdown.audioBytes, 100 * 1024 * 1024);

      // Ranked check
      expect(breakdown.rankedCategories.first.categoryName, 'Videos');
      expect(breakdown.largestContributor.categoryName, 'Videos');
      expect((breakdown.largestContributor.ratio * 100).toStringAsFixed(1), '66.7');
    });

    test('AnalyticsTrends handles empty snapshots safely', () {
      final trends = AnalyticsTrends.compute(
        range: TimeRange.sevenDays,
        snapshots: const [],
      );

      expect(trends.currentTotalBytes, 0);
      expect(trends.netGrowthBytes, 0);
      expect(trends.netGrowthPercentage, 0.0);
      expect(trends.dailyAverageBytes, 0);
      expect(trends.breakdown.largestContributor.categoryName, 'Videos');
      expect(trends.breakdown.largestContributor.ratio, 0.0);
    });
  });
}
