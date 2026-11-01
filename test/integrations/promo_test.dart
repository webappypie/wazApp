import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:wap_promo_sdk/wap_promo_sdk.dart';
import 'package:wazapp/integrations/wapcentral/promo/promo_card.dart';
import 'package:wazapp/integrations/wapcentral/promo/promo_controller.dart';

PromoPayload _p({
  String? id = 'c1',
  String? title = 'Try Pikiva',
  String? url = 'https://example.com/app',
  bool enabled = true,
}) =>
    PromoPayload(
      schemaVersion: 1,
      enabled: enabled,
      campaignId: id,
      title: title,
      description: 'Great app',
      ctaText: 'Get',
      storeUrl: url,
      cacheTtlSeconds: 60,
      signature: 'x',
    );

class _FakePromo implements PromoBackend {
  _FakePromo({this.configured = true});
  final bool configured;
  final notifier = ValueNotifier<PromoPayload?>(null);
  final impressions = <String>[];
  final clicks = <String>[];
  bool inited = false;

  @override
  bool get isConfigured => configured;
  @override
  Future<void> initialize() async => inited = true;
  @override
  ValueListenable<PromoPayload?> get current => notifier;
  @override
  Future<void> refresh() async {}
  @override
  void recordImpression(String campaignId) => impressions.add(campaignId);
  @override
  void recordClick(String campaignId) => clicks.add(campaignId);
}

void main() {
  VisibilityDetectorController.instance.updateInterval = Duration.zero;

  group('campaign gate', () {
    test('valid campaign is showable', () => expect(PromoController.isShowable(_p()), isTrue));

    test('missing title / id / disabled / unsafe link are rejected', () {
      expect(PromoController.isShowable(null), isFalse);
      expect(PromoController.isShowable(_p(title: ' ')), isFalse);
      expect(PromoController.isShowable(_p(id: null)), isFalse);
      expect(PromoController.isShowable(_p(enabled: false)), isFalse);
      expect(PromoController.isShowable(_p(url: 'http://example.com')), isFalse);
      expect(PromoController.isShowable(_p(url: 'javascript:alert(1)')), isFalse);
      expect(PromoController.isShowable(_p(url: 'intent://x#Intent;end')), isFalse);
    });

    test('https and market://details are the only destinations', () {
      expect(PromoController.safeDestination(_p(url: 'market://details?id=a.b')), isNotNull);
      expect(PromoController.safeDestination(_p(url: 'market://search?q=a')), isNull);
    });
  });

  group('controller + card', () {
    testWidgets('no key => nothing starts, card has zero size', (tester) async {
      final b = _FakePromo(configured: false);
      final c = ProviderContainer(overrides: [promoBackendProvider.overrideWithValue(b)]);
      addTearDown(c.dispose);
      await c.read(promoControllerProvider.notifier).start();
      expect(b.inited, isFalse);
      await tester.pumpWidget(UncontrolledProviderScope(
        container: c,
        child: const MaterialApp(home: Scaffold(body: Column(children: [PromoCard(), Text('x')]))),
      ));
      expect(tester.getSize(find.byType(PromoCard)), Size.zero);
    });

    testWidgets('server campaign renders, counts one impression, bad update hides it', (tester) async {
      final b = _FakePromo();
      final c = ProviderContainer(overrides: [promoBackendProvider.overrideWithValue(b)]);
      addTearDown(c.dispose);
      await c.read(promoControllerProvider.notifier).start();
      b.notifier.value = _p();
      await tester.pumpWidget(UncontrolledProviderScope(
        container: c,
        child: const MaterialApp(home: Scaffold(body: PromoCard())),
      ));
      expect(find.text('Try Pikiva'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 600)); // visibility detector debounce
      expect(b.impressions, ['c1']);
      b.notifier.value = _p(url: 'ftp://bad');
      await tester.pump();
      expect(find.text('Try Pikiva'), findsNothing);
    });
  });
}
