// lib/core/services/ads/ads_service.dart
//
// Ads service abstraction (REQ-ADS-01 to 09).
//
// RULES enforced by this interface:
//   - Ad unit IDs NEVER appear in widget code (REQ-ADS-01).
//   - AdManager is the single entry point. Widgets call this service only.
//   - The service consults RemoteConfigService before serving any ad.
//   - Ad failure must never block app functionality (REQ-ADS-08).

/// Supported ad formats.
enum AdFormat { native, interstitial, rewarded }

/// Result of an ad request.
sealed class AdResult {
  const AdResult();
}

/// Ad loaded and ready to show.
final class AdReady extends AdResult {
  const AdReady();
}

/// Ad not available (network, cooldown, kill switch, or Premium active).
/// Caller must proceed normally — never block on this. (REQ-ADS-08)
final class AdNotAvailable extends AdResult {
  const AdNotAvailable({this.reason = ''});
  final String reason;
}

/// Ads service interface.
///
/// Implementations: [FakeAdsService] (tests/dev), AdMobAdsService (Phase 8).
abstract interface class AdsService {
  /// Request and show an ad of the given [format].
  ///
  /// Returns [AdReady] if shown, [AdNotAvailable] otherwise.
  /// Must never throw — ad failure is always silently swallowed.
  Future<AdResult> showAd(AdFormat format);

  /// Whether the user currently has an active ad-free period
  /// (granted by a rewarded ad per REQ-ADS-07).
  bool get isAdFreePeriodActive;

  /// Pre-load ads in the background. Safe to call at any time.
  Future<void> preload();
}
