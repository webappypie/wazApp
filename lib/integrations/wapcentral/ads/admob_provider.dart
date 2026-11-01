// ignore_for_file: prefer_initializing_formals
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart' as gma;
import 'package:wap_ads_sdk/wap_ads.dart';

/// The Google Mobile Ads calls WazApp makes, behind a seam for tests.
abstract class GoogleAdsApi {
  /// Google UMP consent: refresh, show the form where required, and report
  /// whether ad requests are allowed.
  Future<bool> gatherConsent();

  /// Starts the Mobile Ads SDK once.
  Future<void> start();
}

class PluginGoogleAdsApi implements GoogleAdsApi {
  const PluginGoogleAdsApi();

  @override
  Future<bool> gatherConsent() async {
    final updated = Completer<void>();
    gma.ConsentInformation.instance.requestConsentInfoUpdate(
      gma.ConsentRequestParameters(),
      () async {
        await gma.ConsentForm.loadAndShowConsentFormIfRequired((formError) {
          if (formError != null) {
            debugPrint('[AdMob] consent form error ${formError.errorCode}');
          }
        });
        if (!updated.isCompleted) updated.complete();
      },
      (error) {
        debugPrint('[AdMob] consent update failed ${error.errorCode}');
        if (!updated.isCompleted) updated.complete();
      },
    );
    await updated.future;
    // Falls back to the previous session's consent if the update failed.
    return gma.ConsentInformation.instance.canRequestAds();
  }

  @override
  Future<void> start() async {
    final status = await gma.MobileAds.instance.initialize();
    debugPrint('[AdMob] MobileAds started: '
        '${status.adapterStatuses.entries.map((e) => '${e.key}=${e.value.state.name}').join(', ')}');
  }
}

/// Outcome of a full-screen rewarded ad.
class RewardOutcome {
  const RewardOutcome({required this.shown, required this.earned});
  final bool shown;
  final bool earned;
}

/// Full-screen Google Mobile Ads calls (interstitial, app open, rewarded), behind a seam for tests.
/// Each call loads one ad, shows it and completes when the user dismisses it (or load/show fails).
abstract class FullScreenAdsApi {
  Future<bool> showInterstitial(String adUnitId);
  Future<bool> showAppOpen(String adUnitId);
  Future<RewardOutcome> showRewarded(String adUnitId);
}

class PluginFullScreenAdsApi implements FullScreenAdsApi {
  const PluginFullScreenAdsApi();

  static const _loadTimeout = Duration(seconds: 8);

  /// Runs [load] and gives up if no ad has loaded within [_loadTimeout]; once an ad is on screen the
  /// future simply waits for the user to dismiss it.
  Future<T> _run<T>(T failed, void Function(Completer<T> done, void Function() loaded) load) {
    final done = Completer<T>();
    var loaded = false;
    Timer(_loadTimeout, () {
      if (!loaded && !done.isCompleted) done.complete(failed);
    });
    try {
      load(done, () => loaded = true);
    } catch (e) {
      debugPrint('[AdMob] full-screen load threw ${e.runtimeType}');
      if (!done.isCompleted) done.complete(failed);
    }
    return done.future;
  }

  @override
  Future<bool> showInterstitial(String adUnitId) => _run<bool>(false, (done, loaded) {
        debugPrint('[AdMob] interstitial request $adUnitId');
        gma.InterstitialAd.load(
          adUnitId: adUnitId,
          request: const gma.AdRequest(),
          adLoadCallback: gma.InterstitialAdLoadCallback(
            onAdLoaded: (ad) {
              loaded();
              ad.fullScreenContentCallback = gma.FullScreenContentCallback(
                onAdDismissedFullScreenContent: (a) {
                  a.dispose();
                  if (!done.isCompleted) done.complete(true);
                },
                onAdFailedToShowFullScreenContent: (a, e) {
                  a.dispose();
                  if (!done.isCompleted) done.complete(false);
                },
              );
              ad.show();
            },
            onAdFailedToLoad: (e) {
              debugPrint('[AdMob] interstitial failed ${e.code} ${e.message}');
              if (!done.isCompleted) done.complete(false);
            },
          ),
        );
      });

