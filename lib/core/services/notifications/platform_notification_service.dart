// lib/core/services/notifications/platform_notification_service.dart
//
// Platform channel implementation for notifications (Android NotificationManager).

import 'package:flutter/services.dart';
import 'notification_service.dart';

class PlatformNotificationService implements NotificationService {
  PlatformNotificationService({
    MethodChannel? channel,
  }) : _channel = channel ?? const MethodChannel('com.wapptidy/notifications');

  final MethodChannel _channel;
  int _nextId = 100;

  @override
  bool isQuietHours(
    DateTime now, {
    int startHour = 22,
    int endHour = 8,
  }) {
    if (startHour > endHour) {
      return now.hour >= startHour || now.hour < endHour;
    } else if (startHour < endHour) {
      return now.hour >= startHour && now.hour < endHour;
    } else {
      return false;
    }
  }

  @override
  Future<bool> requestNotificationPermission() async {
    try {
      final granted = await _channel.invokeMethod<bool>('requestPermission');
      return granted ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> hasNotificationPermission() async {
    try {
      final granted = await _channel.invokeMethod<bool>('hasPermission');
      return granted ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> showStorageAlert({
    required int totalBytes,
    required int recoverableBytes,
    bool bypassQuietHours = false,
  }) async {
    if (!bypassQuietHours && isQuietHours(DateTime.now())) {
      return false;
    }

    final totalMb = (totalBytes / (1024 * 1024)).round();
    final recMb = (recoverableBytes / (1024 * 1024)).round();

    try {
      final posted = await _channel.invokeMethod<bool>('showNotification', {
        'id': _nextId++,
        'channelId': NotificationService.channelStorageAlerts,
        'title': 'WhatsApp Storage Alert',
        'body': 'WhatsApp media is using ${totalMb}MB. Tap to reclaim up to ${recMb}MB of space.',
      });
      return posted ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> showScanOpportunityReminder({
    required int itemCount,
    required int recoverableBytes,
    DateTime? currentTime,
  }) async {
    final now = currentTime ?? DateTime.now();
    if (isQuietHours(now)) {
      return false;
    }

    final recMb = (recoverableBytes / (1024 * 1024)).round();

    try {
      final posted = await _channel.invokeMethod<bool>('showNotification', {
        'id': _nextId++,
        'channelId': NotificationService.channelScanReminders,
        'title': 'Cleanup Opportunities Found',
        'body': '$itemCount items (${recMb}MB) ready for your review.',
      });
      return posted ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> showWeeklyHygieneTip({
    required String tip,
    DateTime? currentTime,
  }) async {
    final now = currentTime ?? DateTime.now();
    if (isQuietHours(now)) {
      return false;
    }

    try {
      final posted = await _channel.invokeMethod<bool>('showNotification', {
        'id': _nextId++,
        'channelId': NotificationService.channelWeeklyTips,
        'title': 'WappTidy Tip',
        'body': tip,
      });
      return posted ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> cancelAllNotifications() async {
    try {
      await _channel.invokeMethod<void>('cancelAll');
    } catch (_) {}
  }
}
