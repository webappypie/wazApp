# Baseline Audit

- **Date:** 2026-10-24
- **Branch / commit:** `main` @ `155aef4` ("build(android): resolve cross-drive kotlin incremental compilation…"), 20 commits
- **Toolchain / OS:** Flutter 3.47.1 stable, Dart 3.13.1, Windows 11 (10.0.26300); Android SDK 36.1.0; JDK 17 target
- **Build variants:** Android only (debug/profile/release). **No `ios/` directory.**
- **Git state:** dirty — 38 modified + 30 untracked paths (≈2.2k insertions / 0.3k deletions in tracked files). Pre-existing unreleased WappTidy work (multi-source WhatsApp/Business filter, global search, source badges, real media access service) plus the newly added documentation pack, Firebase files and WAPCentral guide. **Nothing was modified or reverted by this audit except new files in `docs/audit/`.**
- **Firebase config filenames (names only):** `google-services.json` (project `wazapp-512609`; Android package matches `com.webappypie.wazapp`), `GoogleService-Info.plist` (bundle matches `com.webappypie.wazapp.ios`). Both sit in the repo root, not where the guide says (`android/app/`, `ios/Runner/`).
- **WAPCentral guide:** `WAPCentral_WazApp_Integration_Guide.md`, Document Version 2.0 / WAPCentral 1.0, generated 24 Oct 2026; read fully. Contains an unmasked `X-App-Key` (do not commit; see A-18).

## Commands and actual results

| Command | Result |
|---|---|
| `flutter pub get` | OK ("Got dependencies!", 48 packages have newer incompatible versions) |
| `flutter analyze` | exit 1 — **16 issues, 0 errors**: mix of warnings (mostly `unused_import`, plus `unused_local_variable`, `dead_code`, `dead_null_aware_expression`, `unused_element_parameter`) and infos (`use_null_aware_elements`, `unnecessary_underscores`); full list is reproducible with `flutter analyze` |
| `flutter test` | **All 212 tests passed** (~63 s). (Repo docs claim 204.) Note many tests assert Fake* behaviour — passing ≠ real feature works |
| `flutter build apk --debug` | **OK** — `build\app\outputs\flutter-apk\app-debug.apk` (381 s). Warning: `firebase_remote_config` applies Kotlin Gradle Plugin (will fail on future Flutter) |
| `flutter build appbundle --release` | **not run** (no keystore; Gradle would silently sign with the debug key — A-06) |
| Device run | **not run in Phase 0.** `flutter devices` lists a physical Android device (model `2201116SI`, Android 13 / API 33, arm64) usable for Phase 1+ validation, plus Windows/Chrome/Edge. No on-device results are claimed |

## Environment blockers
See `KNOWN_LIMITATIONS.md` E1–E4 (no Xcode; Android licences not accepted — the debug build nonetheless succeeded; no keystore).

## Critical security / privacy findings
1. **A-02** Premium is granted without any store transaction (anyone gets "Remove Ads"; revenue/integrity P0).
2. **A-03** Fake Google Drive backup UI (fake account e-mail, simulated upload) and cloud backup is a PRD non-goal.
3. **A-18** WAPCentral `X-App-Key` is written in plain text in an untracked root file; must not enter git or logs.
4. **A-06** Release can be debug-signed silently.
5. No analytics/network code exists today, so there is currently no data exfiltration path; the manifest nonetheless requests `INTERNET`.

## Findings summary (details in `ARCHITECTURE_FINDINGS.md`, per-feature status in `FEATURE_MATRIX.md`)
- **P0:** A-01 wrong product/IDs, A-02 fake purchase, A-03 fake backup, A-04 Fakes in prod DI, A-05 Firebase unused/misplaced, A-06 debug-signing fallback, A-07 uncommitted work, A-08 no status access, A-09 no iOS, A-18 secret hygiene.
- **P1:** A-10 editors/status-maker/private folder absent, A-11 WAP SDKs unavailable, A-12 permissions over-broad, A-13 swallowed exceptions/analyzer warnings, A-14 fake-asserting tests, A-15 config model mismatch.
- **P2:** A-16, A-17.

## Recommended implementation order (after decision D1)
0. Checkpoint commit of existing uncommitted WappTidy work on a branch; start `feature/wazapp` branch.
1. **Phase 1a — Identity & hygiene:** rename to WazApp (`com.webappypie.wazapp`, Kotlin package, channels, label), teal theme tokens, move Firebase files, remove cloud backup/fake services, fix signing fallback, `.gitignore` the guide, clean analyzer.
2. **Phase 1b — Status saver + library:** SAF tree access & persisted URI, status listing (WhatsApp / Business separately), save-copy with verification into app library (Drift `saved_media` + favourites), viewer (`video_player`), search/filter/bulk actions; iOS scaffold with Photos/Files import (verification blocked).
3. Phase 2 photo editor + Hindi/English status maker; Phase 3 video editor (Media3 Transformer); Phase 4 Private Folder + Storage Manager; Phase 5 WAPCentral + AdMob + billing (needs B1–B4); Phase 6 hardening.

## Owner questions
- **D1 (blocking, product direction):** The repo is *WappTidy*, a media **cleaner**, with 17 finished phases and a different package id. The WazApp specs describe a different product (status saver/editor). Recommended: keep the reusable infrastructure (Flutter/Riverpod/Drift/router/theme/Bin/tests), rename to WazApp, **remove** cleaner-only features (similar/blurry photos, swipe clean, audio cleaner, scheduled scans, Drive backup), and build the status/editor features new. Alternative: fresh `flutter create` project, porting only selected files. This also needs your OK to (a) change `applicationId`/namespace to `com.webappypie.wazapp` and (b) commit the existing uncommitted work first.
- B1: where do the four `wap_*_sdk` packages come from (git/private registry/path) and do you have their API docs?
- B3: Play Billing product ID (and App Store IAP ID).
- B5: release keystore (or confirm I should generate an *upload* keystore for you to keep).
- Guide conflicts (promotions disabled vs. `wap_promo_sdk` required; test vs production AdMob App ID in manifest) — see `ARCHITECTURE_FINDINGS.md`.
