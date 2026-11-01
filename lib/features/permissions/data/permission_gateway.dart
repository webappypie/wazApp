// lib/features/permissions/data/permission_gateway.dart
//
// The only place that talks to the OS permission APIs (permission_handler for runtime
// permissions, the status-access channel for settings pages and the Android API level).

import 'dart:io' show Platform;

import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/access_models.dart';

enum SettingsPage { app, security, notifications }

abstract interface class PermissionGateway {
  /// Android API level, or null where it does not apply.
  Future<int?> androidSdkInt();

  /// Current notification state, read from the OS.
  Future<AccessStatus> notificationStatus();

  /// Shows the system notification prompt when the OS still allows it; never loops.
  Future<AccessStatus> requestNotifications();

  /// Opens a system settings page. False when no such page could be opened.
  Future<bool> openSettings(SettingsPage page);
}

class PlatformPermissionGateway implements PermissionGateway {
  PlatformPermissionGateway({MethodChannel? channel})
    : _channel =
          channel ?? const MethodChannel('com.webappypie.wazapp/status_access');

  final MethodChannel _channel;
  static const _kAsked = 'notifications_prompted_v1';

  @override
  Future<int?> androidSdkInt() async {
    if (!Platform.isAndroid) return null;
    try {
      return await _channel.invokeMethod<int>('sdkInt');
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  Future<bool> _asked() async {
    try {
      return (await SharedPreferences.getInstance()).getBool(_kAsked) ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> _markAsked() async {
    try {
      await (await SharedPreferences.getInstance()).setBool(_kAsked, true);
    } catch (_) {}
  }

  @override
  Future<AccessStatus> notificationStatus() async {
    final PermissionStatus s;
    try {
      s = await Permission.notification.status;
    } catch (_) {
      return AccessStatus.unsupported;
    }
    if (s.isGranted || s.isProvisional) return AccessStatus.granted;
    if (s.isPermanentlyDenied || s.isRestricted) {
      return AccessStatus.permanentlyDenied;
    }
    // Below Android 13 there is no prompt at all: notifications are switched in system settings.
    final sdk = await androidSdkInt();
    if (sdk != null && sdk < 33) return AccessStatus.permanentlyDenied;
    return await _asked() ? AccessStatus.denied : AccessStatus.notRequested;
  }

  @override
  Future<AccessStatus> requestNotifications() async {
    final current = await notificationStatus();
    // Never re-prompt something the OS will not (or should not) prompt for.
    if (current == AccessStatus.granted ||
        current == AccessStatus.permanentlyDenied) {
      return current;
    }
    try {
      await Permission.notification.request();
    } catch (_) {}
    await _markAsked();
    return notificationStatus();
  }

  @override
  Future<bool> openSettings(SettingsPage page) async {
    if (Platform.isAndroid) {
      try {
        return await _channel.invokeMethod<bool>('openSettings', {
              'kind': page.name,
            }) ??
            false;
      } on PlatformException {
        return false;
      } on MissingPluginException {
        return false;
      }
    }
    try {
      return await openAppSettings();
    } catch (_) {
      return false;
    }
  }
}
