// lib/integrations/wapcentral/promo/promo_controller.dart
//
// WAPCentral-managed promotions via wap_promo_sdk. Cache-first, never blocks launch. The SDK accepts a campaign
// only when its RS256 signature verifies against WAPCentral's public key and it is enabled, unexpired and not
// frequency-capped. On top of that a campaign needs a title and a safe destination (https or market://details).
// Nothing about the user's media is sent: the request carries only the app id, version and platform.
//
// Guide note: section 5 lists wap_promo_sdk as required while section 8 says external *ad* house promotions are
// not required. Both are honoured: this is the first-party promotion surface, and it renders nothing unless the
// server returns a valid, signed campaign.

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wap_promo_sdk/wap_promo_sdk.dart';

import '../wap_platform.dart';

abstract class PromoBackend {
  bool get isConfigured;
  Future<void> initialize();

  /// The current verified, unexpired, not frequency-capped campaign.
  ValueListenable<PromoPayload?> get current;
  Future<void> refresh();
  void recordImpression(String campaignId);
  void recordClick(String campaignId);
}

class WapPromoBackend implements PromoBackend {
  final _empty = ValueNotifier<PromoPayload?>(null);

  @override
  bool get isConfigured =>
      WapPlatform.isConfigured && WapPlatform.promoKeyN.isNotEmpty && WapPlatform.promoKeyE.isNotEmpty;

  @override
  Future<void> initialize() async {
    try {
      await WapPromoSdk.init(PromoConfig(
        appId: WapPlatform.appId,
        appKey: WapPlatform.appKey,
        baseUrl: WapPlatform.promoBaseUrl,
        verificationKeys: {
          WapPlatform.promoKeyId: PromoRsaPublicKey.fromJwk(n: WapPlatform.promoKeyN, e: WapPlatform.promoKeyE),
        },
        appVersion: WapPlatform.appVersion,
        platform: defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android',
        environment: kReleaseMode ? 'production' : 'development',
      ));
    } catch (e) {
      debugPrint('[Promotions] init failed: ${e.runtimeType}');
    }
  }

  @override
  ValueListenable<PromoPayload?> get current => WapPromoSdk.isReady ? WapPromoSdk.promoNotifier : _empty;

  @override
  Future<void> refresh() async {
    try {
      await WapPromoSdk.refresh();
    } catch (_) {}
  }

  @override
  void recordImpression(String campaignId) => WapPromoSdk.recordImpression(campaignId);

  @override
  void recordClick(String campaignId) => WapPromoSdk.recordClick(campaignId);
}

final promoBackendProvider = Provider<PromoBackend>((ref) => WapPromoBackend());

/// The campaign to show, or null.
class PromoController extends Notifier<PromoPayload?> {
  bool _started = false;
  ValueListenable<PromoPayload?>? _source;

  @override
  PromoPayload? build() {
    ref.onDispose(() => _source?.removeListener(_onChanged));
    return null;
  }

  PromoBackend get _backend => ref.read(promoBackendProvider);

  Future<void> start() async {
    if (_started || !_backend.isConfigured) return;
    _started = true;
    await _backend.initialize();
    _source = _backend.current..addListener(_onChanged);
    _onChanged();
  }

  Future<void> refresh() async {
    if (!_started) return;
    await _backend.refresh();
  }

  void _onChanged() {
    if (!ref.mounted) return;
    final p = _source?.value;
    state = isShowable(p) ? p : null;
  }

  void recordImpression(PromoPayload p) => _backend.recordImpression(p.campaignId!);
  void recordClick(PromoPayload p) => _backend.recordClick(p.campaignId!);

  /// A campaign is shown only with content, an id, a title and a safe destination.
  @visibleForTesting
  static bool isShowable(PromoPayload? p) {
    if (p == null || !p.hasContent || p.campaignId == null) return false;
    if ((p.title ?? '').trim().isEmpty) return false;
    return safeDestination(p) != null;
  }

  /// Only https links and Play Store `market://details` links are opened.
  static Uri? safeDestination(PromoPayload p) {
    final uri = Uri.tryParse(p.storeUrl ?? '');
    if (uri == null) return null;
    if (uri.scheme == 'https' && uri.host.isNotEmpty) return uri;
    if (uri.scheme == 'market' && uri.host == 'details') return uri;
    return null;
  }
}

final promoControllerProvider = NotifierProvider<PromoController, PromoPayload?>(PromoController.new);
