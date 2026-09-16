// test/core/services/fake_services_test.dart
//
// Phase 0 verification: every service abstraction has a working fake implementation.
// These tests prove the fakes are usable before any real implementation exists.

import 'package:flutter_test/flutter_test.dart';
import 'package:wapptidy/core/services/analytics/analytics_service.dart';
import 'package:wapptidy/core/services/analytics/fake_analytics_service.dart';
import 'package:wapptidy/core/services/ads/ads_service.dart';
import 'package:wapptidy/core/services/ads/fake_ads_service.dart';
import 'package:wapptidy/core/services/background_task/background_task_service.dart';
import 'package:wapptidy/core/services/background_task/fake_background_task_service.dart';
import 'package:wapptidy/core/services/media_access/fake_media_access_service.dart';
import 'package:wapptidy/core/services/media_access/media_access_service.dart';
import 'package:wapptidy/core/services/media_access/media_item.dart';
import 'package:wapptidy/core/services/purchases/fake_purchase_service.dart';
import 'package:wapptidy/core/services/purchases/purchase_service.dart';
import 'package:wapptidy/core/services/remote_config/fake_remote_config_service.dart';

void main() {
  // ---------------------------------------------------------------------------
  // Analytics
  // ---------------------------------------------------------------------------
  group('FakeAnalyticsService', () {
    late FakeAnalyticsService svc;

    setUp(() => svc = FakeAnalyticsService());

    test('records events', () async {
      await svc.logEvent(AnalyticsEvent.appOpen);
      await svc.logEvent(
        AnalyticsEvent.scanCompleted,
        params: {'file_count': 1200},
      );
      expect(svc.recorded, hasLength(2));
      expect(svc.recorded.first.event, AnalyticsEvent.appOpen);
      expect(svc.recorded.last.params?['file_count'], 1200);
    });

    test('records user properties', () async {
      await svc.setUserProperty(name: 'premium_status', value: 'free');
      expect(svc.recordedProperties.first.name, 'premium_status');
    });

    test('reset clears state', () async {
      await svc.logEvent(AnalyticsEvent.appOpen);
      svc.reset();
      expect(svc.recorded, isEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  // Remote config
  // ---------------------------------------------------------------------------
  group('FakeRemoteConfigService', () {
    test('has safe ad defaults (all off)', () {
      final svc = FakeRemoteConfigService();
      expect(svc.adsEnabled, isFalse);
      expect(svc.emergencyAdsKillSwitch, isFalse);
    });

    test('can be reconfigured by tests', () {
      final svc = FakeRemoteConfigService()..adsEnabled = true;
      expect(svc.adsEnabled, isTrue);
    });

    test('fetchAndActivate is a no-op', () async {
      final svc = FakeRemoteConfigService();
      await expectLater(svc.fetchAndActivate(), completes);
    });
  });

  // ---------------------------------------------------------------------------
  // Purchases
  // ---------------------------------------------------------------------------
  group('FakePurchaseService', () {
    late FakePurchaseService svc;

    setUp(() => svc = FakePurchaseService());
    tearDown(() => svc.dispose());

    test('starts as free tier', () {
      expect(svc.currentEntitlement, PremiumEntitlement.free);
    });

    test('purchase() upgrades to premium', () async {
      await svc.purchase();
      expect(svc.currentEntitlement, PremiumEntitlement.premium);
    });

    test('entitlementStream emits on setEntitlement', () async {
      final future = svc.entitlementStream.first;
      svc.setEntitlement(PremiumEntitlement.premium);
      expect(await future, PremiumEntitlement.premium);
    });
  });

  // ---------------------------------------------------------------------------
  // Ads
  // ---------------------------------------------------------------------------
  group('FakeAdsService', () {
    late FakeAdsService svc;

    setUp(() => svc = FakeAdsService());

    test('returns AdNotAvailable when ads are off', () async {
      final result = await svc.showAd(AdFormat.native);
      expect(result, isA<AdNotAvailable>());
    });

    test('returns AdReady when ads are available', () async {
      svc.adsAvailable = true;
      final result = await svc.showAd(AdFormat.native);
      expect(result, isA<AdReady>());
      expect(svc.shownAds, contains(AdFormat.native));
    });

    test('blocking mode still returns AdNotAvailable — never throws', () async {
      svc.blocking = true;
      final result = await svc.showAd(AdFormat.interstitial);
      // Must not throw — ad failure is always swallowed (REQ-ADS-08)
      expect(result, isA<AdNotAvailable>());
    });

    test('rewarded ad sets adFreePeriodActive', () async {
      svc.adsAvailable = true;
      await svc.showAd(AdFormat.rewarded);
      expect(svc.isAdFreePeriodActive, isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // Media access
  // ---------------------------------------------------------------------------
  group('FakeMediaAccessService', () {
    late FakeMediaAccessService svc;

    setUp(() => svc = FakeMediaAccessService());

    test('starts with granted permission', () async {
      final state = await svc.checkPermission();
      expect(state, MediaPermissionState.granted);
    });

    test('queryMedia yields seeded items', () async {
      svc.items = [
        const MediaItem(
          mediaId: 1,
          contentUri: 'content://media/1',
          mimeType: 'image/jpeg',
          sizeBytes: 1024 * 1024,
          dateAddedEpochSec: 1700000000,
          dateModifiedEpochSec: 1700000000,
          folderBucket: 'WhatsApp Images',
          source: MediaSource.whatsApp,
        ),
      ];
      final batches = await svc.queryMedia(const MediaQueryOptions()).toList();
      expect(batches.expand((b) => b).length, 1);
    });

    test('can simulate permission states', () async {
      svc.permissionState = MediaPermissionState.permanentlyDenied;
      expect(await svc.checkPermission(), MediaPermissionState.permanentlyDenied);
    });

    test('trashItems removes from items list', () async {
      svc.items = [
        const MediaItem(
          mediaId: 1,
          contentUri: 'content://media/1',
          mimeType: 'image/jpeg',
          sizeBytes: 512,
          dateAddedEpochSec: 0,
          dateModifiedEpochSec: 0,
          folderBucket: 'WA Images',
          source: MediaSource.whatsApp,
        ),
      ];
      await svc.trashItems(['content://media/1']);
      expect(svc.items, isEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  // Background task
  // ---------------------------------------------------------------------------
  group('FakeBackgroundTaskService', () {
    late FakeBackgroundTaskService svc;

    setUp(() => svc = FakeBackgroundTaskService());

    test('starts with no scheduled scan', () async {
      expect(await svc.isBackgroundScanScheduled(), isFalse);
    });

    test('scheduleBackgroundScan marks as scheduled', () async {
      await svc.scheduleBackgroundScan(schedule: ScanSchedule.daily);
      expect(await svc.isBackgroundScanScheduled(), isTrue);
      expect(svc.scheduledWith, ScanSchedule.daily);
    });

    test('cancelBackgroundScan clears state', () async {
      await svc.scheduleBackgroundScan(schedule: ScanSchedule.weekly);
      await svc.cancelBackgroundScan();
      expect(await svc.isBackgroundScanScheduled(), isFalse);
      expect(svc.scheduledWith, isNull);
    });
  });
}
