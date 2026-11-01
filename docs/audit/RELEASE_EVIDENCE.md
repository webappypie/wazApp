# Release Evidence

Only commands that were actually run are listed. Host: Windows 11, Flutter 3.47.1 / Dart 3.13.1, Android SDK 36.1.0. Branch `feature/wazapp`.

## Phase 5 (end state, 2026-10-25)

| Check | Command | Result |
|---|---|---|
| Static analysis | `flutter analyze` | **No issues found** |
| Automated tests (host) | `flutter test` | **248 passed, 0 failed, 1 skipped** (+25 vs Phase 4: client 14, gate 11; the skipped test is the opt-in live check) |
| Live endpoint | opt-in `live_service_status_test` (read-only GET, no key) | HTTP 200; parsed as `source: server, enabled: true` |
| Release / R8 build | `flutter build apk --release --android-project-arg=allowDebugSigning=true` | **OK, 65.1 MB**; INTERNET and USE_BIOMETRIC present in the merged manifest; output is debug-signed (not distributable) |
| Network path on a device / emulator | - | **not run** |
| Physical phone | - | not retried (E5 open) |

Proven by tests: contract parsing and documented defaults, fail-open matrix (timeout, offline, 3xx/4xx/5xx, bad JSON, missing data), key redaction in logs and `toString`, URL scheme safety, non-blocking cold start, inert UI and consumed Android back while blocked, resume re-check, automatic dismissal on restoration, onboarding covered by the notice.
Not proven: behaviour on a real network stack/TLS on a phone, OEM back-gesture handling, `url_launcher` opening a real browser, iOS.

## Phase 4 (end state, 2026-10-25)

| Check | Command | Result |
|---|---|---|
| Static analysis | `flutter analyze` | **No issues found** |
| Automated tests (host) | `flutter test` | **223 passed, 0 failed** (+47 vs Phase 3: private service 9, private UI 13, storage service 17, storage screen 6, migration 2) |
| Schema migration | `database_migration_test` | v1 to v2 keeps rows, adds hash columns |
| Device authentication on an emulator (Android 16, PIN set) | `flutter test integration_test/device_auth_test.dart -d emulator-5554` | **3/3 passed**: available with a screen lock; the real system prompt opened and the PIN returned success; dismissing returned a non-success outcome |
| Device authentication without any screen lock | `flutter test integration_test/device_auth_nolock_test.dart -d emulator-5554` (after `locksettings clear`) | **2/2 passed**: reported not available; `authenticate` returned `notAvailable`, never success |
| Android build with local_auth, AppCompat, FragmentActivity | built by the runs above (`assembleDebug`) | OK |
| Physical phone | - | not retried (E5 open) |
| Release/R8 build | - | **not run** since Phase 1 (media3 and local_auth were added later) |

Not proven: fingerprint/face prompts, OEM biometric UIs, iOS, behaviour of the Private Folder under a screen recorder, time to hash a large library on a phone, root/forensic access to private files (they are not encrypted).

## Phase 3 (end state, 2026-10-25)

