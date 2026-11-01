// lib/integrations/wapcentral/notifications/notification_backend.dart

import 'package:wap_notifications_sdk/wap_notifications.dart';

import '../wap_platform.dart';
import 'wap_notification_api.dart';

/// Source of in-app notifications. [WapNotificationBackend] talks to WAPCentral; tests supply a fake.
abstract class NotificationBackend {
  /// False when the build has no WAPCentral key; the feature is then off.
  bool get isConfigured;

  /// True when WAPCentral reports notifications disabled or the app kill switch active.
  bool get isSuppressed;

  /// Categories WAPCentral reports as active for this app (empty until the config was fetched).
  List<FeedCategory> get categories;

  Future<void> initialize({required String deviceId});

  /// Throws [NotificationsUnavailableException] when the server cannot be reached.
  Future<List<WapNotification>> fetch();

  Future<bool> markRead(String id);
  Future<bool> markAllRead();
  Future<bool> registerPushToken(String token, {required String platform});
  Future<NotificationPreferences> getPreferences();
  Future<bool> updatePreferences(NotificationPreferences preferences);

  /// Converts a push payload into a notification (foreground display).
  WapNotification fromPush(Map<String, dynamic> payload);
}

class WapNotificationBackend implements NotificationBackend {
  WapNotificationApi? _api;

  @override
  bool get isConfigured => WapPlatform.isConfigured;

  @override
  bool get isSuppressed {
    final config = WapNotifications.currentConfig;
    return config != null && !config.isEffectiveActive;
  }

  @override
  List<FeedCategory> get categories => _api?.categories ?? const [];

  @override
  Future<void> initialize({required String deviceId}) async {
    final options = WapNotificationsOptions(
      appId: WapPlatform.appId,
      appKey: WapPlatform.appKey,
      baseUrl: WapPlatform.hostUrl,
      deviceId: deviceId,
      autoFetchBell: false, // fetched explicitly so errors surface honestly
      enableLogging: false, // never print the key or payloads
    );
    _api = WapNotificationApi(options: options);
    await WapNotifications.initialize(options, apiService: _api);
  }

  @override
  Future<List<WapNotification>> fetch() => WapNotifications.notifications(refresh: true);

  @override
  Future<bool> markRead(String id) => WapNotifications.markAsRead(id);

  @override
  Future<bool> markAllRead() => WapNotifications.markAllAsRead();

  @override
  Future<bool> registerPushToken(String token, {required String platform}) =>
      // Only what WAPCentral needs: no device model, locale or user id.
      WapNotifications.registerDevice(fcmToken: token, platform: platform);

  @override
  Future<NotificationPreferences> getPreferences() => WapNotifications.getPreferences(refresh: true);

  @override
  Future<bool> updatePreferences(NotificationPreferences preferences) =>
      WapNotifications.updatePreferences(preferences);

  @override
  WapNotification fromPush(Map<String, dynamic> payload) => WapNotification.fromFcmPayload(payload);
}
