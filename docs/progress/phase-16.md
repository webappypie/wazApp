# Phase 16 — Google Drive Cloud Backup / Offload (REQ-BAK-01..03, P-01..03)

**Status:** Done  
**Completed:** 2026-09-17  
**Requirements:** REQ-BAK-01, REQ-BAK-02, REQ-BAK-03; P-01, P-02, P-03; PRD §7.9  
**Goal:** Implement safe, user-initiated Google Drive cloud backup for WhatsApp media offloading before cleanup, strictly adhering to `drive.file` non-sensitive OAuth scope, transparent item and byte progress reporting with retry support, and strict zero-deletion post-backup CTA rules.

---

## What was built

### 1. Google Drive OAuth Scope & Service Contract (REQ-BAK-01)
- **`CloudDriveScopes` (`lib/core/services/backup/cloud_backup_service.dart`):**
  - Strictly configured with `CloudDriveScopes.driveFileScope` (`https://www.googleapis.com/auth/drive.file`).
  - Guarantees privacy: App can ONLY read, write, and manage files created by WappTidy in Google Drive. Never requests the full, restricted `drive` scope.
- **Models:**
  - `CloudAccountInfo`: email, displayName, photoUrl, grantedScopes validation.
  - `CloudAuthStatus`: sealed hierarchy (`CloudAuthDisconnected`, `CloudAuthAuthenticating`, `CloudAuthConnected`, `CloudAuthError`).
  - `BackupTaskStatus`: `idle`, `preparing`, `uploading`, `paused`, `completed`, `failed`, `cancelled`.
  - `BackupMediaItem`: id, contentUri, displayName, sizeBytes, mimeType, category.
  - `BackupItemResult`: item, isSuccess, driveFileId, errorMessage, canRetry.
  - `BackupProgressSnapshot`: status, totalItems, uploadedItems, failedItems, totalBytes, uploadedBytes, currentItemName, progressRatio, failedResults.
- **Service Implementations:**
  - `CloudBackupService` abstract contract.
  - `FakeCloudBackupService`: Deterministic in-memory fake with progress streaming, pausing, cancellation, configurable failure injection, and retry processing.
  - `PlatformCloudBackupService`: Platform channel bridge (`com.wapptidy/cloud_backup`) configured with `drive.file` scope with graceful in-memory fallback.
  - Dependency Injection: Registered `cloudBackupServiceProvider` in `lib/core/di/providers.dart`.

### 2. Backup Data & State Management
- **`BackupRepository` (`lib/features/backup/data/backup_repository.dart`):**
  - Queries local database (`mediaItems`) to prepare candidate backup items for:
    - All WhatsApp Media, Large Videos (>50 MB), Old Media (>6 Months), Documents, Voice Notes & Audio, Photos.
- **`BackupController` (`lib/features/backup/presentation/backup_controller.dart`):**
  - Riverpod `Notifier<BackupState>` managing candidate filtering, live progress streaming, account connection/disconnection, pause/resume/cancel, and retry actions.
  - Safe post-backup router navigation: `reviewOriginals(context)` (`REQ-BAK-03`).

### 3. Presentation Layer (REQ-BAK-01, REQ-BAK-02, REQ-BAK-03)
- **`BackupScreen` (`lib/features/backup/presentation/backup_screen.dart`):**
  - **Account Card:** Connect / Disconnect Google Drive, account email display, and explicit `drive.file` privacy badge.
  - **Candidate Selection Card:** Filter chips with total item count and deterministic byte volume.
  - **Live Progress Card (`REQ-BAK-02`):** Live percentage progress bar, transferred MB / total MB, uploaded items / total items, active filename, pause, resume, and cancel buttons.
  - **Failure Review Card (`REQ-BAK-02`):** Displays failed files with failure reasons and a dedicated "Retry Failed" action button.
  - **Success Card (`REQ-BAK-03`):** Summary of uploaded files, reassurance note that local files are preserved, and primary CTA strictly reading **"Review originals"** (NEVER "Delete originals").
- **Settings Screen Integration:**
  - Added "Cloud Backup" section in `SettingsScreen` with Google Drive connection status and direct link to `/backup`.
- **Category Screen Integration:**
  - Added "Back up to Google Drive" to the multi-select bottom sheet menu in `CategoryScreen`, allowing direct offload of selected items.
- **Navigation:**
  - Registered `AppRoutes.cloudBackup = '/backup'` in `app_router.dart`.

---

## Verification & Tests

1. **Service & Scope Unit Tests (`test/core/services/cloud_backup_service_test.dart`):**
   - Verified `CloudDriveScopes.driveFileScope` is strictly `https://www.googleapis.com/auth/drive.file`.
   - Verified auth state changes during sign-in and sign-out.
   - Verified progress snapshot emissions, percentage calculations, and byte tracking (`P-03`).
   - Verified pausing, resuming, cancellation, error logging, and retry functionality.
2. **UI & Widget Tests (`test/features/backup/backup_screen_test.dart`):**
   - Verified Google Drive privacy notice and `drive.file` text.
   - Verified account connection state transitions.
   - Verified candidate selection and backup initiation.
   - Verified failed uploads display retry button (`REQ-BAK-02`).
   - Verified strict compliance with `REQ-BAK-03`: Post-backup CTA reads "Review originals" and never "Delete originals".
3. **Static Analysis & Full Suite Run:**
   - `flutter analyze`: **0 issues found**.
   - `flutter test`: **204 / 204 tests passed**.
