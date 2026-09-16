// lib/core/services/ads/fake_ads_service.dart
//
// In-memory ads service for tests and development.
// Returns AdNotAvailable by default. Tests can enable ads and configure
// blocking behaviour to verify that ad failure never blocks app functionality
// (REQ-ADS-08, REQ-BIN-03).

import 'ads_service.dart';

final class FakeAdsService implements AdsService {
  /// Set to true to simulate ads being available.
  bool adsAvailable = false;

  /// Set to true to simulate a "blocking" ads service — used in Phase 7 tests
  /// to prove that restore (REQ-BIN-03) ignores ads entirely.
  bool blocking = false;

  bool _adFreePeriodActive = false;

  final List<AdFormat> shownAds = [];

  @override
  Future<AdResult> showAd(AdFormat format) async {
    if (blocking) {
      // Simulate a hung / broken ad SDK. Caller must still proceed. (REQ-ADS-08)
      await Future<void>.delayed(const Duration(milliseconds: 100));
      return const AdNotAvailable(reason: 'blocking_fake');
    }
    if (adsAvailable) {
      shownAds.add(format);
      if (format == AdFormat.rewarded) {
        _adFreePeriodActive = true;
      }
      return const AdReady();
    }
    return const AdNotAvailable(reason: 'not_available_fake');
  }

  @override
  bool get isAdFreePeriodActive => _adFreePeriodActive;

  @override
  Future<void> preload() async {
    // No-op in fake.
  }

  void reset() {
    shownAds.clear();
    _adFreePeriodActive = false;
  }
}
