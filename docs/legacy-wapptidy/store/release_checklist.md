# Google Play Store Release Checklist — WappTidy

Use this operational checklist before deploying any build to Google Play Console.

---

## 1. Pre-Flight Code Quality & Tests

- [ ] Run static code analysis:
  ```bash
  flutter analyze
  ```
  *Requirement: Must return "No issues found!".*

- [ ] Execute automated test suite:
  ```bash
  flutter test
  ```
  *Requirement: All 204+ tests must pass.*

- [ ] Verify Scoped Storage compliance in `AndroidManifest.xml`:
  - `MANAGE_EXTERNAL_STORAGE` is strictly NOT declared.
  - `READ_EXTERNAL_STORAGE` includes `android:maxSdkVersion="32"`.
  - `READ_MEDIA_IMAGES`, `READ_MEDIA_VIDEO`, `READ_MEDIA_AUDIO`, and `READ_MEDIA_VISUAL_USER_SELECTED` are declared.
  - `INTERNET` and `ACCESS_NETWORK_STATE` are present for Drive and Billing APIs.

---

## 2. Versioning & Signing Configuration

- [ ] Bump version numbers in `pubspec.yaml`:
  ```yaml
  version: 1.0.0+1  # <semantic-version>+<version-code>
  ```
- [ ] Ensure `android/key.properties` exists locally:
  ```properties
  keyAlias=wapptidy_key
  keyPassword=YOUR_KEY_PASSWORD
  storeFile=../release-keystore.jks
  storePassword=YOUR_STORE_PASSWORD
  ```
- [ ] Confirm `android/key.properties` and `*.jks` are in `.gitignore` and NEVER committed.

---

## 3. Production Compilation & Bundle Generation

- [ ] Clean previous build caches:
  ```bash
  flutter clean
  flutter pub get
  ```

- [ ] Build signed Android App Bundle (AAB):
  ```bash
  flutter build appbundle --release
  ```
  *Output location: `build/app/outputs/bundle/release/app-release.aab`*

- [ ] Inspect bundle size & composition:
  ```bash
  flutter build appbundle --analyze-size --target-platform android-arm64
  ```
  *Budget check: Download size should be ≤ 25 MB.*

- [ ] (Optional) Build split APKs for real device sideload testing:
  ```bash
  flutter build apk --split-per-abi --release
  ```

---

## 4. Google Play Console Deployment

- [ ] **Track Strategy:**
  1. Upload `app-release.aab` to **Internal Testing** track first.
  2. Add internal testers and verify:
     - Onboarding flow & permission request grant.
     - Fast MediaStore query performance on physical device with 5,000+ files.
     - Video compressor output playback.
     - Voice notes audio scrub & speed switching.
     - Google Drive cloud backup using test Google account (`drive.file` scope notice appears).
     - Recycle Bin restore & delete.
  3. Inspect automated Google **Pre-Launch Report** (check for crash loops or ANRs across test devices).

- [ ] **Store Presence Setup:**
  - Copy Title & descriptions from `docs/store/listing_en.md`.
  - Upload 8 promotional screenshots generated per `docs/store/screenshot_plan.md`.
  - Upload 512x512 App Icon and 1024x500 Feature Graphic.
  - Complete Data Safety Questionnaire according to declarations in `docs/store/listing_en.md`.

- [ ] **Production Rollout:**
  - Promote build from Internal / Closed Testing to Production.
  - Start with a 20% staged rollout, monitor crash rates for 48 hours, then expand to 100%.
