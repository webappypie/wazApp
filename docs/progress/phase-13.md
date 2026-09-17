# Phase 13 — Scheduled Background Scans & Notifications (REQ-SET-04, REQ-SET-05, P-02)

**Status:** Done  
**Completed:** 2026-09-17  
**Requirements:** REQ-SET-04, REQ-SET-05, P-02; PRD §5.4, §7.10, §11.3  
**Goal:** Android WorkManager periodic background scans, multi-channel notification dispatch with conservative defaults, quiet hours protection (22:00 – 08:00), and strict enforcement of the P-02 detection-only principle.

---

## What was built

### 1. WorkManager Background Task Subsystem (REQ-SET-04, P-02)
- **PlatformBackgroundTaskService (lib/core/services/background_task/platform_background_task_service.dart):**
  - Implements BackgroundTaskService via platform channel com.wapptidy/background_work.
  - Schedules periodic work: daily (24h), everyThreeDays (72h), or weekly (168h).
  - Configures battery constraints: chargingOnly and atteryNotLow.
  - Supports instant cancellation via cancelBackgroundScan().
- **BackgroundScanWorker.kt (ndroid/app/src/main/kotlin/com/wapptidy/wapptidy/BackgroundScanWorker.kt):**
  - Android WorkManager CoroutineWorker running on Dispatchers.IO.
  - Analyzes WhatsApp media via MediaStore to compute item counts and storage volume.
  - **P-02 Invariant:** Detects opportunities only. Never deletes, moves, or mutates user files.
  - Triggers storage threshold notifications (>5GB) or scan reminders if not in quiet hours.

### 2. Multi-Channel Notification Subsystem (REQ-SET-05)
- **NotificationService (lib/core/services/notifications/notification_service.dart):**
  - Defines 3 dedicated channels:
    - wapptidy_storage_alerts: Storage Alerts (Importance: HIGH)
    - wapptidy_scan_reminders: Scan Reminders (Importance: DEFAULT)
    - wapptidy_weekly_tips: Weekly Hygiene Tips (Importance: LOW)
  - Manages permission checks (POST_NOTIFICATIONS on Android 13+) and channel creation.
  - Features isQuietHours(now) to evaluate night-time suppression.
- **PlatformNotificationService & FakeNotificationService:**
  - Real platform bridge invoking com.wapptidy/notifications.
  - In-memory fake tracking dispatched notifications, permission states, and channel IDs for testing.
- **NotificationHelper.kt (ndroid/app/src/main/kotlin/com/wapptidy/wapptidy/NotificationHelper.kt):**
  - Native channel registration and notification builder with pending intent to open MainActivity.

### 3. Conservative Defaults & Quiet Hours
- **Conservative Defaults (REQ-SET-05):**
  - Storage Alerts: **ON** (
otifyStorageAlerts = true)
  - Scan Reminders: **OFF** (
otifyScanReminders = false)
  - Weekly Hygiene Tips: **OFF** (
otifyWeeklyTips = false)
  - Scan on Charger Only: **ON** (scanChargingOnly = true)
  - Scan Frequency: **Weekly** (scanFrequency = ScanFrequency.weekly)
- **Quiet Hours Protection (22:00 – 08:00):**
  - Non-urgent notifications (scan reminders, weekly tips) are suppressed between 10 PM and 8 AM.
  - Added Quiet hours (10 PM – 8 AM) switch in Settings (settings_screen.dart).

### 4. Settings & Reactive Synchronization
- **SettingsNotifier (lib/features/settings/presentation/settings_controller.dart):**
  - Automatically synchronizes background scheduling with BackgroundTaskService upon frequency or charging-only changes.
  - Setting scanFrequency = ScanFrequency.off immediately cancels scheduled WorkManager tasks.
  - Persists quiet hours preferences in SettingsRepository.

---

## Verification & Tests

- **Background Task Tests (	est/features/background/background_task_test.dart):**
  - REQ-SET-04: Frequency scheduling maps intervals and chargingOnly flag correctly.
  - REQ-SET-04: Cancellation resets state and unschedules work.
  - P-02: Simulated background scan identifies opportunities without calling delete/trash APIs.
  - SettingsNotifier sync: changing frequency or charging constraints updates scheduled tasks immediately; setting to off cancels.
- **Notification Tests (	est/features/notifications/notification_service_test.dart):**
  - REQ-SET-05: State adheres to conservative defaults.
  - Category toggles: disabling categories prevents notification dispatch.
  - Quiet hours evaluation: accurately detects overnight hours (22:00, 23:30, 04:00) vs day hours (08:00, 14:00).
  - Quiet hours suppression: non-urgent notifications suppressed at night, allowed by day.
  - Permission gating: revoked permissions cleanly suppress notifications.
  - UI: SettingsScreen displays Quiet Hours switch in Notifications card and updates state.
- **Full Project Verification:**
  - lutter analyze: **0 issues found** (clean static analysis).
  - lutter test: **169 / 169 tests passed** (100% passing across all unit and widget tests).