  @override
  Future<bool> showAppOpen(String adUnitId) => _run<bool>(false, (done, loaded) {
        debugPrint('[AdMob] app open request $adUnitId');
        gma.AppOpenAd.load(
          adUnitId: adUnitId,
          request: const gma.AdRequest(),
          adLoadCallback: gma.AppOpenAdLoadCallback(
            onAdLoaded: (ad) {
              loaded();
              ad.fullScreenContentCallback = gma.FullScreenContentCallback(
                onAdDismissedFullScreenContent: (a) {
                  a.dispose();
                  if (!done.isCompleted) done.complete(true);
                },
                onAdFailedToShowFullScreenContent: (a, e) {
                  a.dispose();
                  if (!done.isCompleted) done.complete(false);
                },
              );
              ad.show();
            },
            onAdFailedToLoad: (e) {
              debugPrint('[AdMob] app open failed ${e.code} ${e.message}');
              if (!done.isCompleted) done.complete(false);
            },
          ),
        );
      });

  @override
  Future<RewardOutcome> showRewarded(String adUnitId) =>
      _run<RewardOutcome>(const RewardOutcome(shown: false, earned: false), (done, loaded) {
        debugPrint('[AdMob] rewarded request $adUnitId');
        gma.RewardedAd.load(
          adUnitId: adUnitId,
          request: const gma.AdRequest(),
          rewardedAdLoadCallback: gma.RewardedAdLoadCallback(
            onAdLoaded: (ad) {
              loaded();
              var earned = false;
              ad.fullScreenContentCallback = gma.FullScreenContentCallback(
                onAdDismissedFullScreenContent: (a) {
                  a.dispose();
                  if (!done.isCompleted) done.complete(RewardOutcome(shown: true, earned: earned));
                },
                onAdFailedToShowFullScreenContent: (a, e) {
                  a.dispose();
                  if (!done.isCompleted) done.complete(const RewardOutcome(shown: false, earned: false));
                },
              );
              ad.show(onUserEarnedReward: (_, _) => earned = true);
            },
            onAdFailedToLoad: (e) {
              debugPrint('[AdMob] rewarded failed ${e.code} ${e.message}');
              if (!done.isCompleted) done.complete(const RewardOutcome(shown: false, earned: false));
            },
          ),
        );
      });
}

/// Google AdMob served **directly** through the Google Mobile Ads SDK, as the
/// `wap_ads_sdk` provider `admob`.
///
/// WAPCentral decides whether ads run, which formats/placements are on, and
/// the AdMob ad unit IDs (`mediationChain` tiers with `networkId: "admob"`
/// from `/ads/config`). The AdMob **App ID** is not served by WAPCentral; it
/// is in the manifest (android/app/build.gradle). Debug/profile builds swap
/// every unit for Google's test unit of the same format.
///
/// AdMob is WazApp's only ad SDK; any other network a dashboard chain
/// names is no-fill (see ad_providers.dart). WazApp's approved
/// placements are banner and native.
class AdMobWapProvider implements WapAdProvider {
  AdMobWapProvider({
    GoogleAdsApi api = const PluginGoogleAdsApi(),
    FullScreenAdsApi fullScreen = const PluginFullScreenAdsApi(),
    EffectiveAdConfig? Function()? currentConfig,
    bool useTestAds = !kReleaseMode,
  })  : _api = api,
        _fullScreen = fullScreen,
        _useTestAds = useTestAds,
        _currentConfig = currentConfig ?? (() => WapAds.currentConfig);

  /// Google's official test units
  /// (developers.google.com/admob/android/test-ads#sample_ad_units).
  static const testUnits = {
    AdFormat.banner: 'ca-app-pub-3940256099942544/9214589741',
    AdFormat.native: 'ca-app-pub-3940256099942544/2247696110',
    AdFormat.interstitial: 'ca-app-pub-3940256099942544/1033173712',
    AdFormat.rewarded: 'ca-app-pub-3940256099942544/5224354917',
    AdFormat.appOpen: 'ca-app-pub-3940256099942544/9257395921',
  };

