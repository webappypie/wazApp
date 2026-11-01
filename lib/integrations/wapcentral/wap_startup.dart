// lib/integrations/wapcentral/wap_startup.dart
//
// Background start-up of the WAP integrations (guide section 11), run AFTER the first frame so launch and every
// local media feature are independent of the network. Each module fails open on its own; without the platform key
// (--dart-define=WAP_APP_KEY) ads, notifications and promotions simply stay off.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ads/ads_controller.dart';
import 'notifications/notifications_controller.dart';
import 'promo/promo_controller.dart';

class WapStartup {
  WapStartup(this._ref);
  final Ref _ref;
  bool _started = false;

  /// Starts ads, notifications and promotions. Idempotent; never throws.
  Future<void> start() async {
    if (_started) return;
    _started = true;
    await Future.wait([
      _guard(() => _ref.read(adsControllerProvider.notifier).start()),
      _guard(() => _ref.read(notificationsControllerProvider.notifier).start()),
      _guard(() => _ref.read(promoControllerProvider.notifier).start()),
    ]);
  }

  /// App returned to the foreground: refresh ad config, re-check the notification permission and feed, refresh promo.
  Future<void> onResume() async {
    if (!_started) return;
    await Future.wait([
      _guard(() => _ref.read(adsControllerProvider.notifier).refreshIfStale()),
      _guard(() => _ref.read(notificationsControllerProvider.notifier).onResume()),
      _guard(() => _ref.read(promoControllerProvider.notifier).refresh()),
    ]);
  }

  Future<void> _guard(Future<void> Function() action) async {
    try {
      await action();
    } catch (_) {}
  }
}

final wapStartupProvider = Provider<WapStartup>((ref) => WapStartup(ref));
