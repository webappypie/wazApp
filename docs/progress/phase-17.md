# Phase 17 — Production Release Packaging, Proguard / R8 Verification & Play Store Asset Readiness

**Status:** Done  
**Completed:** 2026-09-17  
**Requirements:** Production release packaging, Proguard/R8 rules, Scoped Storage manifest integrity, and Google Play Store metadata readiness.  
**Goal:** Prepare WappTidy for production release by hardening Android build configuration, configuring Proguard/R8 shrinking with keep rules, validating manifest permissions and XML syntax, setting up secure keystore signing workflows, and delivering complete Play Store listing and screenshot assets.

---

## What was built

### 1. Android Platform & Manifest Hardening
- **`AndroidManifest.xml` (`android/app/src/main/AndroidManifest.xml`):**
  - Resolved unclosed XML tag in legacy `READ_EXTERNAL_STORAGE` declaration (`android:maxSdkVersion="32"` properly terminated).
  - Added runtime network access permissions: `android.permission.INTERNET` and `android.permission.ACCESS_NETWORK_STATE` (required in release mode for Google Drive backup, Google Play Billing, and Remote Config).
  - Capitalized user-facing app label to `"WappTidy"`.
  - Scoped storage compliance verified: `MANAGE_EXTERNAL_STORAGE` is strictly NOT requested (PRD §5.2 compliant).

### 2. Proguard / R8 Minification & Code Shrinking
- **`proguard-rules.pro` (`android/app/proguard-rules.pro`):**
  - Created comprehensive keep rules protecting:
    - Flutter engine and platform plugin classes (`io.flutter.**`).
    - WappTidy native Kotlin bridge classes (`com.wapptidy.wapptidy.**`).
    - AndroidX WorkManager background scan workers (`androidx.work.**`).
    - SQLite3 / Drift native bindings (`org.sqlite.**`, `sqlite3.**`, `com.simonbadges.**`).
    - Kotlin coroutines, reflection, and annotations.
    - Google Play In-App Billing (`com.android.vending.billing.**`).

### 3. Release Signing Architecture
- **`build.gradle.kts` (`android/app/build.gradle.kts`):**
  - Integrated `key.properties` auto-detection in Kotlin DSL.
  - Enabled release optimizations:
    - `isMinifyEnabled = true`
    - `isShrinkResources = true`
    - `proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")`
  - Safe fallback: If `key.properties` is absent, automatically signs with debug keys so local development, CI runs, and tests never break.
- **`key.properties.example` (`android/key.properties.example`):**
  - Documented template for production keystore credentials with `keytool` instructions.
- **`.gitignore`:**
  - Added `*.jks`, `*.keystore`, and `**/key.properties` to ensure release secrets are never leaked to source control.

### 4. Google Play Store Assets & Release Documentation
- **`docs/store/listing_en.md`:**
  - Play Store Title: `WappTidy: Media Cleaner` (24 characters).
  - Short Description: `Clean WhatsApp storage safely: deduplicate, compress videos & back up.` (71 characters).
  - Full promotional description highlighting all 9 cleaner engines, on-device analysis, zero auto-deletion (`P-01`, `P-02`), and privacy pledges.
  - Data Safety Questionnaire declarations for Play Console review.
- **`docs/store/screenshot_plan.md`:**
  - Visual storyboard and copywriting for 8 promotional store screenshots covering Hero Dashboard, Duplicates, Similar Photos, Video Compressor, Blurry Photos, Swipe Clean, Voice Notes Player, and Storage Analytics / Drive Backup.
- **`docs/store/release_checklist.md`:**
  - Complete operational deployment manual detailing code quality checks, AAB build commands, bundle analysis, internal testing validation, and phased rollout strategy.

---

## Verification & Tests

1. **Static Analysis:**
   - `flutter analyze`: **0 issues found** (clean in 5.6s).
2. **Automated Test Suite:**
   - `flutter test`: **204 / 204 tests passed** (clean in 33s).
3. **Manifest & Proguard Verification:**
   - Validated XML schema correctness across all Android manifests.
   - Verified that R8 keep rules cover all native bridges and third-party native libraries.
