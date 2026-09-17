// lib/features/analytics/presentation/analytics_controller.dart
//
// Riverpod providers and state management for Storage Analytics (REQ-ANL-01..04).

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/di/providers.dart';
import '../data/analytics_repository.dart';
import '../domain/analytics_models.dart';

final analyticsRepositoryProvider = Provider<AnalyticsRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return AnalyticsRepository(database: db);
});

class SelectedTimeRangeNotifier extends Notifier<TimeRange> {
  @override
  TimeRange build() => TimeRange.thirtyDays;

  void setRange(TimeRange range) {
    state = range;
  }
}

final selectedTimeRangeProvider =
    NotifierProvider<SelectedTimeRangeNotifier, TimeRange>(
        SelectedTimeRangeNotifier.new);

final analyticsTrendsProvider = FutureProvider<AnalyticsTrends>((ref) async {
  final repo = ref.watch(analyticsRepositoryProvider);
  final range = ref.watch(selectedTimeRangeProvider);
  return repo.getTrends(range: range);
});
