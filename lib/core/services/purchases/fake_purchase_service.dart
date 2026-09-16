// lib/core/services/purchases/fake_purchase_service.dart
//
// In-memory purchase service for tests and development.
// Starts in free tier by default. Tests can trigger purchase/restore flows.

import 'dart:async';

import 'purchase_service.dart';

final class FakePurchaseService implements PurchaseService {
  final StreamController<PremiumEntitlement> _controller =
      StreamController<PremiumEntitlement>.broadcast();

  PremiumEntitlement _entitlement = PremiumEntitlement.free;

  /// Force a specific entitlement state (useful in tests).
  void setEntitlement(PremiumEntitlement value) {
    _entitlement = value;
    _controller.add(value);
  }

  @override
  Stream<PremiumEntitlement> get entitlementStream => _controller.stream;

  @override
  PremiumEntitlement get currentEntitlement => _entitlement;

  @override
  Future<void> purchase() async {
    setEntitlement(PremiumEntitlement.premium);
  }

  @override
  Future<void> restorePurchases() async {
    // In fake: restore succeeds if entitlement is already premium; otherwise no-op.
  }

  void dispose() {
    _controller.close();
  }
}
