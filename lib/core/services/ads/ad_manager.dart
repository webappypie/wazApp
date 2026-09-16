// lib/core/services/ads/ad_manager.dart
//
// Centralised AdManager implementing all advertising rules (REQ-ADS-01 to REQ-ADS-09).
//
// RULES:
//   - REQ-ADS-01: Single centralized manager. Ad unit IDs NEVER exist in widget code.
//   - REQ-ADS-02: Formats: native, rewarded, very limited interstitial. No app-open ad.
//   - REQ-ADS-03: Home: at most one native card, after storage overview.
//   - REQ-ADS-04: Lists: native ad allowed only after >= 10 content rows.
//   - REQ-ADS-05: FORBIDDEN: destructive screens, permission screens, swipe actions, Bin restore.
//   - REQ-ADS-06: Interstitial max 1 per session, minimum interval cooldown, never on startup/exit/delete.
//   - REQ-ADS-07: Rewarded ad only grants temporary ad-free period, never gates user files/restore/cleanup.
//   - REQ-ADS-08: Ad failure never blocks app functionality; layout collapses cleanly.
//   - REQ-ADS-09: Fully remote-configurable with emergency kill switch.

import 'dart:async';
import '../remote_config/remote_config_service.dart';
import 'ads_service.dart';

/// Explicit placement contexts to enforce REQ-ADS-05 rules.
enum AdPlacement {
  homeSection,
  listContent,
  postScanSummary,
  postCleanupSession,
  // Forbidden contexts (REQ-ADS-05):
  destructiveConfirmation,
  binRestoreFlow,
  permissionScreen,
  swipeAction,
}

/// Exception thrown when code attempts to request an ad in a forbidden context (REQ-ADS-05).
class ForbiddenAdPlacementException implements Exception {
  ForbiddenAdPlacementException(this.placement);
  final AdPlacement placement;

  @override
  String toString() =>
      'REQ-ADS-05 Violation: Ad requested at forbidden placement: $placement. '
      'Ads are strictly forbidden beside Delete/Restore, on permission screens, '
      'in swipe actions, or in the Bin restore flow.';
}

class AdManager {
  AdManager({
    required AdsService service,
    required RemoteConfigService remoteConfigService,
    required bool Function() isPremiumCallback,
  })  : _adsService = service,
        _remoteConfig = remoteConfigService,
        _isPremium = isPremiumCallback;

  final AdsService _adsService;
  final RemoteConfigService _remoteConfig;
  final bool Function() _isPremium;

  int _interstitialsShownThisSession = 0;
  DateTime? _lastInterstitialShownAt;

  DateTime? _rewardAdFreeUntil;

  /// Check if user has an active temporary ad-free reward (REQ-ADS-07).
  bool get isTemporaryAdFreeActive {
    if (_rewardAdFreeUntil == null) return false;
    return DateTime.now().isBefore(_rewardAdFreeUntil!);
  }

  /// Whether ads can be served right now given Premium status,
  /// temporary ad-free state, remote-config flags, and kill switch.
  bool canShowAds({AdFormat? format}) {
    // Premium users: no ads ever
    if (_isPremium()) return false;

    // Emergency kill switch (REQ-ADS-09)
    if (_remoteConfig.emergencyAdsKillSwitch) return false;

    // Master ads toggle (REQ-ADS-09)
    if (!_remoteConfig.adsEnabled) return false;

    // Rewarded ad-free period active (REQ-ADS-07)
    if (isTemporaryAdFreeActive || _adsService.isAdFreePeriodActive) return false;

    // Per-format toggles (REQ-ADS-09)
    if (format != null) {
      switch (format) {
        case AdFormat.native:
          if (!_remoteConfig.nativeAdsEnabled) return false;
        case AdFormat.interstitial:
          if (!_remoteConfig.interstitialAdsEnabled) return false;
        case AdFormat.rewarded:
          if (!_remoteConfig.rewardedAdsEnabled) return false;
      }
    }

    return true;
  }