| Check | Command | Result |
|---|---|---|
| Static analysis | `flutter analyze` | **No issues found** |
| Automated tests (host) | `flutter test` | **176 passed, 0 failed** (+31 for video: edit-state/plan/validation 16, export service with fake encoder 7, editor screen with fake player 8 - counted in the 176 total) |
| Kotlin / Media3 compile | Gradle `compileDebugKotlin` | OK (media3-transformer/effect/common 1.9.2) |
| Android debug build | `flutter test integration_test/...` builds `assembleDebug` | OK |
| **Real encoder on an emulator** | `flutter test integration_test/video_export_test.dart -d emulator-5554` (AVD `wazapp_test`, Android 16 / API 36, x86_64 Google APIs image, software GPU; two host-generated 1280×720 15 fps H.264+AAC clips, 8 s and 40 s, copied into the app's private directory) | **10/10 passed** |
| Install on the physical phone | `adb install` | not retried in this phase; last result `INSTALL_FAILED_USER_RESTRICTED` (owner action E5 still open) |
| Release/R8 build with media3 | – | **not run** in Phase 3 |

What the 10 emulator tests prove (production classes, real MediaCodec encoder, real `video_player`):
1. Native probe reads size/duration/has-audio of the source.
2. **Trim** 1.0-4.0 s → ~3 s H.264 file, full size, audio kept.
3. **Mute** → output has no audio track, video intact.
4. **Crop** (right half) → 640×720 output whose pixels match the *right half* of the source frame (compared against both halves; not mirrored/shifted).
5. **Size cap** 640×360 → decodes and plays in the real `VideoPlayerController` with the right size/duration.
6. **Overlay** PNG → red block burned in at the right pixels while the rest of the frame is the original picture.
7. **Progress** callbacks are within 0..1 and non-decreasing (87-138 samples per export).
8. **Cancel** of a 40 s export → `OperationCancelled`, no output file left (the same test originally failed because of a race in the *test* - the error surfaced before the handler was attached - not in the product; it was fixed in the test).
9. Missing input → `sourceUnavailable`.
10. **End to end** `VideoExportService` with real library, DB and probe: trim + mute + crop + Hindi text overlay → new edited video 640×720, ~4 s, no audio, thumbnail created, original untouched, no temp leftovers, two library rows.

Not proven: behaviour on a physical phone's hardware encoder, 4K/HEVC/10-bit/HDR input, long videos, low storage, thermal/battery, exact export times (the emulator's software encoder ran ~5-8× slower than real time; a 3 s clip took ~20 s), touch handling of trim/crop handles on a real screen, iOS (no encoder implemented).

Environment notes from this phase: the host has 8 GB RAM; with the emulator running and the original `-Xmx8G` Gradle daemon, one build took 43 minutes and corrupted Gradle script caches (random `NoClassDefFoundError`). `android/gradle.properties` heap was lowered to `-Xmx3G`/2G metaspace and the Gradle script caches were deleted and regenerated; builds then took 4-17 minutes.

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

## Phase 6 - physical-device run (debug build only; no release build made)

Device: Redmi Note 11 Pro (2201116SI, MIUI V816), Android 13 / API 33, 1080x2400. WhatsApp Business installed with 4 real statuses (3 JPG, 1 MP4); regular WhatsApp NOT installed. Build: `flutter build apk --debug --target-platform android-arm64`, installed with `adb install` (MIUI shows an "Install via USB?" prompt that must be accepted within seconds).

| Check | Result (observed) |
|---|---|
| First launch -> intro -> /setup | works; setup lists WhatsApp "Not installed", WhatsApp Business "Not set up", Notifications "Not asked yet", Private Folder lock "Off", Photos & files "No permission needed" (real states) |
| Business folder picker | opens directly on `.Statuses`; "Use this folder" + "Allow" -> card shows "Allowed", snackbar "WhatsApp Business connected" |
| Home | both sources shown; Business ring has 4 segments, "4 statuses"; WhatsApp tile "Not installed" |
| Save a status | saved file in app storage has the same MD5 as the original in `.Statuses` |
| App restart (force-stop) | grant and "already saved" marker persist |
| Notification prompt | real system dialog on tap only; Don't allow -> "Denied" + "Try again"; second refusal -> "Blocked" + "Open settings"; no further prompting; "Open settings" opens the app's system notification settings and Back returns |
| Remove access (Settings) | Business returns to "Not set up"; Home tile shows "Tap to set up" |
| No crashes | logcat: only the pre-existing "Zone mismatch" warning (now fixed in source, not re-run on device) |

NOT verified on a device: regular WhatsApp source (not installed), Android versions other than 13, granting notifications through system settings and resume refresh, Private Folder lock enable with the real prompt, video save/editor/Private/Storage flows after this change, ads/notifications/promotions (no `WAP_APP_KEY` supplied, so these surfaces are intentionally off), splash animation by eye (debug cold start 3-6 s hid it), offline behaviour, iOS (no Mac).

## Phase 6 - physical-device run (debug build only; no release build made)

Device: Redmi Note 11 Pro (2201116SI, MIUI V816), Android 13 / API 33, 1080x2400. WhatsApp Business installed with 4 real statuses (3 JPG, 1 MP4); regular WhatsApp NOT installed. Build: `flutter build apk --debug --target-platform android-arm64`, installed with `adb install` (MIUI shows an "Install via USB?" prompt that must be accepted within seconds).

