// lib/integrations/wapcentral/ads/ads_controller.dart
//
// Ads gate (guide section 8). WAPCentral decides whether ads run, which formats/placements are on and the AdMob
// ad units (GET /ads/config via wap_ads_sdk); this controller only starts the SDK in the background, keeps the
// config fresh on resume and exposes one boolean: may a placement request an ad right now?
// Without a platform key, or when WAPCentral says "disabled", the answer is false and no ad is requested.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wap_ads_sdk/wap_ads.dart';

import '../wap_platform.dart';
import 'ad_providers.dart';

/// Ad source. [WapAdsBackend] uses wap_ads_sdk; tests supply a fake.
abstract class AdsBackend {
  bool get isConfigured;

  /// Loads the remote ad config. Never throws.
  Future<void> initialize();

  /// WAPCentral master switch (`enabled` in `/ads/config`).
  bool get remoteEnabled;

  /// Re-fetches the config and applies a changed version to the providers. Never throws.
  Future<void> refresh();
}

class WapAdsBackend implements AdsBackend {
  bool _ready = false;
  String? _appliedVersion;
  final List<WapAdProvider> _providers = wazAppAdProviders();

  @override
  bool get isConfigured => WapPlatform.isConfigured;

  @override
  bool get remoteEnabled => _ready && (WapAds.currentConfig?.enabled ?? false);

  @override
  Future<void> initialize() async {
    try {
      await WapAds.initialize(
        const WapAdsOptions(
          appId: WapPlatform.appId,
          appKey: WapPlatform.appKey,
          baseUrl: WapPlatform.hostUrl,
          // Build flavour metadata only; testing vs production is decided server-side (guide section 8).
          environment: kReleaseMode ? WapEnvironment.production : WapEnvironment.development,
          testMode: false,
        ),
        // Replaces the SDK's mock third-party adapters and its hard-coded house campaign (see ad_providers.dart).
        customProviders: _providers,
      ).timeout(const Duration(seconds: 12));
      _ready = WapAds.isInitialized;
      _appliedVersion = WapAds.currentConfig?.version;
    } catch (e) {
      debugPrint('[Ads] init failed: ${e.runtimeType}');
      _ready = false;
    }
  }

  @override
  Future<void> refresh() async {
    if (!WapAds.isInitialized) return initialize();
    try {
      await WapAds.refreshConfig().timeout(const Duration(seconds: 12));
    } catch (e) {
      debugPrint('[Ads] config refresh failed: ${e.runtimeType}');
      return;
    }
    final config = WapAds.currentConfig;
    if (config == null || config.version == _appliedVersion) return;
    _appliedVersion = config.version;
    // The SDK refreshes the config but does not re-initialise providers.
    for (final p in _providers) {
      try {
        await p.initialize(config, testMode: config.testMode);
      } catch (e) {
        debugPrint('[Ads] ${p.id} re-init failed: ${e.runtimeType}');
      }
    }
  }
}

final adsBackendProvider = Provider<AdsBackend>((ref) => WapAdsBackend());

/// `true` only when a placement may request an ad.
class AdsController extends Notifier<bool> {
  bool _started = false;
  DateTime? _lastRefresh;
  Future<void>? _refreshing;

  @override
  bool build() => false;

  AdsBackend get _backend => ref.read(adsBackendProvider);

  /// Starts the SDK. Safe to call repeatedly; never throws and never blocks the UI.
  Future<void> start() async {
    if (_started || !_backend.isConfigured) return;
    _started = true;
    await _backend.initialize();
    _lastRefresh = DateTime.now();
    if (ref.mounted) state = _backend.remoteEnabled;
  }

  /// Picks up dashboard changes on app resume, at most every [minInterval].
  Future<void> refreshIfStale({Duration minInterval = const Duration(seconds: 60)}) {
    if (!_started || !_backend.isConfigured) return Future.value();
    final last = _lastRefresh;
    if (last != null && DateTime.now().difference(last) < minInterval) return Future.value();
    _lastRefresh = DateTime.now();
    return _refreshing ??= _backend.refresh().whenComplete(() {
      _refreshing = null;
      if (ref.mounted) state = _backend.remoteEnabled;
    });
  }
}

final adsControllerProvider = NotifierProvider<AdsController, bool>(AdsController.new);
