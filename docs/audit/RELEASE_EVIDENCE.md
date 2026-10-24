# Release Evidence

Only commands that were actually run are listed. Host: Windows 11, Flutter 3.47.1 / Dart 3.13.1, Android SDK 36.1.0. Branch `feature/wazapp`.

## Phase 2 (end state, 2026-10-24)

| Check | Command | Result |
|---|---|---|
| Static analysis | `flutter analyze` | **No issues found** |
| Automated tests | `flutter test` | **145 passed, 0 failed** (was 51 after Phase 1). New: renderer pixel tests, crop math (incl. 32 locked-ratio drag cases), real-codec export tests, editor widget tests (7), status renderer (13: 26 templates pairwise distinct, no clipping for 300-char EN/HI text, Devanagari conjunct shaping and Latin-font fallback with the real bundled fonts), status maker UI/service (7: all 26 templates export 1080×1920 PNG) |
| Android debug build (with fonts/assets, `image` dep) | `flutter build apk --debug` | **OK** (597 s) |
| Install on physical device | `adb install -r app-debug.apk` | **FAILED again: `INSTALL_FAILED_USER_RESTRICTED`** (owner has not yet enabled "Install via USB") |
| Visual check of editor / status maker on a device or emulator | – | **not done** — no screenshots exist; Devanagari output has been checked only by metric/ink tests, not by eye |
| Performance (export time of 12 MP photo, preview FPS, memory) | – | **not measured** |

### What the Phase 2 tests prove / do not prove
Proven (real `dart:ui` rendering and codecs in `flutter test`): geometry (rotate/flip/crop order), colour maths clamping, every filter changes pixels and filters differ from each other, overlays paint and move, export is a decodable JPEG with exact dimensions, original bytes unchanged, cancellation/corrupt/missing inputs leave no rows or files, status images have the right size and keep ink inside the safe area, Hindi conjuncts shape and Latin-only fonts fall back to Devanagari glyphs.
Not proven: touch ergonomics (drag/pinch on a real screen), GPU vs test-engine rendering differences, emoji glyph rendering on a device, time/memory on low-end phones, TalkBack behaviour, iOS.

## Phase 1 (end state, 2026-10-24)

| Check | Command | Result |
|---|---|---|
| Static analysis | `flutter analyze` | **No issues found** (baseline was 16 issues) |
| Automated tests | `flutter test` | **51 passed, 0 failed** (library service 22, library widgets 6, viewer 3, status home 10, onboarding/settings 5, core 5). Baseline had 212 passing tests, almost all for the removed cleaner features and many asserting fakes. |
| Code generation | `dart run build_runner build --delete-conflicting-outputs` | OK (Drift `app_database.g.dart`) |
| Android debug build | `flutter build apk --debug` | **OK** (`app-debug.apk`, Kotlin bridge compiled) |
| Android release build with R8 | `flutter build apk --release --android-project-arg=allowDebugSigning=true` | **OK** after adding `-dontwarn com.google.android.play.core.**` (first attempt failed in `minifyReleaseWithR8`, evidence kept in the session log). Output `app-release.apk` 59.6 MB, **debug-signed — not distributable**. `aapt2 dump badging`: package `com.webappypie.wazapp`, label `WazApp`, minSdk 26, targetSdk 36; permissions: `WRITE_EXTERNAL_STORAGE`/`READ_EXTERNAL_STORAGE` (both maxSdk 28), `ACCESS_NETWORK_STATE`, `WAKE_LOCK` (library-added); no `INTERNET`, no `READ_MEDIA_*`, no `MANAGE_EXTERNAL_STORAGE`. |
| Release signing guard | by construction (`build.gradle.kts`: no `key.properties` and no explicit flag → `signingConfig = null`) | **Not executed** as a negative test |
| Release AAB / upload keystore | – | not run (B5: no keystore) |
| Install on physical device | `adb install -r app-debug.apk` (Xiaomi `2201116SI`, Android 13) | **FAILED: `INSTALL_FAILED_USER_RESTRICTED`** — owner must enable "Install via USB". No on-device result exists. |
| Device/OS matrix | – | **none** (Android 11/12/14, other OEMs, WhatsApp vs Business on device: not tested) |
| SAF bridge end-to-end (grant → list → copy → verify) | – | **not verified on device** (compiled + Dart side tested with a fake bridge) |
| iOS build / run / archive | – | **blocked-by-environment** (no macOS/Xcode); `ios/` scaffold only |
| WAPCentral health / service status / ads / FCM / billing sandbox | – | not implemented (Phase 5; blockers B1, B3, B4) |

## What the automated tests really prove (and do not)
Proven on the host with real Drift + real files and only the platform bridge faked: save/import/delete integrity and rollback, duplicate handling, WhatsApp/Business separation of source keys, partial-failure and cancel semantics, filters/search, favourites, confirmation dialogs, onboarding flow, theme persistence in state, honest unsupported-platform UI.
**Not proven:** native SAF behaviour, MediaStore export, video_player playback, thumbnails produced by the native bridge, iOS pickers, performance (cold start, scrolling, memory), TalkBack/large-text accessibility.

## Previous baseline (Phase 0, WappTidy code) — superseded
`flutter analyze` 16 issues; `flutter test` 212 passed; `flutter build apk --debug` OK (381 s).
