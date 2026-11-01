import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wap_ads_sdk/wap_ads.dart';
import 'package:wazapp/integrations/wapcentral/ads/full_screen_ads.dart';

class _Driver extends FullScreenDriver {
  _Driver();
  bool on = true;
  bool fills = true;
  final shown = <String>[];

  @override
  bool formatOn(AdFormat f) => on;

  @override
  Future<bool> interstitial(BuildContext c, String placement) async {
    if (fills) shown.add('interstitial:$placement');
    return fills;
  }

  @override
  Future<bool> appOpen(BuildContext c, String placement) async {
    if (fills) shown.add('appOpen:$placement');
    return fills;
  }

  @override
  Future<RewardedAdResult> rewarded(BuildContext c, String placement) async {
    shown.add('rewarded:$placement');
    return RewardedAdResult.granted(provider: 'admob', requestId: 'r');
  }
}

void main() {
  late DateTime now;
  late bool adsOn;
  late _Driver driver;
  late FullScreenAds ads;
  late BuildContext ctx;

  setUp(() {
    now = DateTime(2026, 10, 25, 10);
    adsOn = true;
    driver = _Driver();
    ads = FullScreenAds(() => adsOn, clock: () => now, driver: driver);
  });

  testWidgets('interstitial only after every 3rd successful save batch', (tester) async {
    await tester.pumpWidget(Builder(builder: (c) {
      ctx = c;
      return const SizedBox();
    }));
    expect(await ads.afterStatusSave(ctx, 1), isFalse);
    expect(await ads.afterStatusSave(ctx, 2), isFalse);
    expect(await ads.afterStatusSave(ctx, 1), isTrue);
    expect(driver.shown, ['interstitial:interstitial_after_save']);
  });

  testWidgets('nothing saved (failed/cancelled) never counts or shows', (tester) async {
    await tester.pumpWidget(Builder(builder: (c) {
      ctx = c;
      return const SizedBox();
    }));
    for (var i = 0; i < 6; i++) {
      expect(await ads.afterStatusSave(ctx, 0), isFalse);
    }
    expect(driver.shown, isEmpty);
  });

  testWidgets('a 4 minute gap is enforced between full-screen ads', (tester) async {
    await tester.pumpWidget(Builder(builder: (c) {
      ctx = c;
      return const SizedBox();
    }));
    for (var i = 0; i < 3; i++) {
      await ads.afterStatusSave(ctx, 1);
    }
    expect(driver.shown, hasLength(1));
    for (var i = 0; i < 3; i++) {
      await ads.afterStatusSave(ctx, 1); // 6th batch, but only seconds later
    }
    expect(driver.shown, hasLength(1));
    now = now.add(const Duration(minutes: 5));
    for (var i = 0; i < 3; i++) {
      await ads.afterStatusSave(ctx, 1);
    }
    expect(driver.shown, hasLength(2));
  });

  testWidgets('ads off, format off or no fill: nothing shown and nothing breaks', (tester) async {
    await tester.pumpWidget(Builder(builder: (c) {
      ctx = c;
      return const SizedBox();
    }));
    adsOn = false;
    for (var i = 0; i < 3; i++) {
      expect(await ads.afterStatusSave(ctx, 1), isFalse);
    }
    expect(ads.canOfferRewarded, isFalse);
    adsOn = true;
    driver.on = false;
    for (var i = 0; i < 3; i++) {
      expect(await ads.afterStatusSave(ctx, 1), isFalse);
    }
    driver
      ..on = true
      ..fills = false;
    expect(await ads.afterStatusSave(ctx, 1), isFalse);
    expect(driver.shown, isEmpty);
  });

  testWidgets('app open: needs 10 min away, a main tab, and at most once per 4 hours', (tester) async {
    await tester.pumpWidget(Builder(builder: (c) {
      ctx = c;
      return const SizedBox();
    }));
    ads.onBackgrounded();
    now = now.add(const Duration(minutes: 2)); // short trip: picker, WhatsApp, share sheet
    expect(await ads.onResumed(ctx, route: '/'), isFalse);

    ads.onBackgrounded();
    now = now.add(const Duration(minutes: 11));
    expect(await ads.onResumed(ctx, route: '/private'), isFalse);
    ads.onBackgrounded();
    now = now.add(const Duration(minutes: 11));
    expect(await ads.onResumed(ctx, route: '/photo-editor'), isFalse);
    ads.onBackgrounded();
    now = now.add(const Duration(minutes: 11));
    expect(await ads.onResumed(ctx, route: '/', blocked: true), isFalse); // service notice showing

    ads.onBackgrounded();
    now = now.add(const Duration(minutes: 11));
    expect(await ads.onResumed(ctx, route: '/saved'), isTrue);

    ads.onBackgrounded();
    now = now.add(const Duration(minutes: 30));
    expect(await ads.onResumed(ctx, route: '/'), isFalse); // within 4 hours
    ads.onBackgrounded();
    now = now.add(const Duration(hours: 4, minutes: 1));
    expect(await ads.onResumed(ctx, route: '/'), isTrue);
    expect(driver.shown.where((e) => e.startsWith('appOpen')), hasLength(2));
  });

  testWidgets('rewarded is offered only when the format is on, and only on explicit request', (tester) async {
    await tester.pumpWidget(Builder(builder: (c) {
      ctx = c;
      return const SizedBox();
    }));
    expect(ads.canOfferRewarded, isTrue);
    final r = await ads.showSupportRewarded(ctx);
    expect(r?.rewardGranted, isTrue);
    expect(driver.shown, ['rewarded:support_rewarded']);
    driver.on = false;
    expect(await ads.showSupportRewarded(ctx), isNull);
  });
}
