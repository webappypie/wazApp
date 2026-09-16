// lib/core/services/purchases/purchase_service.dart
//
// In-app purchase abstraction (PRD §11).
//
// v1 model: one-time lifetime purchase only (no subscription).
// The service tracks entitlement state and persists it across
// app restarts (even offline — PRD P-10 + Phase 8 requirement).

/// Entitlement state for the Premium SKU.
enum PremiumEntitlement {
  /// User has not purchased Premium.
  free,

  /// Purchase is being verified / pending (e.g. PayU pending state).
  pending,

  /// User has a valid lifetime Premium entitlement.
  premium,
}

/// Purchase service interface.
///
/// Implementations: [FakePurchaseService] (tests/dev), Play Billing (Phase 8).
abstract interface class PurchaseService {
  /// Stream of entitlement changes (e.g. purchase completed, restored).
  Stream<PremiumEntitlement> get entitlementStream;

  /// Current entitlement, immediately available (from cache).
  PremiumEntitlement get currentEntitlement;

  /// Initiate a purchase flow for the lifetime Premium SKU.
  Future<void> purchase();

  /// Restore previous purchases (e.g. after reinstall).
  Future<void> restorePurchases();
}
