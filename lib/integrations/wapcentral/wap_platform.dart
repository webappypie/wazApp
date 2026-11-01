// lib/integrations/wapcentral/wap_platform.dart
//
// Identity shared by the WAP SDK integrations (ads, notifications, promotions).
// Source: WAPCentral_WazApp_Integration_Guide.md sections 2, 6, 8.
//
// The platform key is NEVER in source (guide section 2, rule 1). Supply it at build/run time:
//   flutter run --dart-define-from-file=dart_defines.json      (file is git-ignored, see docs/WAPCENTRAL_INTEGRATION.md)
//   flutter run --dart-define=WAP_APP_KEY=<key>
// Without it ads, the notification feed/registration and promotions stay off and the app runs local-only
// (the public service-status check still works). Core media features never depend on any of this.

import 'package:flutter/foundation.dart';

import 'wapcentral_config.dart';

@immutable
class WapPlatform {
  const WapPlatform._();

  static const String appId = WapCentralConfig.defaultAppId;
  static const String appKey = String.fromEnvironment('WAP_APP_KEY');

  /// Host root: the ads/notifications SDKs append `/api/platform/v1/...` themselves.
  static const String hostUrl = 'https://wapcentral.webappypie.com';

  static bool get isConfigured => appKey.isNotEmpty;

  // Promotions are signed by WAPCentral with the Cloud KMS key `promo-signing` (RS256). The app holds only the
  // PUBLIC half, which is not a secret; anything unsigned or tampered with is dropped by wap_promo_sdk.
  // Value taken from the sibling ShotNest integration of the same platform; override after a key rotation with
  // --dart-define=PROMO_KEY_N=... --dart-define=PROMO_KEY_E=...
  static const String promoKeyId = 'promo-signing-v1';
  static const String promoKeyN = String.fromEnvironment(
    'PROMO_KEY_N',
    defaultValue: 'va88no_7vAasyxGBgnjl5x2Xd_upZ0jpvWHwebfi2R9xy6loMOlUtODPocyIl4ufrMKKGg'
        'CnPUA7LmyKqL_NAnAN7TsqW2GcBdGChBmEpcrLFZ1P7_fDqWBetRL8kSiRRR7fQHhEU9ib'
        'w-jnvEUsofboS_x0-gpy0Zt1yJZQ5F8A-4gZMU03-cqMFE08d5Oyu1OVDHrq2FWaKLpOYc'
        'MmtorLujUFXQx6Ntox40H0M0AN3knquobYgTtuGbSrL9f9mPy3kCp-6swqWsVzapppF8gB'
        'z-zaXtB1wgmJChGy89NI1SMSZE8CbKhltgnJUg-DzwMc7_hgH9lshisi2x1OYw',
  );
  static const String promoKeyE = String.fromEnvironment('PROMO_KEY_E', defaultValue: 'AQAB');

  /// The promo SDK appends `/v1/promotion` to this.
  static const String promoBaseUrl = '$hostUrl/api/platform';

  static const String appVersion = '1.0.0';
}
