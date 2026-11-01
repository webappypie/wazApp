import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wap_ads_sdk/wap_ads.dart';
import 'package:wazapp/integrations/wapcentral/ads/ad_providers.dart';
import 'package:wazapp/integrations/wapcentral/ads/ad_slot.dart';
import 'package:wazapp/integrations/wapcentral/ads/admob_provider.dart';
import 'package:wazapp/integrations/wapcentral/ads/ads_controller.dart';

class _FakeGoogle implements GoogleAdsApi {
  _FakeGoogle({this.consent = true});
  final bool consent;
  int starts = 0;

  @override
  Future<bool> gatherConsent() async => consent;

  @override
  Future<void> start() async => starts++;
}

class _FakeAdsBackend implements AdsBackend {
  _FakeAdsBackend({this.configured = true});
  bool configured;
  bool enabled = true;
  int inits = 0;
  int refreshes = 0;

  @override
  bool get isConfigured => configured;
  @override
  bool get remoteEnabled => enabled;
  @override
  Future<void> initialize() async => inits++;
  @override
  Future<void> refresh() async => refreshes++;
}

/// Shaped like WAPCentral GET /ads/config.
EffectiveAdConfig _config({bool enabled = true, Map<String, String> admob = const {}, Set<String> off = const {}}) {
  Map<String, dynamic> format(String name) => {
        'enabled': enabled && !off.contains(name),
        'format': name,
        'mediationChain': [
          if (admob[name] != null) {'networkId': 'admob', 'priority': 2, 'adUnitId': admob[name]},
        ],
      };
  return EffectiveAdConfig.fromJson({
    'success': true,
    'data': {
      'appId': 'app_1792836068231',
      'version': 'v1',
      'enabled': enabled,
      'formats': {for (final f in ['banner', 'native']) f: format(f)},
    },
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AdMob provider', () {
    test('real AdMob provider replaces the mocks; other networks are no-fill', () {
      final providers = wazAppAdProviders();
      expect(providers.whereType<AdMobWapProvider>(), hasLength(1));
      for (final id in kMockedThirdPartyNetworks) {
        final p = providers.firstWhere((p) => p.id == id);
        expect(p, isA<NoFillAdProvider>());
        expect(p.isFormatSupported(AdFormat.banner), isFalse);
      }
    });

    test('ads disabled in WAPCentral: SDK is not started', () async {
      final api = _FakeGoogle();
      final p = AdMobWapProvider(api: api);
      await p.initialize(_config(enabled: false));
      expect(p.isReady, isFalse);
      expect(api.starts, 0);
    });

    test('units come from WAPCentral and the SDK starts once', () async {
      final api = _FakeGoogle();
      final p = AdMobWapProvider(api: api, useTestAds: false);
      final cfg = _config(admob: {'banner': 'ca-app-pub-1/2', 'native': 'ca-app-pub-1/3'});
      await p.initialize(cfg);
      await p.initialize(cfg);
      expect(p.isReady, isTrue);
      expect(p.units, {AdFormat.banner: 'ca-app-pub-1/2', AdFormat.native: 'ca-app-pub-1/3'});
      expect(api.starts, 1);
    });

    test('disabled formats are not used; consent can keep AdMob off', () async {
      final p = AdMobWapProvider(api: _FakeGoogle());
      await p.initialize(_config(admob: {'banner': 'b', 'native': 'n'}, off: {'native'}));
      expect(p.units, {AdFormat.banner: 'b'});

      final noConsent = _FakeGoogle(consent: false);
      final q = AdMobWapProvider(api: noConsent);
      await q.initialize(_config(admob: {'banner': 'b'}));
      expect(q.isReady, isFalse);
      expect(q.notReadyReason, contains('consent'));
      expect(noConsent.starts, 0);
    });

    testWidgets('not ready reports no-fill so the waterfall moves on', (tester) async {
      final p = AdMobWapProvider(api: _FakeGoogle());
      await p.initialize(_config());
      String? failure;
      await tester.pumpWidget(MaterialApp(
        home: Builder(builder: (c) => p.buildBanner(c, '', onFailed: (e) => failure = e)),
      ));
      await tester.pump();
      expect(failure, contains('admob'));
    });

    test('non-release builds request only Google test units', () {
      expect(AdMobWapProvider.testUnits.values.every((u) => u.startsWith('ca-app-pub-3940256099942544/')), isTrue);
    });
  });

  group('AdsController', () {
    ProviderContainer make(_FakeAdsBackend b) {
      final c = ProviderContainer(overrides: [adsBackendProvider.overrideWithValue(b)]);
      addTearDown(c.dispose);
      return c;
    }

    test('without a key nothing starts and no ad may be requested', () async {
      final b = _FakeAdsBackend(configured: false);
      final c = make(b);
      await c.read(adsControllerProvider.notifier).start();
      expect(c.read(adsControllerProvider), isFalse);
      expect(b.inits, 0);
    });

    test('enabled by WAPCentral => placements may request ads; start is idempotent', () async {
      final b = _FakeAdsBackend();
      final c = make(b);
      await c.read(adsControllerProvider.notifier).start();
      await c.read(adsControllerProvider.notifier).start();
      expect(c.read(adsControllerProvider), isTrue);
      expect(b.inits, 1);
    });

    test('kill switch from WAPCentral is applied on refresh', () async {
      final b = _FakeAdsBackend();
      final c = make(b);
      final n = c.read(adsControllerProvider.notifier);
      await n.start();
      b.enabled = false;
      await n.refreshIfStale(minInterval: Duration.zero);
      expect(b.refreshes, 1);
      expect(c.read(adsControllerProvider), isFalse);
    });

    testWidgets('AdSlot occupies no space when ads are off', (tester) async {
      final c = make(_FakeAdsBackend(configured: false));
      await tester.pumpWidget(UncontrolledProviderScope(
        container: c,
        child: const MaterialApp(
          home: Scaffold(body: Column(children: [AdSlot(placementKey: AdPlacements.homeNative), Text('content')])),
        ),
      ));
      expect(tester.getSize(find.byType(AdSlot)), Size.zero);
    });
  });
}