  /// Development builds (debug/profile) always request Google's test units,
  /// so production ads are never requested while developing or testing on a
  /// device. WAPCentral still decides whether and where ads appear. Release
  /// builds request exactly the units WAPCentral delivers.
  final bool _useTestAds;
  final GoogleAdsApi _api;
  final FullScreenAdsApi _fullScreen;
  final EffectiveAdConfig? Function() _currentConfig;
  final Map<AdFormat, String> _units = {};
  bool _ready = false;
  bool _sdkStarted = false;
  String? _configVersion;
  Future<void>? _resync;

  /// Why AdMob is not serving, for diagnostics; null when ready.
  String? notReadyReason = 'not initialized';

  bool get isReady => _ready;

  @visibleForTesting
  Map<AdFormat, String> get units => Map.unmodifiable(_units);

  @override
  String get id => 'admob';

  @override
  String get name => 'Google AdMob';

  @override
  bool isFormatSupported(AdFormat format) =>
      format == AdFormat.banner ||
      format == AdFormat.native ||
      format == AdFormat.interstitial ||
      format == AdFormat.appOpen ||
      format == AdFormat.rewarded;

  @override
  Future<void> initialize(EffectiveAdConfig config,
      {bool testMode = false}) async {
    _configVersion = config.version;
    _units.clear();
    config.formats.forEach((format, formatConfig) {
      if (!formatConfig.enabled) return;
      for (final tier in formatConfig.mediationChain) {
        if (tier.networkId == id && tier.adUnitId.isNotEmpty) {
          _units[format] = tier.adUnitId;
        }
      }
    });
    debugPrint('[AdMob] units from WAPCentral (testMode=${config.testMode}): '
        '${_units.entries.map((e) => '${e.key.name}=${e.value}').join(', ')}');
    debugPrint('[AdMob] ${adModeSummary(config, useTestAds: _useTestAds)}');

    if (!config.enabled) return _notReady('ads disabled in WAPCentral');
    if (_units.isEmpty) {
      return _notReady('no AdMob ad units in the WAPCentral config');
    }
    try {
      if (!await _api.gatherConsent()) {
        return _notReady('consent does not allow ad requests');
      }
      if (!_sdkStarted) {
        await _api.start();
        _sdkStarted = true;
      }
    } catch (e) {
      return _notReady('Google Mobile Ads did not start (${e.runtimeType})');
    }
    _ready = true;
    notReadyReason = null;
  }

  /// One-line diagnostic: build mode, config source, WAPCentral mode, and
  /// whether test or production units are requested. No keys or unit IDs.
  @visibleForTesting
  static String adModeSummary(EffectiveAdConfig config,
      {required bool useTestAds}) {
    const build = kReleaseMode
        ? 'release'
        : kProfileMode
            ? 'profile'
            : 'debug';
    final source = config.version == 'offline_fallback'
        ? 'offline fallback (ads off)'
        : 'WAPCentral v${config.version}';
    final formats = config.formats.entries
        .where((e) => e.value.enabled)
        .map((e) => e.key.name)
        .join(',');
    final serving = useTestAds
        ? 'Google TEST units (non-release build safeguard)'
        : config.testMode
            ? 'WAPCentral units (WAPCentral testing mode)'
            : 'WAPCentral PRODUCTION units';
    return 'mode: build=$build source=$source enabled=${config.enabled} '
        'wapTestMode=${config.testMode} formats=[$formats] serving=$serving';
  }

  void _notReady(String reason) {
    _ready = false;
    notReadyReason = reason;
    debugPrint('[AdMob] not serving: $reason');
  }

  /// `wap_ads_sdk` refreshes `/ads/config` every 15 minutes without
  /// re-initializing providers; re-apply the config when its version changes
  /// so dashboard edits (units, kill switches, environment) apply mid-session.
  void _followConfigRefresh() {
    final latest = _currentConfig();
    if (latest == null || latest.version == _configVersion) return;
    _resync ??= initialize(latest).whenComplete(() => _resync = null);
  }

  Widget _noFill(Function(String error)? onFailed) {
    final reason = notReadyReason ?? 'no unit';
    WidgetsBinding.instance
        .addPostFrameCallback((_) => onFailed?.call('admob: $reason'));
    return const SizedBox.shrink();
  }

  String? _unitFor(AdFormat format, String adUnitId) {
    final unit = adUnitId.isNotEmpty ? adUnitId : _units[format];
    if (unit == null) return null;
    return _useTestAds ? testUnits[format] : unit;
  }