  /// Evaluates whether a Native ad can be shown at the given [placement].
  ///
  /// For [AdPlacement.listContent], requires at least [minItemsAbove] >= 10 (REQ-ADS-04).
  bool canShowNativeAd({
    required AdPlacement placement,
    int minItemsAbove = 0,
  }) {
    _validatePlacement(placement);

    if (!canShowAds(format: AdFormat.native)) return false;

    if (placement == AdPlacement.listContent) {
      final minRequired = _remoteConfig.nativeMinContentItems;
      if (minItemsAbove < minRequired) return false;
    }

    return true;
  }

  /// Request to show an interstitial ad at a genuine break (REQ-ADS-06).
  ///
  /// Enforces:
  /// - REQ-ADS-05: Forbidden placements throw [ForbiddenAdPlacementException]
  /// - REQ-ADS-06: Max 1 per session, minimum cooldown minutes
  /// - REQ-ADS-08: Failure never throws or blocks caller
  Future<bool> showInterstitial({required AdPlacement placement}) async {
    _validatePlacement(placement);

    // REQ-ADS-06: Interstitials only allowed at post-scan or post-cleanup breaks
    if (placement != AdPlacement.postScanSummary &&
        placement != AdPlacement.postCleanupSession) {
      return false;
    }

    if (!canShowAds(format: AdFormat.interstitial)) return false;

    // Check session cap (REQ-ADS-06, REQ-ADS-09)
    final cap = _remoteConfig.interstitialSessionCap;
    if (_interstitialsShownThisSession >= cap) return false;

    // Check cooldown (REQ-ADS-06, REQ-ADS-09)
    final cooldownMins = _remoteConfig.interstitialCooldownMinutes;
    if (_lastInterstitialShownAt != null) {
      final elapsed = DateTime.now().difference(_lastInterstitialShownAt!);
      if (elapsed < Duration(minutes: cooldownMins)) {
        return false;
      }
    }

    try {
      final result = await _adsService.showAd(AdFormat.interstitial);
      if (result is AdReady) {
        _interstitialsShownThisSession++;
        _lastInterstitialShownAt = DateTime.now();
        return true;
      }
    } catch (_) {
      // REQ-ADS-08: Failure never throws to caller
    }
    return false;
  }

  /// Request a rewarded ad to earn a temporary ad-free period (REQ-ADS-07).
  ///
  /// Rewarded ads ONLY grant temporary ad-free periods.
  /// Never gate user media, bin restore, or cleanup categories.
  Future<bool> showRewardedForAdFreePeriod() async {
    if (!canShowAds(format: AdFormat.rewarded)) return false;

    try {
      final result = await _adsService.showAd(AdFormat.rewarded);
      if (result is AdReady) {
        final durationMins = _remoteConfig.rewardAdFreeDurationMinutes;
        _rewardAdFreeUntil = DateTime.now().add(Duration(minutes: durationMins));
        return true;
      }
    } catch (_) {
      // REQ-ADS-08: Swallow error
    }
    return false;
  }

  /// REQ-ADS-05: Explicit placement validator.
  void _validatePlacement(AdPlacement placement) {
    switch (placement) {
      case AdPlacement.destructiveConfirmation:
      case AdPlacement.binRestoreFlow:
      case AdPlacement.permissionScreen:
      case AdPlacement.swipeAction:
        throw ForbiddenAdPlacementException(placement);
      case AdPlacement.homeSection:
      case AdPlacement.listContent:
      case AdPlacement.postScanSummary:
      case AdPlacement.postCleanupSession:
        break;
    }
  }

  /// Reset session counters (e.g. for testing).
  void resetSession() {
    _interstitialsShownThisSession = 0;
    _lastInterstitialShownAt = null;
    _rewardAdFreeUntil = null;
  }
}
