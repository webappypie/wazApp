// test/core/services/ad_manager_test.dart
//
// Tests for AdManager enforcing REQ-ADS-01 through REQ-ADS-09.

import 'package:flutter_test/flutter_test.dart';
import 'package:wapptidy/core/services/ads/ad_manager.dart';
import 'package:wapptidy/core/services/ads/ads_service.dart';
import 'package:wapptidy/core/services/ads/fake_ads_service.dart';
import 'package:wapptidy/core/services/remote_config/fake_remote_config_service.dart';

void main() {
  late FakeAdsService fakeAds;
  late FakeRemoteConfigService fakeConfig;
  late bool isPremium;
  late AdManager adManager;

  setUp(() {
    fakeAds = FakeAdsService()..adsAvailable = true;
    fakeConfig = FakeRemoteConfigService()
      ..adsEnabled = true
      ..nativeAdsEnabled = true
      ..interstitialAdsEnabled = true
      ..rewardedAdsEnabled = true
      ..emergencyAdsKillSwitch = false;
    isPremium = false;

    adManager = AdManager(
      service: fakeAds,
      remoteConfigService: fakeConfig,
      isPremiumCallback: () => isPremium,
    );
  });

  group('REQ-ADS-01 & REQ-ADS-03: General availability and Home placement', () {
    test('Ads permitted when user is free and config enables ads', () {
      expect(adManager.canShowAds(), isTrue);
      expect(
        adManager.canShowNativeAd(placement: AdPlacement.homeSection),
        isTrue,
      );
    });

    test('Premium users NEVER receive ads (REQ-HOM-07)', () {
      isPremium = true;
      expect(adManager.canShowAds(), isFalse);
      expect(
        adManager.canShowNativeAd(placement: AdPlacement.homeSection),
        isFalse,
      );
    });
  });

  group('REQ-ADS-04: List placement min content rows', () {
    test('List native ad blocked when items above < 10', () {
      final allowed = adManager.canShowNativeAd(
        placement: AdPlacement.listContent,
        minItemsAbove: 5,
      );
      expect(allowed, isFalse);
    });

    test('List native ad allowed when items above >= 10', () {
      final allowed = adManager.canShowNativeAd(
        placement: AdPlacement.listContent,
        minItemsAbove: 12,
      );
      expect(allowed, isTrue);
    });
  });

  group('REQ-ADS-05: Forbidden placements throw ForbiddenAdPlacementException', () {
    test('Destructive confirmation placement throws', () {
      expect(
        () => adManager.canShowNativeAd(
          placement: AdPlacement.destructiveConfirmation,
        ),
        throwsA(isA<ForbiddenAdPlacementException>()),
      );
    });

    test('Bin restore flow placement throws', () {
      expect(
        () => adManager.showInterstitial(
          placement: AdPlacement.binRestoreFlow,
        ),
        throwsA(isA<ForbiddenAdPlacementException>()),
      );
    });

    test('Permission screen placement throws', () {
      expect(
        () => adManager.canShowNativeAd(
          placement: AdPlacement.permissionScreen,
        ),
        throwsA(isA<ForbiddenAdPlacementException>()),
      );
    });

    test('Swipe action placement throws', () {
      expect(
        () => adManager.canShowNativeAd(
          placement: AdPlacement.swipeAction,
        ),
        throwsA(isA<ForbiddenAdPlacementException>()),
      );
    });
  });

  group('REQ-ADS-06: Interstitial session cap and cooldown', () {
    test('Interstitial succeeds at genuine break (post-scan summary)', () async {
      final result = await adManager.showInterstitial(
        placement: AdPlacement.postScanSummary,
      );
      expect(result, isTrue);
      expect(fakeAds.shownAds, contains(AdFormat.interstitial));
    });

    test('Second interstitial in same session blocked by session cap (cap = 1)', () async {
      final first = await adManager.showInterstitial(
        placement: AdPlacement.postScanSummary,
      );
      expect(first, isTrue);

      final second = await adManager.showInterstitial(
        placement: AdPlacement.postCleanupSession,
      );
      expect(second, isFalse);
    });
  });

  group('REQ-ADS-07: Rewarded ads strictly grant temporary ad-free period', () {
    test('Watching rewarded ad activates temporary ad-free status', () async {
      expect(adManager.isTemporaryAdFreeActive, isFalse);

      final success = await adManager.showRewardedForAdFreePeriod();
      expect(success, isTrue);
      expect(adManager.isTemporaryAdFreeActive, isTrue);

      // Now all ads should be suppressed during temporary ad-free period
      expect(adManager.canShowAds(), isFalse);
    });
  });

  group('REQ-ADS-08: Fail-safe — ad failure never throws or blocks app', () {
    test('Broken/hung ad SDK returns false gracefully without throwing', () async {
      fakeAds.blocking = true; // Simulates ad timeout/failure
      final result = await adManager.showInterstitial(
        placement: AdPlacement.postScanSummary,
      );
      expect(result, isFalse);
    });
  });

  group('REQ-ADS-09: Remote Config toggles & Emergency kill switch', () {
    test('Emergency kill switch immediately suppresses all ads', () {
      fakeConfig.emergencyAdsKillSwitch = true;
      expect(adManager.canShowAds(), isFalse);
      expect(
        adManager.canShowNativeAd(placement: AdPlacement.homeSection),
        isFalse,
      );
    });

    test('Master ads toggle disables all ads', () {
      fakeConfig.adsEnabled = false;
      expect(adManager.canShowAds(), isFalse);
    });

    test('Per-format toggle disables specific format', () {
      fakeConfig.interstitialAdsEnabled = false;
      expect(adManager.canShowAds(format: AdFormat.interstitial), isFalse);
      expect(adManager.canShowAds(format: AdFormat.native), isTrue);
    });
  });
}
