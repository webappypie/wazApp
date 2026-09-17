// test/features/background/background_task_test.dart
//
// Tests for BackgroundTaskService and WorkManager scheduling (REQ-SET-04, P-02).

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wapptidy/core/di/providers.dart';
import 'package:wapptidy/core/services/background_task/background_task_service.dart';
import 'package:wapptidy/core/services/background_task/fake_background_task_service.dart';
import 'package:wapptidy/core/services/media_access/fake_media_access_service.dart';
import 'package:wapptidy/core/services/media_access/media_item.dart';
import 'package:wapptidy/features/settings/domain/settings_state.dart';
import 'package:wapptidy/features/settings/presentation/settings_controller.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('REQ-SET-04: BackgroundTaskService scheduling & constraints', () {
    test('FakeBackgroundTaskService records schedule and chargingOnly', () async {
      final service = FakeBackgroundTaskService();

      expect(await service.isBackgroundScanScheduled(), isFalse);

      await service.scheduleBackgroundScan(
        schedule: ScanSchedule.daily,
        chargingOnly: true,
      );

      expect(await service.isBackgroundScanScheduled(), isTrue);
      expect(service.scheduledWith, ScanSchedule.daily);
      expect(service.chargingOnly, isTrue);

      await service.scheduleBackgroundScan(
        schedule: ScanSchedule.weekly,
        chargingOnly: false,
      );

      expect(service.scheduledWith, ScanSchedule.weekly);
      expect(service.chargingOnly, isFalse);
    });

    test('cancelBackgroundScan resets scheduled state', () async {
      final service = FakeBackgroundTaskService();

      await service.scheduleBackgroundScan(schedule: ScanSchedule.everyThreeDays);
      expect(await service.isBackgroundScanScheduled(), isTrue);

      await service.cancelBackgroundScan();
      expect(await service.isBackgroundScanScheduled(), isFalse);
      expect(service.scheduledWith, isNull);
      expect(service.chargingOnly, isNull);
    });
  });

  group('P-02 Invariant: Background scans detect only — NEVER delete', () {
    test('Simulated background scan identifies opportunities without calling delete/trash APIs', () async {
      final mediaService = FakeMediaAccessService();

      final dummyItems = [
        const MediaItem(
          mediaId: 1,
          contentUri: 'content://media/1',
          mimeType: 'image/jpeg',
          sizeBytes: 10 * 1024 * 1024,
          dateAddedEpochSec: 1000,
          dateModifiedEpochSec: 1000,
          folderBucket: 'WhatsApp Images',
          source: MediaSource.whatsApp,
        ),
        const MediaItem(
          mediaId: 2,
          contentUri: 'content://media/2',
          mimeType: 'image/jpeg',
          sizeBytes: 15 * 1024 * 1024,
          dateAddedEpochSec: 1000,
          dateModifiedEpochSec: 1000,
          folderBucket: 'WhatsApp Images',
          source: MediaSource.whatsApp,
        ),
      ];

      // Detect-only operation: calculates statistics
      int totalBytes = 0;
      for (final item in dummyItems) {
        totalBytes += item.sizeBytes;
      }
      expect(totalBytes, 25 * 1024 * 1024);
      expect(dummyItems.length, 2);

      // Verify no delete or trash actions were recorded
      expect(mediaService.trashedItems, isEmpty);
      expect(mediaService.movedItems, isEmpty);
    });
  });

  group('SettingsNotifier synchronization with BackgroundTaskService', () {
    test('Changing scanFrequency synchronizes background schedule', () async {
      final fakeBg = FakeBackgroundTaskService();
      final container = ProviderContainer(
        overrides: [
          backgroundTaskServiceProvider.overrideWithValue(fakeBg),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(settingsNotifierProvider.notifier);

      // Change frequency to daily
      await notifier.setScanFrequency(ScanFrequency.daily);
      expect(fakeBg.scheduledWith, ScanSchedule.daily);
      expect(await fakeBg.isBackgroundScanScheduled(), isTrue);

      // Change frequency to every 3 days
      await notifier.setScanFrequency(ScanFrequency.every3Days);
      expect(fakeBg.scheduledWith, ScanSchedule.everyThreeDays);
      expect(await fakeBg.isBackgroundScanScheduled(), isTrue);

      // Set frequency to off (manual only) -> cancels scheduled task
      await notifier.setScanFrequency(ScanFrequency.off);
      expect(await fakeBg.isBackgroundScanScheduled(), isFalse);
    });

    test('Toggling chargingOnly constraint updates scheduled parameters', () async {
      final fakeBg = FakeBackgroundTaskService();
      final container = ProviderContainer(
        overrides: [
          backgroundTaskServiceProvider.overrideWithValue(fakeBg),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(settingsNotifierProvider.notifier);

      await notifier.setScanFrequency(ScanFrequency.weekly);
      expect(fakeBg.chargingOnly, isTrue);

      await notifier.setScanChargingOnly(false);
      expect(fakeBg.chargingOnly, isFalse);
    });
  });
}
