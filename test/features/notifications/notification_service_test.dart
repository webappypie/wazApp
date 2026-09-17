// test/features/notifications/notification_service_test.dart
//
// Tests for NotificationService, conservative defaults, quiet hours, and UI (REQ-SET-05).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wapptidy/core/design/tokens.dart';
import 'package:wapptidy/core/di/providers.dart';
import 'package:wapptidy/core/services/notifications/fake_notification_service.dart';
import 'package:wapptidy/core/services/notifications/notification_service.dart';
import 'package:wapptidy/features/settings/domain/settings_state.dart';
import 'package:wapptidy/features/settings/presentation/settings_controller.dart';
import 'package:wapptidy/features/settings/presentation/settings_screen.dart';

Widget _buildSettingsApp({FakeNotificationService? fakeNotifications}) {
  return ProviderScope(
    overrides: [
      if (fakeNotifications != null)
        notificationServiceProvider.overrideWithValue(fakeNotifications),
    ],
    child: MaterialApp(
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      home: const SettingsScreen(),
    ),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('REQ-SET-05: Conservative Defaults & State', () {
    test('SettingsState adheres to conservative notification defaults', () {
      const state = SettingsState();
      expect(state.notifyStorageAlerts, isTrue, reason: 'Storage alerts default ON');
      expect(state.notifyScanReminders, isFalse, reason: 'Scan reminders default OFF');
      expect(state.notifyWeeklyTips, isFalse, reason: 'Weekly tips default OFF');
      expect(state.quietHoursEnabled, isTrue, reason: 'Quiet hours default ON');
      expect(state.quietHoursStartHour, 22);
      expect(state.quietHoursEndHour, 8);
    });
  });

  group('REQ-SET-05: Notification Channels & Category Toggles', () {
    test('Storage Alert posts when enabled and fails when disabled', () async {
      final service = FakeNotificationService(
        storageAlertsEnabled: true,
        quietHoursEnabled: false,
      );

      final posted = await service.showStorageAlert(
        totalBytes: 5 * 1024 * 1024 * 1024,
        recoverableBytes: 1024 * 1024 * 1024,
      );
      expect(posted, isTrue);
      expect(service.dispatchedNotifications.length, 1);
      expect(service.dispatchedNotifications.first.category, NotificationCategory.storageAlert);
      expect(service.dispatchedNotifications.first.channelId, NotificationService.channelStorageAlerts);

      // Disable storage alerts
      service.storageAlertsEnabled = false;
      final postedDisabled = await service.showStorageAlert(
        totalBytes: 5 * 1024 * 1024 * 1024,
        recoverableBytes: 1024 * 1024 * 1024,
      );
      expect(postedDisabled, isFalse);
      expect(service.dispatchedNotifications.length, 1);
    });

    test('Scan Reminder respects enabled flag', () async {
      final service = FakeNotificationService(
        scanRemindersEnabled: false,
        quietHoursEnabled: false,
      );

      // Disabled by default
      final postedOff = await service.showScanOpportunityReminder(
        itemCount: 42,
        recoverableBytes: 500 * 1024 * 1024,
      );
      expect(postedOff, isFalse);
      expect(service.dispatchedNotifications, isEmpty);

      // Enable scan reminders
      service.scanRemindersEnabled = true;
      final postedOn = await service.showScanOpportunityReminder(
        itemCount: 42,
        recoverableBytes: 500 * 1024 * 1024,
      );
      expect(postedOn, isTrue);
      expect(service.dispatchedNotifications.length, 1);
      expect(service.dispatchedNotifications.first.category, NotificationCategory.scanReminder);
      expect(service.dispatchedNotifications.first.channelId, NotificationService.channelScanReminders);
    });

    test('Weekly hygiene tips respects enabled flag', () async {
      final service = FakeNotificationService(
        weeklyTipsEnabled: false,
        quietHoursEnabled: false,
      );

      final postedOff = await service.showWeeklyHygieneTip(tip: 'Review large video files!');
      expect(postedOff, isFalse);

      service.weeklyTipsEnabled = true;
      final postedOn = await service.showWeeklyHygieneTip(tip: 'Review large video files!');
      expect(postedOn, isTrue);
      expect(service.dispatchedNotifications.length, 1);
      expect(service.dispatchedNotifications.first.category, NotificationCategory.weeklyTip);
    });

    test('Permission rejection suppresses notifications', () async {
      final service = FakeNotificationService(
        permissionGranted: false,
        storageAlertsEnabled: true,
      );

      final posted = await service.showStorageAlert(
        totalBytes: 10 * 1024 * 1024 * 1024,
        recoverableBytes: 2 * 1024 * 1024 * 1024,
      );
      expect(posted, isFalse);
      expect(service.dispatchedNotifications, isEmpty);
    });
  });

  group('Quiet Hours Protection (22:00 – 08:00)', () {
    test('isQuietHours accurately detects overnight range', () {
      final service = FakeNotificationService();

      // Night / early morning hours (quiet)
      expect(service.isQuietHours(DateTime(2026, 9, 17, 22, 0)), isTrue);
      expect(service.isQuietHours(DateTime(2026, 9, 17, 23, 30)), isTrue);
      expect(service.isQuietHours(DateTime(2026, 9, 17, 0, 0)), isTrue);
      expect(service.isQuietHours(DateTime(2026, 9, 17, 3, 45)), isTrue);
      expect(service.isQuietHours(DateTime(2026, 9, 17, 7, 59)), isTrue);

      // Daytime hours (not quiet)
      expect(service.isQuietHours(DateTime(2026, 9, 17, 8, 0)), isFalse);
      expect(service.isQuietHours(DateTime(2026, 9, 17, 12, 0)), isFalse);
      expect(service.isQuietHours(DateTime(2026, 9, 17, 15, 30)), isFalse);
      expect(service.isQuietHours(DateTime(2026, 9, 17, 21, 59)), isFalse);
    });

    test('Non-urgent notifications are suppressed during quiet hours', () async {
      final service = FakeNotificationService(
        scanRemindersEnabled: true,
        weeklyTipsEnabled: true,
        quietHoursEnabled: true,
      );

      final nightTime = DateTime(2026, 9, 17, 23, 30);
      final dayTime = DateTime(2026, 9, 17, 14, 0);

      // During quiet hours -> suppressed
      final reminderAtNight = await service.showScanOpportunityReminder(
        itemCount: 15,
        recoverableBytes: 200 * 1024 * 1024,
        currentTime: nightTime,
      );
      expect(reminderAtNight, isFalse);

      final tipAtNight = await service.showWeeklyHygieneTip(
        tip: 'Check duplicates!',
        currentTime: nightTime,
      );
      expect(tipAtNight, isFalse);
      expect(service.dispatchedNotifications, isEmpty);

      // During daytime -> posted
      final reminderAtDay = await service.showScanOpportunityReminder(
        itemCount: 15,
        recoverableBytes: 200 * 1024 * 1024,
        currentTime: dayTime,
      );
      expect(reminderAtDay, isTrue);
      expect(service.dispatchedNotifications.length, 1);
    });
  });

  group('UI: SettingsScreen Quiet Hours Switch', () {
    testWidgets('Displays Quiet Hours switch in Notifications card and updates state', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_buildSettingsApp());
      await tester.pumpAndSettle();

      expect(find.text('Quiet hours (10 PM – 8 AM)'), findsOneWidget);
      expect(find.text('Mute non-urgent notifications late at night'), findsOneWidget);

      final element = tester.element(find.byType(SettingsScreen));
      final notifier = ProviderScope.containerOf(element).read(settingsNotifierProvider.notifier);

      // Toggle quiet hours off
      await notifier.setQuietHoursEnabled(false);
      await tester.pumpAndSettle();

      final state = ProviderScope.containerOf(element).read(settingsNotifierProvider);
      expect(state.quietHoursEnabled, isFalse);
    });
  });
}
