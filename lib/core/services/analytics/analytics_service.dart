// lib/core/services/analytics/analytics_service.dart
//
// Analytics service abstraction (P-01, P-10).
//
// Only the events listed in PRD §10 may ever be tracked. This interface
// enforces that list — adding an event means adding it here, making it
// auditable. No filenames, paths, thumbnails, or content hashes are
// ever passed to any analytics call.

/// The complete set of product events permitted by PRD §10.
enum AnalyticsEvent {
  appOpen,
  scanStarted,
  scanCompleted,
  categoryOpened,
  cleanupCompleted,
  bytesRecovered,
  moveCompleted,
  binRestore,
  premiumView,
  purchaseCompleted,
  adImpression,
}

/// Analytics service interface.
///
/// Implementations: [FakeAnalyticsService] (tests/dev), real Firebase/GA4 impl (Phase 8).
abstract interface class AnalyticsService {
  /// Log a product event with optional integer/string parameters.
  ///
  /// [params] must never include filenames, paths, contact identifiers, or
  /// media content. Only counts, sizes (in bytes), and category labels.
  Future<void> logEvent(
    AnalyticsEvent event, {
    Map<String, Object>? params,
  });

  /// Set a user property (e.g. 'premium_status': 'free'|'premium').
  /// Never include PII.
  Future<void> setUserProperty({
    required String name,
    required String value,
  });
}
