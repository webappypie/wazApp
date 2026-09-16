// lib/features/home/presentation/home_providers.dart
//
// Riverpod providers for the Home dashboard.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../data/real_home_repository.dart';
import '../domain/home_models.dart';
import '../domain/home_repository.dart';

// ---------------------------------------------------------------------------
// Repository
// ---------------------------------------------------------------------------

/// Home repository provider.
/// Phase 4: uses RealHomeRepository (queries Drift).
/// Tests: override with FakeHomeRepository.
final homeRepositoryProvider = Provider<HomeRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return RealHomeRepository(db);
});

// ---------------------------------------------------------------------------
// Dashboard
// ---------------------------------------------------------------------------

/// Loads and caches the HomeDashboard.
/// Invalidated by [refreshHomeDashboardProvider].
final homeDashboardProvider =
    FutureProvider.autoDispose<HomeDashboard>((ref) async {
  final repo = ref.watch(homeRepositoryProvider);
  return repo.loadDashboard();
});

/// Call ref.invalidate(refreshHomeDashboardProvider) after any cleanup action
/// to force a HomeDashboard reload.
final refreshHomeDashboardProvider = Provider<void>((ref) {});
