// lib/core/di/providers.dart
//
// Root Riverpod providers for all core services and the database.
//
// Architecture rule (DEV_PROMPT §3): dependencies point inward only.
//   presentation → domain → data → core/services
//
// All providers here expose interfaces, not concrete types, so that
// tests can override them with fakes via ProviderContainer overrides.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/clean/data/media_action_coordinator.dart';
import '../database/app_database.dart';
import '../services/ads/ads_service.dart';
import '../services/ads/fake_ads_service.dart';
import '../services/analytics/analytics_service.dart';
import '../services/analytics/fake_analytics_service.dart';
import '../services/background_task/background_task_service.dart';
import '../services/background_task/fake_background_task_service.dart';
import '../services/media_access/media_access_service.dart';
import '../services/media_access/fake_media_access_service.dart';
import '../services/purchases/purchase_service.dart';
import '../services/purchases/fake_purchase_service.dart';
import '../services/remote_config/remote_config_service.dart';
import '../services/remote_config/fake_remote_config_service.dart';
import '../services/onboarding/onboarding_service.dart';
import '../services/onboarding/real_onboarding_service.dart';

// ---------------------------------------------------------------------------
// Database
// ---------------------------------------------------------------------------

/// The single shared AppDatabase instance.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

// ---------------------------------------------------------------------------
// Services
// ---------------------------------------------------------------------------
//
// Phase 0: all service providers return their Fake implementations.
// Phase 3+: real implementations are swapped in here (not in callers).
// Tests override any of these via ProviderContainer(overrides: [...]).

final analyticsServiceProvider = Provider<AnalyticsService>(
  (ref) => FakeAnalyticsService(),
);

final remoteConfigServiceProvider = Provider<RemoteConfigService>(
  (ref) => FakeRemoteConfigService(),
);

final purchaseServiceProvider = Provider<PurchaseService>((ref) {
  final svc = FakePurchaseService();
  ref.onDispose(svc.dispose);
  return svc;
});

final adsServiceProvider = Provider<AdsService>(
  (ref) => FakeAdsService(),
);

final mediaAccessServiceProvider = Provider<MediaAccessService>(
  (ref) => FakeMediaAccessService(),
);

final backgroundTaskServiceProvider = Provider<BackgroundTaskService>(
  (ref) => FakeBackgroundTaskService(),
);

final onboardingServiceProvider = Provider<OnboardingService>(
  (ref) => RealOnboardingService(),
);

final mediaActionCoordinatorProvider = Provider<MediaActionCoordinator>((ref) {
  return MediaActionCoordinator(
    mediaAccessService: ref.watch(mediaAccessServiceProvider),
    db: ref.watch(appDatabaseProvider),
  );
});

// ---------------------------------------------------------------------------
// Derived state
// ---------------------------------------------------------------------------

/// Current premium entitlement, derived from the purchase service stream.
final premiumEntitlementProvider = StreamProvider<PremiumEntitlement>((ref) {
  final svc = ref.watch(purchaseServiceProvider);
  return svc.entitlementStream;
});

/// Convenience bool: is the user currently Premium?
final isPremiumProvider = Provider<bool>((ref) {
  final entitlement = ref.watch(premiumEntitlementProvider);
  // In Riverpod 3, .value returns null during loading/error (same as old .valueOrNull).
  return entitlement.value == PremiumEntitlement.premium;
});
