// lib/integrations/wapcentral/ads/full_screen_ads.dart
//
// Where full-screen ads may appear in WazApp, and when. WAPCentral still decides whether a format is on,
// which AdMob units are used and the server-side cooldowns/caps (wap_ads_sdk FrequencyManager); this file
// only picks the moments, and is deliberately conservative:
//
//   interstitial  after every 3rd successful status-save batch, at least 4 minutes after any full-screen ad.
//                 Never on failure/cancel, never while editing, never in the Private Folder.
//   app open      when the app returns after >= 10 minutes in the background, at most once per 4 hours, only on
//                 the main tabs (not Private, editors, viewer, setup) and never right after another ad.
//                 Short trips (a system picker, WhatsApp, Settings, the share sheet) never trigger it.
//   rewarded      only on the user's tap in Settings > "Support WazApp". Nothing is locked behind it.
//
// All of it is off without the platform key, when WAPCentral disables ads, offline, and on no-fill.

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wap_ads_sdk/wap_ads.dart';

import 'ads_controller.dart';

abstract final class FullScreenPlacements {
  static const interstitialAfterSave = 'interstitial_after_save';
  static const appOpenReturn = 'app_open_return';
  static const supportRewarded = 'support_rewarded';
}

/// What the ad layer can do; the default talks to wap_ads_sdk, tests substitute a fake.
class FullScreenDriver {
  const FullScreenDriver();

  bool formatOn(AdFormat f) => WapAds.currentConfig?.isFormatEnabled(f) ?? false;

  Future<bool> interstitial(BuildContext c, String placement) => WapAds.showInterstitial(c, placementKey: placement);

  Future<bool> appOpen(BuildContext c, String placement) => WapAds.showAppOpen(c, placementKey: placement);

  Future<RewardedAdResult> rewarded(BuildContext c, String placement) => WapAds.showRewarded(c, placementKey: placement);
}

class FullScreenAds {
  FullScreenAds(this._adsOn, {DateTime Function()? clock, FullScreenDriver driver = const FullScreenDriver()})
      : _now = clock ?? DateTime.now,
        // ignore: prefer_initializing_formals
        _driver = driver;

  final bool Function() _adsOn;
  final DateTime Function() _now;
  final FullScreenDriver _driver;

  static const interstitialEvery = 3;
  static const minGap = Duration(minutes: 4);
  static const minBackground = Duration(minutes: 10);
  static const appOpenEvery = Duration(hours: 4);

  /// Routes where an app-open ad may cover the screen.
  static const appOpenRoutes = {'/', '/saved', '/create', '/settings'};

  int _saveBatches = 0;
  DateTime? _lastAny;
  DateTime? _lastAppOpen;
  DateTime? _backgroundedAt;
  bool _showing = false;

  bool _formatOn(AdFormat f) => _driver.formatOn(f);

  bool _gapOk() => _lastAny == null || _now().difference(_lastAny!) >= minGap;

  /// Call after a status-save batch finished. [saved] is the number of items really saved.
  Future<bool> afterStatusSave(BuildContext context, int saved) async {
    if (saved <= 0 || !_adsOn() || _showing || !_formatOn(AdFormat.interstitial)) return false;
    _saveBatches++;
    if (_saveBatches % interstitialEvery != 0 || !_gapOk()) return false;
    return _show(() => _driver.interstitial(context, FullScreenPlacements.interstitialAfterSave));
  }

  void onBackgrounded() => _backgroundedAt = _now();

  /// Call when the app returns to the foreground. [route] is the current location, [context] a mounted context.
  Future<bool> onResumed(BuildContext context, {required String route, bool blocked = false}) async {
    final away = _backgroundedAt == null ? Duration.zero : _now().difference(_backgroundedAt!);
    _backgroundedAt = null;
    if (blocked || _showing || !_adsOn() || !_formatOn(AdFormat.appOpen)) return false;
    if (away < minBackground || !appOpenRoutes.contains(route) || !_gapOk()) return false;
    if (_lastAppOpen != null && _now().difference(_lastAppOpen!) < appOpenEvery) return false;
    final shown = await _show(() => _driver.appOpen(context, FullScreenPlacements.appOpenReturn));
    if (shown) _lastAppOpen = _now();
    return shown;
  }

  /// Whether the "Support WazApp" rewarded ad can be offered right now.
  bool get canOfferRewarded => _adsOn() && _formatOn(AdFormat.rewarded);

  /// Shows the optional rewarded ad (user tap only). The reward is a thank-you; no feature depends on it.
  Future<RewardedAdResult?> showSupportRewarded(BuildContext context) async {
    if (!canOfferRewarded || _showing) return null;
    _showing = true;
    try {
      final r = await _driver.rewarded(context, FullScreenPlacements.supportRewarded);
      _lastAny = _now();
      return r;
    } catch (_) {
      return null;
    } finally {
      _showing = false;
    }
  }

  Future<bool> _show(Future<bool> Function() show) async {
    _showing = true;
    try {
      final shown = await show();
      if (shown) _lastAny = _now();
      return shown;
    } catch (_) {
      return false;
    } finally {
      _showing = false;
    }
  }
}

final fullScreenAdsProvider = Provider<FullScreenAds>((ref) => FullScreenAds(() => ref.read(adsControllerProvider)));
