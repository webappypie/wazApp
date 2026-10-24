// On-device check of the REAL device-authentication path (androidx.biometric via local_auth).
//
// Needs an Android device/emulator WITH a screen lock (e.g. `adb shell locksettings set-pin 1234`) and a host
// helper that types the PIN when the system prompt appears (see docs/audit/RELEASE_EVIDENCE.md).
// The test writes files/stop_pin into the app's private directory to tell the helper to stop typing.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:local_auth/local_auth.dart';
import 'package:wazapp/features/private_folder/data/device_auth_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final service = LocalDeviceAuthService();

  test('a device with a screen lock reports authentication as available', () async {
    expect(await service.availability(), AuthAvailability.available);
  });

  test('the system prompt opens and entering the device PIN returns success', () async {
    final outcome = await service.authenticate('WazApp integration test: enter the PIN');
    expect(outcome, AuthOutcome.success);
    File('/data/data/com.webappypie.wazapp/files/stop_pin').writeAsStringSync('done');
  });

  test('dismissing the prompt is reported as cancelled (never as success)', () async {
    final pending = service.authenticate('WazApp integration test: dismiss me');
    await Future<void>.delayed(const Duration(seconds: 6));
    await LocalAuthentication().stopAuthentication();
    final outcome = await pending.timeout(const Duration(seconds: 60));
    expect(outcome, isNot(AuthOutcome.success));
    expect([AuthOutcome.cancelled, AuthOutcome.failed], contains(outcome));
  });
}