  @override
  Widget buildBanner(BuildContext context, String adUnitId,
      {VoidCallback? onLoaded,
      Function(String error)? onFailed,
      VoidCallback? onClicked}) {
    _followConfigRefresh();
    final unit = _unitFor(AdFormat.banner, adUnitId);
    if (!_ready || unit == null) return _noFill(onFailed);
    return AdMobBannerView(
      key: ValueKey('admob_banner_$unit'),
      adUnitId: unit,
      onLoaded: onLoaded,
      onFailed: onFailed,
      onClicked: onClicked,
    );
  }

  @override
  Widget buildNative(BuildContext context, String adUnitId,
      {Widget Function(BuildContext context, Map<String, dynamic> data)?
          customBuilder,
      VoidCallback? onLoaded,
      Function(String error)? onFailed,
      VoidCallback? onClicked}) {
    _followConfigRefresh();
    final unit = _unitFor(AdFormat.native, adUnitId);
    if (!_ready || unit == null) return _noFill(onFailed);
    return AdMobNativeView(
      key: ValueKey('admob_native_$unit'),
      adUnitId: unit,
      onLoaded: onLoaded,
      onFailed: onFailed,
      onClicked: onClicked,
    );
  }

  // No full-screen placements in WazApp (banner and native only).
  /// The SDK App Open manager also calls [showInterstitial]; tell the two apart by the configured unit.
  AdFormat _fullScreenFormat(String adUnitId) =>
      _units[AdFormat.appOpen] == adUnitId && _units[AdFormat.interstitial] != adUnitId
          ? AdFormat.appOpen
          : AdFormat.interstitial;

  @override
  Future<bool> showInterstitial(BuildContext context, String adUnitId,
      {String? placementKey, String? requestId}) async {
    _followConfigRefresh();
    final format = _fullScreenFormat(adUnitId);
    final unit = _unitFor(format, adUnitId);
    if (!_ready || unit == null) return false;
    return format == AdFormat.appOpen ? _fullScreen.showAppOpen(unit) : _fullScreen.showInterstitial(unit);
  }

  @override
  Future<RewardedAdResult> showRewarded(BuildContext context, String adUnitId,
      {String? placementKey, String? requestId}) async {
    final reqId = requestId ?? 'req_none';
    _followConfigRefresh();
    final unit = _unitFor(AdFormat.rewarded, adUnitId);
    if (!_ready || unit == null) {
      return RewardedAdResult.failed(
        provider: id,
        requestId: reqId,
        error: AdError(code: AdError.noFill, message: 'admob: ${notReadyReason ?? 'no unit'}'),
      );
    }
    final r = await _fullScreen.showRewarded(unit);
    if (!r.shown) {
      return RewardedAdResult.failed(
        provider: id,
        requestId: reqId,
        error: const AdError(code: AdError.noFill, message: 'admob: rewarded ad unavailable'),
      );
    }
    return r.earned
        ? RewardedAdResult.granted(provider: id, requestId: reqId)
        : RewardedAdResult.skipped(provider: id, requestId: reqId);
  }
}

/// Inline adaptive AdMob banner, as wide as its slot and capped to a slim
/// strip. Draws nothing until an ad has actually loaded.
class AdMobBannerView extends StatefulWidget {
  const AdMobBannerView({
    super.key,
    required this.adUnitId,
    this.onLoaded,
    this.onFailed,
    this.onClicked,
  });

  final String adUnitId;
  final VoidCallback? onLoaded;
  final Function(String error)? onFailed;
  final VoidCallback? onClicked;

  @override
  State<AdMobBannerView> createState() => _AdMobBannerViewState();
}

class _AdMobBannerViewState extends State<AdMobBannerView> {
  static const _maxBannerHeight = 60;

  gma.BannerAd? _ad;
  bool _loaded = false;
  bool _requested = false;
  double? _height;