| Check | Result (observed) |
|---|---|
| First launch -> intro -> /setup | works; setup lists WhatsApp "Not installed", WhatsApp Business "Not set up", Notifications "Not asked yet", Private Folder lock "Off", Photos & files "No permission needed" (real states) |
| Business folder picker | opens directly on `.Statuses`; "Use this folder" + "Allow" -> card shows "Allowed", snackbar "WhatsApp Business connected" |
| Home | both sources shown; Business ring has 4 segments, "4 statuses"; WhatsApp tile "Not installed" |
| Save a status | saved file in app storage has the same MD5 as the original in `.Statuses` |
| App restart (force-stop) | grant and "already saved" marker persist |
| Notification prompt | real system dialog on tap only; Don't allow -> "Denied" + "Try again"; second refusal -> "Blocked" + "Open settings"; no further prompting; "Open settings" opens the app's system notification settings and Back returns |
| Remove access (Settings) | Business returns to "Not set up"; Home tile shows "Tap to set up" |
| Crashes | none seen; logcat showed only a "Zone mismatch" warning (fixed in source afterwards, not re-run on device) |

NOT verified on a device: regular WhatsApp source (not installed), Android versions other than 13, granting notifications through system settings and the resume refresh, Private Folder lock enable with the real prompt, video save/editor/Private/Storage flows after this change, ads/notifications/promotions (no `WAP_APP_KEY` supplied, so these surfaces are intentionally off), the splash animation by eye (debug cold start hid it), offline behaviour, iOS (no Mac).

## Phase 7 - detection, contact metadata and missing statuses (physical device, debug build)

Device as in Phase 6 (Android 13): WhatsApp Business installed, WhatsApp Messenger not installed.

### Installed-app detection
- `getPackageInfo` for `com.whatsapp` / `com.whatsapp.w4b` with only those two `<queries>` entries: Business detected, Messenger not detected (matches `pm list packages`). Home shows exactly one card (Business) - scenario B observed on the device. Scenarios A, C and D are covered by host tests (`home_sources_test`) only.
- Removing the folder grant in Settings turned the card into "Not set up / Allow access" while the app stayed detected; "Allow access" on the card ran the real picker and restored "4 statuses available" (installed vs accessible are separate states, observed).

### Can statuses be grouped by contact? No
Inspected the real status folder over adb (`Android/media/com.whatsapp.w4b/WhatsApp Business/Media/.Statuses`):
- 4 files, names are 32-hex content hashes (e.g. `6f2f...d165.jpg`), plus an empty `.nomedia`; no sidecar/metadata files.
- JPEG: plain JFIF, no EXIF/GPS/comment; MP4: only `ftyp mp42/isom` boxes; no contact id or phone number strings found.
- All four files share the same modification time (download time), so time cannot separate senders either.
- The only place WhatsApp stores which contact posted what is its private database; the app's `Android/media/.../Databases` folder holds only encrypted `msgstore-*.crypt14` backups. Reading or decrypting them is unsupported and out of scope (no private-database scraping).
Conclusion: contact names, avatars and status-to-contact mapping are not available through supported mechanisms. WazApp groups by day (file time) and says so; no contact identity is invented.

### Why a status visible in WhatsApp may not be listed
Verified: the folder contains only media files WhatsApp has written; WazApp lists exactly those 4 and there is no other source that reveals a status that has no file. NOT verified by test: that opening a status in WhatsApp is what causes the file to appear (that would need viewing other people's statuses in the user's WhatsApp, which was not done; WazApp never does this either). The in-app help therefore says statuses "may appear only after WhatsApp has downloaded them", states it is not guaranteed, offers "Check again" and "Open WhatsApp[ Business]" (launcher intent only), and keeps folder-permission problems in a separate message. Device/OS differences not tested: Android 10 and older use `WhatsApp[ Business]/Media/.Statuses` (hint path only, untested).

### On-device UI results (Phase 7 build)
Home hero card with real thumbnails, source screen with day heading "Today", filter chips "All 4 / Photos 3 / Videos 1", "Saved" marker, collapsed-by-default "Missing a status?" help, app-bar "Open WhatsApp Business" launching the Business app (focus confirmed with `dumpsys window`) and returning to WazApp. Not verified: dark/light by eye in light mode, TalkBack, splash by eye.
