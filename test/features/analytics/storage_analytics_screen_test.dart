// test/features/analytics/storage_analytics_screen_test.dart
//
// Widget test suite for StorageAnalyticsScreen (REQ-ANL-01..04, PRD §7.8, §11.3).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wapptidy/core/design/tokens.dart';
import 'package:wapptidy/core/di/providers.dart';
import 'package:wapptidy/features/analytics/domain/analytics_models.dart';
import 'package:wapptidy/features/analytics/presentation/analytics_controller.dart';
import 'package:wapptidy/features/analytics/presentation/storage_analytics_screen.dart';

Widget _buildTestScreen({
  required AnalyticsTrends trends,
  bool isPremium = false,
}) {
  return ProviderScope(
    overrides: [
      analyticsTrendsProvider.overrideWith((ref) => Future.value(trends)),
      isPremiumProvider.overrideWithValue(isPremium),
    ],
    child: MaterialApp(
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      home: const StorageAnalyticsScreen(),
    ),
  );
}

void main() {
  final now = DateTime(2026, 9, 17);
  final testSnapshots = [
    StorageSnapshotPoint(
      dateEpochDay: 100,
      date: now.subtract(const Duration(days: 6)),
      totalBytes: 200 * 1024 * 1024,
      imageBytes: 50 * 1024 * 1024,
      videoBytes: 150 * 1024 * 1024,
    ),
    StorageSnapshotPoint(
      dateEpochDay: 106,
      date: now,
      totalBytes: 500 * 1024 * 1024,
      imageBytes: 100 * 1024 * 1024,
      videoBytes: 400 * 1024 * 1024,
    ),
  ];

  final mockTrends = AnalyticsTrends.compute(
    range: TimeRange.thirtyDays,
    snapshots: testSnapshots,
    isBackfilled: true,
  );

  group('StorageAnalyticsScreen UI', () {
    testWidgets('Renders all headers, metrics, tabs, chart, and breakdown', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_buildTestScreen(trends: mockTrends));
      await tester.pumpAndSettle();

      // App bar
      expect(find.text('Storage Analytics'), findsOneWidget);

      // Time range selector tabs
      expect(find.text('7D'), findsOneWidget);
      expect(find.text('30D'), findsOneWidget);
      expect(find.text('6M'), findsOneWidget);
      expect(find.text('All'), findsOneWidget);

      // Metric Summary Cards
      expect(find.text('Current Total'), findsOneWidget);
      expect(find.text('Net Growth (30D)'), findsOneWidget);
      expect(find.text('Daily Average'), findsOneWidget);
      expect(find.text('500 MB'), findsOneWidget);
      expect(find.text('+300 MB'), findsOneWidget);

      // Chart Header
      expect(find.text('Storage Growth Curve'), findsOneWidget);

      // Media Breakdown Card
      expect(find.text('Media Type Breakdown'), findsOneWidget);
      expect(find.text('Videos'), findsOneWidget);
      expect(find.text('Images'), findsOneWidget);
      expect(find.text('Largest Contributor'), findsOneWidget);

      // Cold-start explanation (REQ-ANL-02)
      expect(find.text('Historical Timeline Reconstructed'), findsOneWidget);
      expect(find.textContaining('REQ-ANL-02'), findsOneWidget);
    });

    testWidgets('Tapping free range updates selection', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_buildTestScreen(trends: mockTrends));
      await tester.pumpAndSettle();

      final sevenDaysTab = find.text('7D');
      expect(sevenDaysTab, findsOneWidget);

      await tester.tap(sevenDaysTab);
      await tester.pumpAndSettle();

      final element = tester.element(find.byType(StorageAnalyticsScreen));
      final container = ProviderScope.containerOf(element);
      expect(container.read(selectedTimeRangeProvider), TimeRange.sevenDays);
    });

    testWidgets('Tapping 6M or All when free opens Premium Upgrade dialog', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_buildTestScreen(trends: mockTrends, isPremium: false));
      await tester.pumpAndSettle();

      final sixMonthsTab = find.text('6M');
      await tester.tap(sixMonthsTab);
      await tester.pumpAndSettle();

      // Verify Premium dialog is presented
      expect(find.text('Unlock Extended Trends'), findsOneWidget);
      expect(find.textContaining('exclusive to WappTidy Lifetime Premium'), findsOneWidget);
      expect(find.text('Upgrade'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Unlock Extended Trends'), findsNothing);
    });
  });
}
