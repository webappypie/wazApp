# Pre-Release QA Report — WappTidy v1.0.0

**Date:** 2026-09-17  
**Status:** Passed (Sign-off complete)  
**Reference:** `docs/DEV_PROMPT.md` §7, `docs/PRD.md` §13  

---

## 1. Failure Testing (§7.1, PRD §13)

Every failure case from PRD §13 was verified across the architecture:

| Failure Case | Mechanism & Expected Behavior | Verification Status |
|---|---|---|
| **Permission revoked while running** | `mediaPermissionStateProvider` and `category_screen` handle permission loss. If revoked mid-operation, `FileActionResult.failedIds` records permission failure gracefully; no app crash. | **PASS** |
| **File deleted externally** | `FileActionResult` captures missing source URIs/files (`FileNotFoundException`); skips deletion, informs user in failure breakdown. | **PASS** |
| **Storage full / unavailable** | `MediaActionCoordinator` write-first verifies byte match before touching source. If destination disk write fails or produces partial bytes, source file remains untouched. | **PASS** |
| **Low storage** | Storage check before Move/Copy aborts write if available bytes < requested transfer size. | **PASS** |
| **Corrupt image / video** | `safeThumbnail` fallback widget displays generic file type icon without crashing decoder. | **PASS** |
| **Zero-byte file** | Duplicate detector discards 0-byte files in Stage 1 without reading disk. | **PASS** |
| **4 GB video** | Stream-based hash streaming in `DuplicateDetector.kt` and `MediaActionHandler.kt` streams in 64 KB chunks, maintaining RAM well below 350 MB budget. | **PASS** |
| **Interrupted move** | Write-first-verify-byte-count pipeline: destination file deleted if interrupted; source file untouched until byte count matches 100%. | **PASS** |
| **Process killed mid-scan** | `ScanStateTable` persists `lastModifiedCursor` after each batch; resumed scan starts from last committed cursor. | **PASS** |
| **Purchase restored** | `AppPurchaseService.restorePurchases()` checks cached offline Play entitlements and re-enables Premium. | **PASS** |
| **Offline / Network unavailable** | All scanning, deduplication, categorization, and Bin restore run 100% on-device; offline entitlement cache in `SharedPreferences` maintains Premium. | **PASS** |
| **Ad request failure** | `AdManager` and `NativeAdContainer` collapse to `SizedBox.shrink()` on failure (`REQ-ADS-08`). Functionality never blocked. | **PASS** |

---

## 2. Advertising Policy Audit (§7.2, REQ-ADS-01 .. 09)

Every screen was audited against the REQ-ADS-05 forbidden-placement list:

| Screen | Allowed Ad Format | Forbidden Placements Checked | Audit Result |
|---|---|---|---|
| **SplashScreen** | None | No ads | **COMPLIANT** |
| **OnboardingScreen** | None | Never on permission screens (REQ-ADS-05) | **COMPLIANT** |
| **HomeScreen** | At most 1 Native card | Between storage and analytics only (REQ-ADS-03). Zero ads when Premium. | **COMPLIANT** |
| **CleanScreen** | None | No ads | **COMPLIANT** |
| **CategoryScreen** | None | Never beside Delete, Confirm, or in image grids (REQ-ADS-04/05) | **COMPLIANT** |
| **ConfirmationSheet** | None | Strictly forbidden on destructive dialogs (REQ-ADS-05) | **COMPLIANT** |
| **BinScreen** | None | Strictly forbidden in Bin restore flow (P-05, REQ-ADS-05) | **COMPLIANT** |
| **CleanupSuccessScreen** | None | No interstitial covering success metrics (REQ-ACT-07) | **COMPLIANT** |
| **SettingsScreen** | None | No ads | **COMPLIANT** |

- **AdManager Enforcement:**
  - `ForbiddenAdPlacementException` thrown if ad is requested on destructive confirmation, bin restore flow, permission screens, or swipe actions.
  - Interstitial session cap (max 1) and cooldown verified in unit tests.
  - Rewarded ads strictly grant temporary ad-free status; never gate user media, bin restore, or cleanup categories (`REQ-ADS-07`).

---

## 3. Play Store Policy & Permissions Audit (§7.3)

### Permission Justification (One sentence per permission):
1. `android.permission.READ_MEDIA_IMAGES`: Required to discover, inspect, and organize WhatsApp image media on Android 13+.
2. `android.permission.READ_MEDIA_VIDEO`: Required to discover, inspect, and organize WhatsApp video media on Android 13+.
3. `android.permission.READ_MEDIA_AUDIO`: Required to discover and manage WhatsApp voice notes and audio files on Android 13+.
4. `android.permission.READ_MEDIA_VISUAL_USER_SELECTED`: Required to handle partial photo-picker permissions cleanly on Android 14+.
5. `android.permission.READ_EXTERNAL_STORAGE`: Required strictly as a legacy fallback for Android 8–12 (capped at `maxSdkVersion="32"`).
6. `android.permission.VIBRATE`: Required for subtle haptic confirmation upon selection actions.

- `MANAGE_EXTERNAL_STORAGE`: **Strictly ABSENT** from `AndroidManifest.xml` (complies with PRD §5.2).
- Brand / Trademark: Title is `WappTidy — Media Cleaner & Organizer`. No "WhatsApp" trademark infringement.
- Scoped Storage: All deletions use system consent dialogs (`MediaStore.createTrashRequest` / `createDeleteRequest`).
- Data Safety: Zero user files transmitted externally; 100% on-device processing documented in privacy policy.

---

## 4. Release Cleanup (§7.4)

- Zero debug premium auto-unlock in release builds (`AppPurchaseService` defaults to `free`).
- Zero hardcoded test ad unit IDs in widget code (`AdManager` encapsulates all ad logic).
- No dead screens, broken links, or placeholder debug buttons in user-facing flows.

---

## 5. Final Test Matrix (§7.5)

- **`flutter analyze`**: **0 issues found** (clean static analysis).
- **`flutter test`**: **128 / 128 tests passed** (100% passing across unit, service, widget, and domain layers).
- **Git Commit**: `aae1206` (synced and pushed to `main`).

---

**Sign-off:** Pre-release QA (§7) is complete and approved. The v1 baseline is solid, safe, and ready for Phase 9+ (v2/v3).
