import 'package:flutter/widgets.dart';
import 'package:wap_ads_sdk/wap_ads.dart';
// The SDK exposes its house-ad tracker only through the core singleton.
// ignore: implementation_imports
import 'package:wap_ads_sdk/src/core/wap_ads_core.dart';
import 'house_ad_card.dart';
import 'admob_provider.dart';

/// Third-party network IDs that `WapAdsCore` auto-registers with **mock**
/// adapters in wap_ads_sdk 0.1.0 (they draw placeholder banners and grant
/// fake rewards). WazApp bundles no SDK for any of them (Google AdMob is
/// its only ad SDK), so each is overridden with [NoFillAdProvider] and a fake
/// ad can never be shown or counted, even if a dashboard chain names one.
/// `admob` is replaced by the real, direct [AdMobWapProvider].
const kMockedThirdPartyNetworks = ['applovin', 'meta', 'inmobi', 'unity'];

/// A provider that never fills, used in place of the SDK's mock adapters for
/// networks WazApp does not integrate. The waterfall simply moves on.
class NoFillAdProvider implements WapAdProvider {
  NoFillAdProvider(this.id);

  @override
  final String id;

  @override
  String get name => 'Unavailable ($id)';

  @override
  Future<void> initialize(EffectiveAdConfig config,
      {bool testMode = false}) async {}

  @override
  bool isFormatSupported(AdFormat format) => false;

  @override
  Future<bool> showInterstitial(BuildContext context, String adUnitId,
          {String? placementKey, String? requestId}) async =>
      false;

  @override
  Future<RewardedAdResult> showRewarded(BuildContext context, String adUnitId,
      {String? placementKey, String? requestId}) async {
    return RewardedAdResult.failed(
      provider: id,
      requestId: requestId ?? 'req_none',
      error: const AdError(code: AdError.noFill, message: 'Not integrated'),
    );
  }

  @override
  Widget buildBanner(BuildContext context, String adUnitId,
      {VoidCallback? onLoaded,
      Function(String error)? onFailed,
      VoidCallback? onClicked}) {
    WidgetsBinding.instance
        .addPostFrameCallback((_) => onFailed?.call('$id not integrated'));
    return const SizedBox.shrink();
  }

  @override
  Widget buildNative(BuildContext context, String adUnitId,
      {Widget Function(BuildContext context, Map<String, dynamic> data)?
          customBuilder,
      VoidCallback? onLoaded,
      Function(String error)? onFailed,
      VoidCallback? onClicked}) {
    WidgetsBinding.instance
        .addPostFrameCallback((_) => onFailed?.call('$id not integrated'));
    return const SizedBox.shrink();
  }
}

/// WebAppyPie house ads, rendered **only** from a campaign WAPCentral returns
/// in `formats.<format>.customAdFallback`.
///
/// The SDK's own `CustomAdsProvider` substitutes a hard-coded
/// "WebAppyPie Central" campaign when none is configured and tracks
/// impressions for it; its tap handler also never opens the destination.
/// This replacement reports no-fill instead, counts impressions only when the
/// card is actually visible, and opens the https destination on tap.
class ServerHouseAdsProvider implements WapAdProvider {
  EffectiveAdConfig? _config;

  @override
  String get id => 'custom_ads';

  @override
  String get name => 'WebAppyPie house ads';

  @override
  Future<void> initialize(EffectiveAdConfig config,
      {bool testMode = false}) async {
    _config = config;
  }

  @override
  bool isFormatSupported(AdFormat format) =>
      format == AdFormat.banner || format == AdFormat.native;

  /// The server campaign for [format], or null if absent or unsafe.
  CustomAdFallback? campaignFor(AdFormat format) {
    final c =
        (WapAds.currentConfig ?? _config)?.formats[format]?.customAdFallback;
    if (c == null) return null;
    final uri = Uri.tryParse(c.destinationUrl);
    final valid = c.campaignId.isNotEmpty &&
        c.title.trim().isNotEmpty &&
        uri != null &&
        uri.scheme == 'https' &&
        uri.host.isNotEmpty;
    return valid ? c : null;
  }

  Widget _build(AdFormat format, VoidCallback? onLoaded,
      Function(String error)? onFailed, VoidCallback? onClicked) {
    final campaign = campaignFor(format);
    if (campaign == null) {
      WidgetsBinding.instance.addPostFrameCallback(
          (_) => onFailed?.call('No house campaign configured'));
      return const SizedBox.shrink();
    }
    return HouseAdCard(
      campaign: campaign,
      compact: format == AdFormat.banner,
      onShown: () {
        onLoaded?.call();
        WapAdsCore.instance.customAdTracker?.track(
            campaignId: campaign.campaignId,
            type: 'impression',
            format: format);
      },
      onTap: () {
        onClicked?.call();
        WapAdsCore.instance.customAdTracker?.track(
            campaignId: campaign.campaignId, type: 'click', format: format);
      },
    );
  }

  @override
  Widget buildBanner(BuildContext context, String adUnitId,
          {VoidCallback? onLoaded,
          Function(String error)? onFailed,
          VoidCallback? onClicked}) =>
      _build(AdFormat.banner, onLoaded, onFailed, onClicked);

  @override
  Widget buildNative(BuildContext context, String adUnitId,
          {Widget Function(BuildContext context, Map<String, dynamic> data)?
              customBuilder,
          VoidCallback? onLoaded,
          Function(String error)? onFailed,
          VoidCallback? onClicked}) =>
      _build(AdFormat.native, onLoaded, onFailed, onClicked);

  // WazApp does not use full-screen formats .
  @override
  Future<bool> showInterstitial(BuildContext context, String adUnitId,
          {String? placementKey, String? requestId}) async =>
      false;

  @override
  Future<RewardedAdResult> showRewarded(BuildContext context, String adUnitId,
          {String? placementKey, String? requestId}) async =>
      RewardedAdResult.skipped(
          provider: id, requestId: requestId ?? 'req_none');
}

/// All provider overrides to pass to `WapAds.initialize(customProviders:)`.
/// WAPCentral's `mediationChain` picks among them per format.
List<WapAdProvider> wazAppAdProviders() => [
      for (final id in kMockedThirdPartyNetworks) NoFillAdProvider(id),
      AdMobWapProvider(),
      ServerHouseAdsProvider(),
    ];
