// lib/features/private_folder/data/device_auth_service.dart
//
// Thin, testable wrapper around the platform's device authentication
// (biometrics or the device PIN / pattern / password via local_auth).
//
// This is an access gate, not encryption: it only decides whether WazApp shows
// the Private Folder screen.

import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

enum AuthAvailability {
  /// The device has a screen lock / biometrics that can be used.
  available,

  /// The device supports authentication but nothing is set up (no PIN/pattern/biometric).
  notEnrolled,

  /// No authentication mechanism on this device/platform.
  unsupported,
}

enum AuthOutcome { success, cancelled, notAvailable, failed }

abstract interface class DeviceAuthService {
  Future<AuthAvailability> availability();

  /// Shows the system authentication prompt. Never throws.
  Future<AuthOutcome> authenticate(String reason);
}

class LocalDeviceAuthService implements DeviceAuthService {
  LocalDeviceAuthService([LocalAuthentication? auth]) : _auth = auth ?? LocalAuthentication();
  final LocalAuthentication _auth;

  @override
  Future<AuthAvailability> availability() async {
    try {
      if (!await _auth.isDeviceSupported()) return AuthAvailability.unsupported;
      // isDeviceSupported is true when a screen lock OR biometrics are configured.
      return AuthAvailability.available;
    } on LocalAuthException catch (e) {
      return switch (e.code) {
        LocalAuthExceptionCode.noCredentialsSet || LocalAuthExceptionCode.noBiometricsEnrolled =>
          AuthAvailability.notEnrolled,
        _ => AuthAvailability.unsupported,
      };
    } on PlatformException {
      return AuthAvailability.unsupported;
    } on MissingPluginException {
      return AuthAvailability.unsupported;
    }
  }

  @override
  Future<AuthOutcome> authenticate(String reason) async {
    try {
      final ok = await _auth.authenticate(localizedReason: reason, persistAcrossBackgrounding: false);
      return ok ? AuthOutcome.success : AuthOutcome.cancelled;
    } on LocalAuthException catch (e) {
      return switch (e.code) {
        LocalAuthExceptionCode.userCanceled ||
        LocalAuthExceptionCode.systemCanceled ||
        LocalAuthExceptionCode.timeout =>
          AuthOutcome.cancelled,
        LocalAuthExceptionCode.noCredentialsSet ||
        LocalAuthExceptionCode.noBiometricsEnrolled ||
        LocalAuthExceptionCode.noBiometricHardware ||
        LocalAuthExceptionCode.biometricHardwareTemporarilyUnavailable =>
          AuthOutcome.notAvailable,
        _ => AuthOutcome.failed,
      };
    } on PlatformException {
      return AuthOutcome.failed;
    } on MissingPluginException {
      return AuthOutcome.notAvailable;
    }
  }
}
