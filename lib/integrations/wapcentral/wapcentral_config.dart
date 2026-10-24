// lib/integrations/wapcentral/wapcentral_config.dart
//
// Public WAPCentral identifiers taken from WAPCentral_WazApp_Integration_Guide.md (sections 2, 6, 9).
//
// Secrets: the platform key (`X-App-Key`) is NEVER written in source. It is read from the build with
//   flutter build ... --dart-define=WAP_APP_KEY=<key>
// (guide section 2, rule 1). The service-status endpoint is documented as "Public or standard platform
// auth headers", so it works without a key; the key is only attached when the build provides one.

import 'package:flutter/foundation.dart';

@immutable
class WapCentralConfig {
  const WapCentralConfig({
    this.baseUrl = defaultBaseUrl,
    this.appId = defaultAppId,
    this.appKey = '',
    this.timeout = const Duration(seconds: 5),
  });

  /// Reads the optional key from `--dart-define=WAP_APP_KEY=...` (empty when not provided).
  factory WapCentralConfig.fromEnvironment() =>
      const WapCentralConfig(appKey: String.fromEnvironment('WAP_APP_KEY'));

  /// Production gateway (guide section 6).
  static const defaultBaseUrl = 'https://wapcentral.webappypie.com/api/platform/v1';

  /// Public application identifier (guide sections 2 and 6: "Public application identifier passed in X-App-Id").
  static const defaultAppId = 'app_1792836068231';

  final String baseUrl;
  final String appId;
  final String appKey;

  /// Guide section 9 reference implementation uses a 5 second timeout.
  final Duration timeout;

  bool get hasKey => appKey.isNotEmpty;

  /// `GET /apps/{appId}/service-status` (guide section 9).
  Uri get serviceStatusUri => Uri.parse('$baseUrl/apps/$appId/service-status');

  /// Headers for a platform request. The key is attached only when configured.
  Map<String, String> get headers => {
        'X-App-Id': appId,
        if (hasKey) 'X-App-Key': appKey,
        'Accept': 'application/json',
      };

  // Never let the key leak through toString()/logging.
  @override
  String toString() => 'WapCentralConfig(baseUrl: $baseUrl, appId: $appId, appKey: ${hasKey ? '<redacted>' : '<none>'})';
}