  void _load(int width) {
    debugPrint('[AdMob] banner request ${widget.adUnitId} (width $width)');
    _ad = gma.BannerAd(
      adUnitId: widget.adUnitId,
      size: width >= 320
          ? gma.AdSize.getInlineAdaptiveBannerAdSize(width, _maxBannerHeight)
          : gma.AdSize.banner,
      request: const gma.AdRequest(),
      listener: gma.BannerAdListener(
        onAdLoaded: (ad) async {
          debugPrint('[AdMob] banner loaded ${widget.adUnitId}');
          final size = await (ad as gma.BannerAd).getPlatformAdSize();
          if (!mounted) return;
          setState(() {
            _height = size?.height.toDouble();
            _loaded = true;
          });
          widget.onLoaded?.call();
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          _ad = null;
          debugPrint('[AdMob] banner failed ${widget.adUnitId}: '
              '${error.code} ${error.message}');
          widget.onFailed?.call('AdMob ${error.code}: ${error.message}');
        },
        onAdClicked: (_) => widget.onClicked?.call(),
      ),
    )..load();
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _ad;
    if (!_loaded || ad == null) {
      if (_requested) return const SizedBox.shrink();
      // The ad width comes from the layout, so request on first layout.
      return LayoutBuilder(builder: (context, constraints) {
        if (!_requested) {
          _requested = true;
          final width = constraints.maxWidth.isFinite
              ? constraints.maxWidth
              : MediaQuery.sizeOf(context).width;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _load(width.truncate());
          });
        }
        return const SizedBox.shrink();
      });
    }
    final height = _height ?? ad.size.height.toDouble();
    return SizedBox(
      width: ad.size.width.toDouble(),
      height: height > 0 ? height : gma.AdSize.banner.height.toDouble(),
      child: gma.AdWidget(ad: ad),
    );
  }
}

/// AdMob native ad in Google's small template, styled from the app theme.
/// Google's template always shows the "Ad" attribution.
class AdMobNativeView extends StatefulWidget {
  const AdMobNativeView({
    super.key,
    required this.adUnitId,
    this.onLoaded,
    this.onFailed,
    this.onClicked,
  });

  final String adUnitId;
  final VoidCallback? onLoaded;
  final Function(String error)? onFailed;
  final VoidCallback? onClicked;

  @override
  State<AdMobNativeView> createState() => _AdMobNativeViewState();
}

class _AdMobNativeViewState extends State<AdMobNativeView> {
  static const double _height = 100;

  gma.NativeAd? _ad;
  bool _loaded = false;
  bool _requested = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_requested) return;
    _requested = true;
    _load(Theme.of(context).colorScheme);
  }

  void _load(ColorScheme colors) {
    debugPrint('[AdMob] native request ${widget.adUnitId}');
    _ad = gma.NativeAd(
      adUnitId: widget.adUnitId,
      request: const gma.AdRequest(),
      nativeTemplateStyle: gma.NativeTemplateStyle(
        templateType: gma.TemplateType.small,
        mainBackgroundColor: colors.surface,
        cornerRadius: 14,
        callToActionTextStyle: gma.NativeTemplateTextStyle(
          textColor: colors.onPrimary,
          backgroundColor: colors.primary,
          style: gma.NativeTemplateFontStyle.bold,
          size: 14,
        ),
        primaryTextStyle: gma.NativeTemplateTextStyle(
          textColor: colors.onSurface,
          style: gma.NativeTemplateFontStyle.bold,
          size: 15,
        ),
        secondaryTextStyle: gma.NativeTemplateTextStyle(
            textColor: colors.onSurfaceVariant, size: 13),
        tertiaryTextStyle: gma.NativeTemplateTextStyle(
            textColor: colors.onSurfaceVariant, size: 13),
      ),
      listener: gma.NativeAdListener(
        onAdLoaded: (_) {
          debugPrint('[AdMob] native loaded ${widget.adUnitId}');
          if (!mounted) return;
          setState(() => _loaded = true);
          widget.onLoaded?.call();
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          _ad = null;
          debugPrint('[AdMob] native failed ${widget.adUnitId}: '
              '${error.code} ${error.message}');
          widget.onFailed?.call('AdMob ${error.code}: ${error.message}');
        },
        onAdClicked: (_) => widget.onClicked?.call(),
      ),
    )..load();
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _ad;
    if (!_loaded || ad == null) return const SizedBox.shrink();
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(height: _height, child: gma.AdWidget(ad: ad)),
    );
  }
}
