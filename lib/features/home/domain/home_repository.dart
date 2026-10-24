// lib/features/home/domain/home_repository.dart
//
// Interface for the Home dashboard data layer.
// The real impl queries Drift; the fake returns configurable test data.

import 'home_models.dart';

abstract interface class HomeRepository {
  /// Build the full HomeDashboard from the current Drift index.
  Future<HomeDashboard> loadDashboard({String? sourceApp});

  /// Add a recent-activity entry after a cleanup action completes.
  Future<void> recordActivity({
    required String actionLabel,
    required int filesCount,
    required int bytesRecovered,
  });
}
