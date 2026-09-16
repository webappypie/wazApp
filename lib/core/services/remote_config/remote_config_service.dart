// lib/core/services/remote_config/remote_config_service.dart
//
// Remote config abstraction (P-10).
//
// Firebase Remote Config is optional and fail-safe:
//   - If unreachable, local defaults apply and the app works normally.
//   - Every key that can be fetched remotely must have a hardcoded local default here.
// All ad-policy keys from REQ-ADS-09 are declared here.

/// Remote configuration service interface.
///
/// Implementations: [FakeRemoteConfigService] (tests/dev), FirebaseRemoteConfigService (Phase 8).
abstract interface class RemoteConfigService {
  /// Fetch and activate new values. On failure, silently keep local defaults.
  Future<void> fetchAndActivate();

  // --- Ad policy keys (REQ-ADS-09) ---

  /// Master ads switch. [true] = ads enabled.
  bool get adsEnabled;

  /// Per-format toggles.
  bool get nativeAdsEnabled;
  bool get interstitialAdsEnabled;
  bool get rewardedAdsEnabled;

  /// Maximum interstitial ads per session.
  int get interstitialSessionCap;

  /// Minimum minutes between interstitials.
  int get interstitialCooldownMinutes;

  /// Minimum real content items before a native ad may appear.
  int get nativeMinContentItems;

  /// Duration in minutes that a rewarded ad grants an ad-free period.
  int get rewardAdFreeDurationMinutes;

  /// Emergency kill switch — when [true], all ads are immediately suppressed
  /// regardless of other flags.
  bool get emergencyAdsKillSwitch;
}
