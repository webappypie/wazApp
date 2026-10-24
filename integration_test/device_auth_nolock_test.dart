// On-device check: a device WITHOUT any screen lock must be reported as unable to authenticate,
// and authenticate() must never return success. (Run after `adb shell locksettings clear --old <pin>`.)

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:wazapp/features/private_folder/data/device_auth_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final service = LocalDeviceAuthService();

  test('without a screen lock authentication is not available', () async {
    expect(await service.availability(), isNot(AuthAvailability.available));
  });

  test('authenticate never succeeds without a screen lock', () async {
    final outcome = await service.authenticate('WazApp integration test (no lock configured)');
    expect(outcome, isNot(AuthOutcome.success));
    expect(outcome, AuthOutcome.notAvailable);
  });
}
