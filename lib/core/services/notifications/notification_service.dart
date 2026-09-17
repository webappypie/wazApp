// lib/core/services/notifications/notification_service.dart
//
// Notification service abstraction (REQ-SET-05, PRD §7.10).
//
// Channels:
//   - Storage Alerts: warn when WhatsApp storage volume exceeds threshold
//   - Scan Reminders: remind to review detected clutter when idle
//   - Weekly Tips: hygiene and cleanup guidance
//
// Conservative defaults:
//   - Storage Alerts: ON
//   - Scan Reminders: OFF
//   - Weekly Tips: OFF

/// Distinct notification categories (REQ-SET-05).
enum NotificationCategory {
  storageAlert,
  scanReminder,
  weeklyTip,
}

/// Representation of a dispatched notification.
class DispatchedNotification {
  const DispatchedNotification({
    required this.id,
    required this.channelId,
    required this.category,
    required this.title,
    required this.body,
    required this.timestamp,
  });

  final int id;
  final String channelId;
  final NotificationCategory category;
  final String title;
  final String body;
  final DateTime timestamp;
}

/// Notification service interface.
abstract interface class NotificationService {
  static const String channelStorageAlerts = 'wapptidy_storage_alerts';
  static const String channelScanReminders = 'wapptidy_scan_reminders';
  static const String channelWeeklyTips = 'wapptidy_weekly_tips';

  /// Request runtime notification permission (Android 13+ / API 33+).
  Future<bool> requestNotificationPermission();

  /// Check whether the app has notification posting permission.
  Future<bool> hasNotificationPermission();

  /// Show high-priority storage threshold alert.
  /// Returns true if notification was posted, false if suppressed (e.g. quiet hours or disabled).
  Future<bool> showStorageAlert({
    required int totalBytes,
    required int recoverableBytes,
    bool bypassQuietHours = false,
  });

  /// Show scan opportunity reminder inviting the user to review detected items.
  /// Suppressed during quiet hours and when scan reminders toggle is off.
  Future<bool> showScanOpportunityReminder({
    required int itemCount,
    required int recoverableBytes,
    DateTime? currentTime,
  });

  /// Show weekly hygiene tip.
  /// Suppressed during quiet hours and when weekly tips toggle is off.
  Future<bool> showWeeklyHygieneTip({
    required String tip,
    DateTime? currentTime,
  });

  /// Determines whether [now] falls within quiet hours (default: 22:00 to 08:00).
  bool isQuietHours(
    DateTime now, {
    int startHour = 22,
    int endHour = 8,
  });

  /// Cancel all active notifications.
  Future<void> cancelAllNotifications();
}
