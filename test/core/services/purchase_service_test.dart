// test/core/services/purchase_service_test.dart
//
// Tests for AppPurchaseService with offline entitlement caching (PRD §11, P-10).

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wapptidy/core/di/providers.dart';
import 'package:wapptidy/core/services/purchases/app_purchase_service.dart';
import 'package:wapptidy/core/services/purchases/purchase_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('AppPurchaseService — Entitlement & Offline Cache', () {
    test('Defaults to free entitlement on first launch', () async {
      final service = AppPurchaseService();
      expect(service.currentEntitlement, PremiumEntitlement.free);
      service.dispose();
    });

    test('Purchase flow upgrades to premium and emits state', () async {
      final service = AppPurchaseService();

      final states = <PremiumEntitlement>[];
      final sub = service.entitlementStream.listen(states.add);

      await service.purchase();
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(service.currentEntitlement, PremiumEntitlement.premium);
      expect(states, contains(PremiumEntitlement.premium));

      await sub.cancel();
      service.dispose();
    });

    test('Offline cache persists across app restarts (P-10)', () async {
      // 1. Initial launch & purchase
      final firstLaunchService = AppPurchaseService();
      await firstLaunchService.purchase();
      expect(firstLaunchService.currentEntitlement, PremiumEntitlement.premium);
      firstLaunchService.dispose();

      // 2. Restart app — instantiate new service instance with existing cache
      final secondLaunchService = AppPurchaseService();
      // Wait for cache read
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(secondLaunchService.currentEntitlement, PremiumEntitlement.premium);
      secondLaunchService.dispose();
    });

    test('isPremiumProvider reacts immediately to purchase in Riverpod', () async {
      final container = ProviderContainer();
      final sub = container.listen(isPremiumProvider, (prev, next) {});

      expect(container.read(isPremiumProvider), isFalse);

      final purchaseService = container.read(purchaseServiceProvider);
      await purchaseService.purchase();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(container.read(isPremiumProvider), isTrue);
      sub.close();
      container.dispose();
    });
  });
}
