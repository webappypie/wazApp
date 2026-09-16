# Phase 07 — Actions and Bin

**Status:** Done  
**Completed:** 2026-09-17  
**Requirements:** REQ-ACT-01, REQ-ACT-02, REQ-ACT-03, REQ-ACT-04, REQ-ACT-05, REQ-ACT-06, REQ-ACT-07, REQ-BIN-01, REQ-BIN-02, REQ-BIN-03, REQ-BIN-04, REQ-BIN-05  
**Goal:** Implement Scoped Storage deletion via system confirmation dialogs, honest permanent deletion fallback for Android $\le 10$, write-first-verify-byte-count Move/Copy, protect/keep-forever guard, and ad-free Recycle Bin.

---

## What was built

### 1. Scoped Storage Deletion & OS Awareness (REQ-ACT-01, REQ-ACT-02, REQ-BIN-04)
- **Native Android Layer (`android/app/src/main/kotlin/com/wapptidy/wapptidy/MediaActionHandler.kt`):**
  - **API 30+ (Android 11+):** Uses `MediaStore.createTrashRequest(contentResolver, uris, true).intentSender` to launch the single system batch consent dialog.
  - **API 29 (Android 10):** Uses `MediaStore.createDeleteRequest(contentResolver, uris).intentSender`.
  - **API < 29 (Android $\le 9$):** Direct deletion via `contentResolver.delete(uri, null, null)`.
  - Activity result routing and pending result continuation implemented cleanly in `MainActivity.kt`.
- **Pre-Delete ConfirmationSheet:**
  - Shows item count and total size formatted.
  - Contextual OS destination:
    - Android 11+: Shows destination as "Recycle Bin", informing users of ~30-day Android retention.
    - Android $\le 10$: Explicit warning: *"⚠️ This deletion is permanent! Your device version does not support a Recycle Bin."*

### 2. Move & Copy with Byte Verification (REQ-ACT-03, REQ-ACT-06)
- **Write-First-Verify Rule:**
  - Implemented in `MediaActionHandler.kt` and abstracted in `MediaAccessService`.
  - Pipeline:
    1. Open destination `OutputStream` in external storage (`Pictures`, `Movies`, `Music`, `Documents`, or `Media Archive/<year>/<type>`).
    2. Stream bytes from source `InputStream` to destination file.
    3. **Byte Verification:** Verify `destFile.length() == srcFile.length()` (or byte counter match).
    4. Only upon 100% byte verification:
       - For Copy: register in MediaStore / local DB.
       - For Move: remove source file via `MediaStore.createTrashRequest` or `contentResolver.delete`.
    5. If byte mismatch or error occurs at any point: destination is aborted/deleted and source file is left completely intact.

### 3. Error Handling & Partial Batch Failure (REQ-ACT-04)
- Domain model `FileActionResult` tracks:
  - `succeededCount`, `failedCount`, `succeededIds`, `failedIds`, and `failureReasons` map.
- Handles collision renaming (`name (1).ext`), permission denial, storage full, and missing files with individual reporting.

### 4. Protect / Keep-Forever Rules (REQ-ACT-05)
- Stored via `is_protected` column in Drift `media_items` table and `CategoryItem.isProtected`.
- **Suggestions Guard:**
  - `duplicates_data_source.dart`, `large_videos_data_source.dart`, `screenshots_data_source.dart`, and `old_media_data_source.dart` strictly exclude protected items.
- **Deletion Guard:**
  - `MediaActionCoordinator` throws `ProtectedFileException` if delete/trash is invoked on a protected item.
  - `CategoryScreen` blocks delete if any selected item is protected and warns user via SnackBar to explicitly unprotect first.

### 5. Cleanup Success Screen (REQ-ACT-07)
- `CleanupSuccessScreen` (`lib/features/clean/presentation/cleanup_success_screen.dart`):
  - Displays space recovered and breakdown counts (items deleted/trashed, moved, copied).
  - Clear navigation back to Clean dashboard or home.
  - **NO interstitial ad covering it** (violates zero user-hostile patterns).

### 6. Recycle Bin Screen (REQ-BIN-01 .. 05)
- `BinScreen` (`lib/features/bin/presentation/bin_screen.dart`):
  - **REQ-BIN-01:** Groups trashed items by date modified: Today, Yesterday, This week, Older.
  - **REQ-BIN-02:** Selectable restore action to return files to original location.
  - **REQ-BIN-03:** Permanent delete action with clear destructive confirmation.
  - **REQ-BIN-04:** Android $\le 10$ empty state warning explaining permanent deletion.
  - **REQ-BIN-05:** Honest system retention notice banner ("Android removes items after ~30 days").
  - **Non-negotiable P-05:** Restoring media from Recycle Bin **NEVER** requires ads, purchases, or internet connection.

---

## Verification & Tests

- **Unit & Widget Test Suite (`test/features/clean/actions_and_bin_test.dart`):**
  - REQ-ACT-01, 02 & REQ-BIN-04: Confirmation sheet text and OS awareness (Android 11+ vs Android 10).
  - REQ-ACT-03: Move and Copy write-first and byte verification; source left untouched on simulated write failure.
  - REQ-ACT-04: Partial batch failures provide per-file failure summary.
  - REQ-ACT-05: Protected item deletion throws `ProtectedFileException` and blocks UI delete with warning.
  - REQ-ACT-06: Archive path generation (`Media Archive/<year>/<type>`).
  - REQ-ACT-07: CleanupSuccessScreen displays space recovered and breakdown counts.
  - REQ-BIN-01 .. 05: Recycle Bin displays honest retention banner, groups by date (Today, Yesterday, Older), restores items without paywall or ads.
- **Full Test Suite:**
  - `flutter test`: 100/100 tests passed (100% passing across the entire project).
  - `flutter analyze`: 0 issues found.
