// lib/integrations/wapcentral/notifications/push_gateway.dart
//
// FCM transport behind a seam for tests. This layer never shows the OS permission prompt on its own: the
// permission setup / Settings screens request POST_NOTIFICATIONS from a user action and then call
// NotificationsController.syncRegistration(). A token is fetched and registered only when permission is granted.

import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

abstract class PushGateway {
  /// Initialises Firebase/FCM. False when push is unavailable (no Play services, init failure).
  Future<bool> initialize();

  /// True when the user has allowed system notifications. Never prompts.
  Future<bool> isPermissionGranted();

  Future<String?> token();
  Stream<String> get onTokenRefresh;

  /// Pushes received while the app is in the foreground.
  Stream<Map<String, dynamic>> get onForegroundMessage;

  /// Pushes the user tapped (app in background, or launched from the tap).
  Stream<Map<String, dynamic>> get onMessageOpened;
  Future<Map<String, dynamic>?> initialMessage();
}

class FirebasePushGateway implements PushGateway {
  bool _ready = false;

  @override
  Future<bool> initialize() async {
    try {
      if (Firebase.apps.isEmpty) await Firebase.initializeApp();
      // Foreground pushes are shown in the app (bell), not as a duplicate system banner.
      await FirebaseMessaging.instance
          .setForegroundNotificationPresentationOptions(alert: false, badge: true, sound: false);
      _ready = true;
    } catch (e) {
      debugPrint('[Push] Firebase unavailable: ${e.runtimeType}');
      _ready = false;
    }
    return _ready;
  }

  @override
  Future<bool> isPermissionGranted() async {
    if (!_ready) return false;
    try {
      final s = await FirebaseMessaging.instance.getNotificationSettings();
      return s.authorizationStatus == AuthorizationStatus.authorized ||
          s.authorizationStatus == AuthorizationStatus.provisional;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<String?> token() async {
    if (!_ready) return null;
    try {
      return await FirebaseMessaging.instance.getToken();
    } catch (e) {
      debugPrint('[Push] token unavailable: ${e.runtimeType}');
      return null;
    }
  }

  @override
  Stream<String> get onTokenRefresh => _ready ? FirebaseMessaging.instance.onTokenRefresh : const Stream.empty();

  @override
  Stream<Map<String, dynamic>> get onForegroundMessage =>
      _ready ? FirebaseMessaging.onMessage.map(_toMap) : const Stream.empty();

  @override
  Stream<Map<String, dynamic>> get onMessageOpened =>
      _ready ? FirebaseMessaging.onMessageOpenedApp.map(_toMap) : const Stream.empty();

  @override
  Future<Map<String, dynamic>?> initialMessage() async {
    if (!_ready) return null;
    try {
      final m = await FirebaseMessaging.instance.getInitialMessage();
      return m == null ? null : _toMap(m);
    } catch (_) {
      return null;
    }
  }

  // WAPCentral sends the image as the FCM notification image (android.imageUrl), not in `data`.
  static Map<String, dynamic> _toMap(RemoteMessage m) {
    final image = m.notification?.android?.imageUrl ?? m.notification?.apple?.imageUrl;
    return {
      'messageId': m.messageId,
      'notification': {
        if (m.notification?.title != null) 'title': m.notification!.title,
        if (m.notification?.body != null) 'body': m.notification!.body,
        if (image != null && image.isNotEmpty) 'image': image,
      },
      'data': Map<String, dynamic>.from(m.data),
    };
  }
}
