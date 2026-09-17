// lib/core/services/notifications/fake_notification_service.dart
//
// In-memory fake notification service for testing and development.
// Verifies REQ-SET-05 conservative defaults, quiet hours, and category toggles.

import 'notification_service.dart';

class FakeNotificationService implements NotificationService {
  FakeNotificationService({
    this.permissionGranted = true,
    this.storageAlertsEnabled = true,
    this.scanRemindersEnabled = false,
    this.weeklyTipsEnabled = false,
    this.quietHoursEnabled = true,
    this.quietHoursStart = 22,
    this.quietHoursEnd = 8,
  });

  bool permissionGranted;
  bool storageAlertsEnabled;
  bool scanRemindersEnabled;
  bool weeklyTipsEnabled;
  bool quietHoursEnabled;
  int quietHoursStart;
  int quietHoursEnd;

  final List<DispatchedNotification> dispatchedNotifications = [];
  int _nextId = 1;

  void reset() {
    permissionGranted = true;
    storageAlertsEnabled = true;
    scanRemindersEnabled = false;
    weeklyTipsEnabled = false;
    quietHoursEnabled = true;
    quietHoursStart = 22;
    quietHoursEnd = 8;
    dispatchedNotifications.clear();
    _nextId = 1;
  }

  @override
  bool isQuietHours(
    DateTime now, {
    int startHour = 22,
    int endHour = 8,
  }) {
    if (startHour > endHour) {
      // Crosses midnight, e.g. 22:00 to 08:00
      return now.hour >= startHour || now.hour < endHour;
    } else if (startHour < endHour) {
      // Same day interval
      return now.hour >= startHour && now.hour < endHour;
    } else {
      return false;
    }
  }

  @override
  Future<bool> requestNotificationPermission() async {
    return permissionGranted;
  }

  @override
  Future<bool> hasNotificationPermission() async {
    return permissionGranted;
  }

  @override
  Future<bool> showStorageAlert({
    required int totalBytes,
    required int recoverableBytes,
    bool bypassQuietHours = false,
  }) async {
    if (!permissionGranted || !storageAlertsEnabled) return false;

    final now = DateTime.now();
    if (!bypassQuietHours && quietHoursEnabled && isQuietHours(now, startHour: quietHoursStart, endHour: quietHoursEnd)) {
      return false;
    }

    final totalMb = (totalBytes / (1024 * 1024)).round();
    final recMb = (recoverableBytes / (1024 * 1024)).round();

    final notification = DispatchedNotification(
      id: _nextId++,
      channelId: NotificationService.channelStorageAlerts,
      category: NotificationCategory.storageAlert,
      title: 'WhatsApp Storage Alert',
      body: 'WhatsApp media is using ${totalMb}MB. Tap to reclaim up to ${recMb}MB of space.',
      timestamp: now,
    );
    dispatchedNotifications.add(notification);
    return true;
  }

  @override
  Future<bool> showScanOpportunityReminder({
    required int itemCount,
    required int recoverableBytes,
    DateTime? currentTime,
  }) async {
    if (!permissionGranted || !scanRemindersEnabled) return false;

    final now = currentTime ?? DateTime.now();
    if (quietHoursEnabled && isQuietHours(now, startHour: quietHoursStart, endHour: quietHoursEnd)) {
      return false;
    }

    final recMb = (recoverableBytes / (1024 * 1024)).round();

    final notification = DispatchedNotification(
      id: _nextId++,
      channelId: NotificationService.channelScanReminders,
      category: NotificationCategory.scanReminder,
      title: 'Cleanup Opportunities Found',
      body: '$itemCount items (${recMb}MB) ready for your review.',
      timestamp: now,
    );
    dispatchedNotifications.add(notification);
    return true;
  }

  @override
  Future<bool> showWeeklyHygieneTip({
    required String tip,
    DateTime? currentTime,
  }) async {
    if (!permissionGranted || !weeklyTipsEnabled) return false;

    final now = currentTime ?? DateTime.now();
    if (quietHoursEnabled && isQuietHours(now, startHour: quietHoursStart, endHour: quietHoursEnd)) {
      return false;
    }

    final notification = DispatchedNotification(
      id: _nextId++,
      channelId: NotificationService.channelWeeklyTips,
      category: NotificationCategory.weeklyTip,
      title: 'WappTidy Tip',
      body: tip,
      timestamp: now,
    );
    dispatchedNotifications.add(notification);
    return true;
  }

  @override
  Future<void> cancelAllNotifications() async {
    dispatchedNotifications.clear();
  }
}
