// lib/core/services/background_task/background_task_service.dart
//
// Background task scheduling abstraction (PRD §11.3 — Premium: scheduled scanning).
//
// Free tier: foreground scanning only.
// Premium tier: background scanning via WorkManager (Phase 8).
//
// This interface exists in Phase 0 so that every service reference
// is mockable from day one, as required by DEV_PROMPT §3.

/// Supported scan schedule intervals (REQ-SET-04).
enum ScanSchedule {
  daily,
  everyThreeDays,
  weekly,
}

/// Background task service interface.
///
/// Implementations: [FakeBackgroundTaskService] (tests/dev), WorkManagerService (Phase 8).
abstract interface class BackgroundTaskService {
  /// Schedule recurring background scans.
  ///
  /// [chargingOnly]: if true, only run when device is charging (REQ-SET-04).
  /// Background scans DETECT ONLY — never delete (P-02).
  Future<void> scheduleBackgroundScan({
    required ScanSchedule schedule,
    bool chargingOnly = true,
  });

  /// Cancel any scheduled background scan.
  Future<void> cancelBackgroundScan();

  /// Whether a background scan is currently scheduled.
  Future<bool> isBackgroundScanScheduled();
}
