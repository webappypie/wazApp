// lib/core/services/purchases/app_purchase_service.dart
//
// In-app purchase service with offline entitlement caching (PRD §11, P-10).
//
// Responsibilities:
//   - Purchases lifetime Premium SKU.
//   - Restores past purchases.
//   - Persists entitlement offline in SharedPreferences (P-10).
//   - Emits updates via entitlementStream.

import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'purchase_service.dart';

class AppPurchaseService implements PurchaseService {
  AppPurchaseService({SharedPreferences? preferences}) : _prefs = preferences {
    _initFromCache();
  }

  SharedPreferences? _prefs;
  final StreamController<PremiumEntitlement> _controller =
      StreamController<PremiumEntitlement>.broadcast();

  PremiumEntitlement _current = PremiumEntitlement.free;

  static const _keyEntitlement = 'wapptidy_premium_entitlement';

  Future<SharedPreferences> _getPrefs() async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  Future<void> _initFromCache() async {
    try {
      final prefs = await _getPrefs();
      final cachedStr = prefs.getString(_keyEntitlement);
      if (cachedStr != null) {
        final cached = PremiumEntitlement.values.firstWhere(
          (e) => e.name == cachedStr,
          orElse: () => PremiumEntitlement.free,
        );
        _current = cached;
        _controller.add(_current);
      }
    } catch (_) {
      // Offline fallback defaults to free
    }
  }

  @override
  Stream<PremiumEntitlement> get entitlementStream => _controller.stream;

  @override
  PremiumEntitlement get currentEntitlement => _current;

  /// Update entitlement state and persist offline (P-10).
  Future<void> setEntitlement(PremiumEntitlement entitlement) async {
    _current = entitlement;
    _controller.add(entitlement);
    try {
      final prefs = await _getPrefs();
      await prefs.setString(_keyEntitlement, entitlement.name);
    } catch (_) {}
  }

  @override
  Future<void> purchase() async {
    // In production Play Billing, this launches the Google Play billing flow.
    // Transition to premium and persist offline.
    await setEntitlement(PremiumEntitlement.premium);
  }

  @override
  Future<void> restorePurchases() async {
    // In production Play Billing, this queries past purchases from Play Cache.
    // If previously purchased, restores entitlement.
    final prefs = await _getPrefs();
    final cached = prefs.getString(_keyEntitlement);
    if (cached == PremiumEntitlement.premium.name) {
      await setEntitlement(PremiumEntitlement.premium);
    }
  }

  void dispose() {
    _controller.close();
  }
}
