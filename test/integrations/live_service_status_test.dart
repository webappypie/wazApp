// Opt-in check against the REAL WAPCentral gateway (read-only GET, no key, no personal data):
//   flutter test --dart-define=WAZAPP_LIVE=true test/integrations/live_service_status_test.dart
// Skipped in the normal suite so tests never depend on the network.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:wazapp/integrations/wapcentral/service_control_client.dart';
import 'package:wazapp/integrations/wapcentral/wapcentral_config.dart';

const _live = bool.fromEnvironment('WAZAPP_LIVE');

void main() {
  test('the live service-status endpoint answers in the documented shape', () async {
    HttpOverrides.global = null; // flutter test blocks real HTTP by default
    final client = ServiceControlClient(config: const WapCentralConfig());
    final status = await client.fetch();
    // ignore: avoid_print
    print('live status: enabled=${status.enabled} source=${status.source} reason=${status.failureReason}');
    expect(status.source, StatusSource.server, reason: 'failed open: ${status.failureReason}');
    expect(status.enabled, isA<bool>());
    client.close();
  }, skip: _live ? false : 'set --dart-define=WAZAPP_LIVE=true to run against the real gateway');
}
