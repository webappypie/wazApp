# Implementation Log

## 2026-10-24 — Phase 0: audit only
- Read README, AI_AGENT_HANDOFF, all `docs/*.md` pack files, all `prompts/*.md`, the full WAPCentral guide.
- Located Firebase config (repo root): `google-services.json` (project `wazapp-512609`, package `com.webappypie.wazapp`), `GoogleService-Info.plist` (bundle `com.webappypie.wazapp.ios`). Values intentionally not copied into reports.
- Ran baseline analyzer/tests/debug build on the pre-existing WappTidy code (see `BASELINE_AUDIT.md`). Finding: the repo is a media cleaner, not WazApp. Owner decided: rename in place (ADR-001).

## 2026-10-24 — Phase 1: conversion + P0 core saver and library (Android implemented; iOS scaffolded)

### Git
- `checkpoint/wapptidy-pre-wazapp` (`3c18c57`): all pre-existing uncommitted WappTidy work + the documentation pack. The WAPCentral guide was **not** committed (contains the unmasked `X-App-Key`) and is now git-ignored.
- `feature/wazapp`: all changes below.

### Removed (cleaner-only / fake)
Whole feature modules `analytics`, `backup` (fake Google Drive), `bin`, `clean`, `dev`, `home`, `indexing`, `organize`, `search`, `settings` (old); services `ads`, `analytics`, `audio`, `background_task`, `backup`, `installed_apps`, `media_access`, `notifications`, `purchases` (fake Premium grant), `remote_config`; native Kotlin: BackgroundScanWorker, BlurDetectorEngine, DuplicateDetector, MediaActionHandler, MediaIndexer, NotificationHelper, PerceptualHashEngine, VideoCompressorEngine; the 28 old test files; unused deps (`firebase_core`, `firebase_remote_config`, `permission_handler`, `riverpod_annotation`, `riverpod_generator`, WorkManager). Legacy docs moved to `docs/legacy-wapptidy/`. Audit findings A-01, A-03, A-04 (fakes), A-05 (unused Firebase deps), A-12 (permissions: only `WRITE_EXTERNAL_STORAGE` maxSdk 28 remains), A-13/A-14 (swallowed errors, fake-asserting tests) resolved by removal.

### Identity / config
- Android `applicationId`/`namespace` `com.webappypie.wazapp`, Kotlin package `com.webappypie.wazapp`, channel `com.webappypie.wazapp/status_access`, label `WazApp`, Dart package `wazapp`; iOS scaffold created (`flutter create --platforms=ios`), bundle id `com.webappypie.wazapp.ios`.
- `google-services.json` → `android/app/`, `GoogleService-Info.plist` → `ios/Runner/` per guide §3. **Not wired into any build yet** (Firebase/FCM is Phase 5; the google-services Gradle plugin is intentionally not applied until `firebase_messaging` is added).
- Release signing no longer falls back silently to the debug key (A-06): requires `android/key.properties` or explicit `-PallowDebugSigning=true`.
- Brand tokens: deep teal `#075E54`, green `#128C7E`, accent `#25D366`; original mark (gradient tile + download arrow), no third-party assets.

### New code
- Native: `StatusAccessHandler.kt` (SAF folder grant + persisted permission, WhatsApp/Business separate validation, listing, thumbnails, verified copy with `.part` + size check + decode, gallery export via MediaStore on API 29+). ADR-002.
- Dart: `features/status` (access service, providers, Home, status preview), `features/library` (Drift `saved_media`, `LibraryService`, storage layout, probe, Saved grid with filters/search/multi-select, full-screen viewer with video controls, import from Photos/Files, share, gallery export, confirmed delete), `features/settings`, `features/onboarding` (no permission prompts; honest copy), 3-tab router. ADR-003.
- Riverpod 3 silent provider retry disabled (`ProviderScope(retry: …)`), so failures surface immediately.

### Bugs found by the new tests and fixed
1. Quick-save/selection overlays were unreachable: tile `InkWell` sat above the action button (hit-test) → restructured `MediaTile`.
2. `LibraryService.delete` could remove the thumbnail/file and keep the row (or the reverse) → media file is now the source of truth; thumbnails best-effort; `reconcile()` sweeps orphan thumbnails.
3. `formatBytes` showed "2 KB" for 1.5 KB.

### Not done in Phase 1 (honest list)
- iOS: scaffold only. Import code is the same Dart path (image_picker/file_picker), **unverified on iOS** (no Xcode); iOS video thumbnails are not generated (placeholder icon); no iOS gallery export (Share is the path).
- Android on-device validation of the SAF bridge: **blocked** — USB install was refused by the phone (`INSTALL_FAILED_USER_RESTRICTED`, "Install via USB" must be enabled by the owner). See `KNOWN_LIMITATIONS.md`.
- Photo/video editor, status maker, Private Folder, Storage Manager, WAPCentral, ads, billing: Phases 2–5 (not started; no UI entry points exist for them yet, so no placeholder controls ship).

## 2026-10-24 — Phase 2: photo editor + Hindi/English status maker

### Delivered (host-verified; not yet seen on a device)
- `features/editor`: immutable `EditState` + `EditHistory` (undo/redo/reset), one renderer for preview and export (`paintEdit`), pure `crop_math`, `PhotoExportService` (bounded decode → render → JPEG in isolate → verify → library), editor UI (Adjust, Crop/rotate/flip with aspect presets and draggable frame, Filters with live thumbnails, Text, Stickers), discard guard, staged progress + cancel, error dialog with retry. Entry points: **Create** tab and viewer ▸ *Edit photo*. ADR-004.
- `features/status_maker`: 26 procedural templates, EN/HI samples, text auto-fit (max 300 chars), 1080×1920 PNG export, Save / Save & share.
- `LibraryService.addCreatedFile` (verified insert of app-generated output with exact-size check and rollback).
- Bundled fonts (Hind, Tiro Devanagari Hindi, Kalam, Rozha One, Poppins, Pacifico; OFL; licences registered in the app's licence page).
- New dependency: `image` (JPEG encoder). Navigation now Home / Saved / Create / Settings.

### Bugs found by the new tests and fixed
1. Free crop drag threw `ArgumentError` (inverted clamp range) when a handle was dragged past the opposite edge.
2. Sweep-gradient templates (Neon, Aurora) crashed: `Gradient.sweep` needs explicit stops for >2 colours.
3. Text-entry dialog disposed its controller while the closing animation still used it (framework assertion) → dialog now owns its controller.
4. Sticker text had no explicit colour (invisible in the test engine / on glyph fallback) → explicit colour.
5. Over-long status text could not fit → input capped at 300 chars and layout guaranteed to fit that.

### Not offered on purpose
Sharpness control (cannot be done honestly with Canvas only), free-angle straighten, JPEG quality picker.

### Known gaps
No on-device run (install blocked, see KNOWN_LIMITATIONS E5); status maker has no 1:1 export size (9:16 only); overlays do not rotate with the photo when the photo is rotated (they stay in the frame); crop frame resets when rotating/flipping.

## 2026-10-24 — Phase 3: video editor (Android)

### Delivered
- `android/.../VideoExportHandler.kt`: Media3 Transformer 1.9.2 export (H.264/AAC MP4): trim, mute, crop, one full-frame transparent overlay bitmap, even-sized output, bitrate by resolution; progress polling, cancel (+ partial-output deletion), single-flight guard, free-space pre-check, `unsupported` mapping for codec failures. `StatusAccessHandler.describeFile` now reports `hasAudio`.
- `features/video_editor`: `VideoEditState` + pure planning/validation (`clampTrim`, `outputSize`, `planVideoExport`, `checkExportedVideo`), `VideoEncoder` bridge (+ `UnsupportedVideoEncoder` on iOS), `VideoExportService` (plan → overlay PNG → encode → verify → library), `VideoEditorScreen` (play/pause loop within trim, range-slider trim with 0.5 s minimum, crop frame with aspect presets, text/sticker overlays reusing the photo editor's panels, mute, size caps, undo/redo/reset, discard guard, progress with real percentage, cancel, retry dialog).
- `EditorCanvas` generalised (optional `baseBuilder`) so photos and videos share one gesture/overlay/crop implementation; `paintOverlays` extracted.
- Create tab and viewer menu offer video editing only when `VideoEncoder.isSupported`.
- `LibraryService.addCreatedFile` reused for video (exact-size check + `video_player` decode).
- Environment fix: `android/gradle.properties` heap lowered from `-Xmx8G` to `-Xmx3G` (this machine has 8 GB RAM; with the emulator running, the 8 GB daemon thrashed and one build took 43 min).

### Bugs found by the new tests and fixed
1. Editor tool panels were wrapped in a coloured `Container`, which hid ink/ripples of chips and list tiles (framework assertion) → `Material` surface (photo and video editors).
2. `clampTrim` semantics were pinned down by exhaustive tests (pushes the handle that did not move).

### Verification
See `RELEASE_EVIDENCE.md` (Phase 3 section) for exactly what ran on the emulator and what did not.

## 2026-10-25 - Phase 4: Private Folder + Storage Manager

### Delivered
- **DB schema v2** (`content_hash`, `visual_hash`) with `onUpgrade` (`addColumn`), migration test from a literal v1 schema.
- **Private Folder:** separate `private/` + `private_thumbs/` directories; `LibraryService.moveToPrivate/restoreFromPrivate` (rename files, single row update, rollback on failure); queries `watchPrivate/watchAll`; Private tab (5th tab), lock/unlock session, re-lock on `paused/hidden`, always-visible honest banner, move-back/share/save-a-copy/delete; Saved and viewer menus "Move to Private Folder"; viewer refuses private items while locked; edit hidden for private items.
- **Device authentication:** `DeviceAuthService` over `local_auth` 3.x; `MainActivity` is now `FlutterFragmentActivity`, `USE_BIOMETRIC`, AppCompat launch themes, iOS `NSFaceIDUsageDescription`. Settings switch: enabling requires passing the prompt, disabling requires authentication, a phone without a screen lock cannot enable it.
- **Storage Manager** (Settings > Storage Manager): `StorageService.report()` measured from disk and reconciled with the directories; large files; duplicate scan (size, then SHA-256 in an isolate; photos get a 9x8 dHash; hashes cached); clean-ups (unreferenced files, temp files, broken entries); `StorageScreen` with explanation text and count/size confirmations. ADR-006.
- `LibraryStorage` private dirs, `usedBytes`, partial-file cleanup; `reconcile()` sweeps orphan thumbnails of both directories.

### Bugs/risks found by the new tests
1. A first draft let a file appear in both an identical group and a look-alike group (double-counted reclaimable space): look-alike groups now use only the oldest of each identical group, so suggested deletions are disjoint (tested).
2. `deleteUnreferenced` counted an already-missing file as deleted ("freed 0 B"): now skipped.
3. A UI test pressed a stale tile (action buttons re-render after the report refresh): the test now waits for the refresh; product behaviour unchanged.
4. Windows hosts hold image handles after decoding, so renaming/deleting displayed images fails in widget tests: those tests use video rows (no image file is opened). The product code uses rename/unlink, which is correct on Android.

### Environment
Emulator `wazapp_test` (Android 16) was used for the authentication checks. A PIN was set with `adb shell locksettings set-pin` and typed by a host helper via `input keyevent`; PIN screens are secure windows (screenshots are black), so those steps were verified by test outcomes, not by eye. One run failed because Android killed the app start (`failed to attach` while Gradle was busy); a retry with the cached build passed.

## Phase 5 - WAPCentral service control (partial by owner instruction)

### Delivered
- `lib/integrations/wapcentral/`: `WapCentralConfig` (public base URL and app ID, optional key via `--dart-define=WAP_APP_KEY`, redacted `toString`), `ServiceControlClient` (REST GET per guide section 9, never throws, fails open with a reason-only log line), `ServiceGate` (full-app notice in `MaterialApp.builder`, post-first-frame check, resume re-check, overlapping checks collapse), `UrlOpener` abstraction.
- `WazApp.didPopRoute` consumes Android back while blocked; `INTERNET` permission and `https` VIEW query added; Settings > Privacy > "Service check" discloses what is sent.
- ADR-007 and `WAPCENTRAL_INTEGRATION_STATUS.md` (implemented items, deviations from the guide's snippet, every blocker with the exact owner action).

### Deliberately not done (nothing guessed)
SDK integration (B1), ads config/tracking, notification registration/feed, promotions, Firebase/FCM, AdMob, Remove Ads billing: the supplied material has no SDK source, no schemas for those endpoints and no billing product ID.

### Bugs found by the tests
1. `Uri.parse('https://')` has an empty host and passed the scheme check: destinations now need a non-empty host.
2. A `PopScope` in the gate had no effect (the gate is above the Navigator; back at the root returned false): back is now consumed in `WazApp.didPopRoute`.
3. A blank `destinationUrl` falls back to the guide's default link (test expectation corrected, product behaviour as the guide states).
4. The Settings list got longer, so the onboarding privacy-text test now scrolls to each text instead of one fixed drag.

## Phase 6 - dual WhatsApp sources, permission setup, splash, WAPCentral SDKs (2026-10-25)

### Delivered
- **Sources:** native `accessState` (`not_configured / granted / revoked / folder_missing`), SDK-aware picker hint (Android 11+ `Android/media/<pkg>/...`, older `WhatsApp[ Business]/Media`), Home shows both sources always (circular status ring per source: one segment per real status, warning ring when access is missing, "Not installed" tile), access re-checked before every save (`saveStatusesFlow`).
- **Permissions & Access** (`features/permissions/`): `PermissionGateway` (permission_handler + native settings deep links), `AccessOverviewController` (real state per item, refreshed on app resume), shared `AccessCard`, guided `/setup` screen after the intro (Continue / Skip / Try again / Open settings / Check again), Settings > Permissions & Access section. No fake toggles: Photos & files honestly reports "No permission needed" (system pickers + MediaStore). Notifications are prompted only on a tap; after a second refusal the action becomes "Open settings".
- **Splash:** original launcher icon (adaptive vector, replaces the Flutter default), native teal launch theme + Android 12 splash attributes, animated in-app splash (three-segment ring draw, word-by-word tagline, tap to skip, reduced-motion aware, ~1.3 s, routing as soon as the local flag is read).
- **WAPCentral SDKs** (see `WAPCENTRAL_INTEGRATION_STATUS.md`): the four SDKs were found as sibling path packages; ads (AdMob direct, test units in non-release builds), notifications (FCM registration only after permission, inbox, preferences), promotions wired in. Feature surfaces are hidden without `--dart-define WAP_APP_KEY`.
- `main()` now runs inside the error-boundary zone (removed a "Zone mismatch" warning seen in logcat).

### Bugs found by tests / device
1. Splash tagline intervals exceeded 1.0 (assertion) and the tagline row overflowed at 2x text: fixed (`Wrap`, intervals).
2. `flutter build apk --debug` once failed in `:firebase_core:bundleLibCompileToJarDebug` ("already contains entry"); deleting `build/firebase_core` and rebuilding succeeded (stale intermediates, not reproduced).
3. Onboarding tests updated: the intro now leads to /setup, which completes onboarding.

## Phase 7 - Clenzy-informed redesign, source auto-detection, day grouping, missing-status help (2026-10-25)

### Clenzy reference (inspected locally at `D:\Mobile-App\Clenzy`)
Adopted patterns: a `ThemeExtension` for semantic tokens (hero gradient, card shadow, on-hero colours, one bright "signature" colour) instead of ad-hoc colours; a bundled two-font system (Sora for headlines/numbers, Plus Jakarta Sans for body, both OFL, copied with their licences); `AppCard` (hairline border, soft shadow, press-scale), `SectionTitle`, `AccentIcon`, `StatusPill`; a motion scale that honours "remove animations"; short staggered entrances; a hero-gradient summary card as the home anchor. NOT copied: Clenzy's lime/paper palette (WazApp keeps teal/green), its donut chart, category accents or any code.

### Redesigned
`WazTheme` + `AppMotion` (`core/design/waz_theme.dart`), `design_components.dart`, typography (Sora/Jakarta + Hind fallback for Devanagari), cards/app bar/navigation bar themes, **Home** (hero source cards with status ring, real thumbnail strip, per-state action, create/import tiles), new **Source screen** (day-grouped grid, filter chips with real counts, multi-select save, pull to refresh, Missing-a-status help), Permissions cards. Loading/empty/permission/error states reuse the same components.

### Detection
`availableSourcesProvider` lists only installed apps (package visibility via `<queries>` for `com.whatsapp` and `com.whatsapp.w4b`, resolved by `PackageManager.getPackageInfo`). Home shows one card per installed app (A: WhatsApp only, B: Business only, C: both, D: neither -> explanation, no placeholders). Installed and accessible are separate states. Detection and folder state are re-read on resume, on pull-to-refresh and on "Check again".

### Contact grouping: NOT supported (see RELEASE_EVIDENCE Phase 7 for the evidence)
Statuses are grouped by day instead (`status_grouping.dart`); no contact name, avatar or per-contact screen is shown, because none can be obtained legitimately.

### Tests added
`status_grouping_test` (3), `home_sources_test` (9: scenarios A-D, installed vs access, revoked recovery, re-detect on refresh and on resume, iOS), `source_screen_test` (12: grouping, filters, missing-status help, Open WhatsApp, access vs availability, separate sources, errors, save, access re-check before save, multi-select). The old Home grid tests moved to the source screen.

## Phase 8 - full-screen ad placements (2026-10-25)
Real AdMob interstitial, app-open and rewarded support in the provider, a placement coordinator with explicit frequency rules (`full_screen_ads.dart`), hooks in `saveStatusesFlow` (interstitial), the `WazApp` lifecycle (app open) and Settings (optional rewarded "Support WazApp"). A pending-timer failure in the service-gate tests led to checking "ads on" before scheduling the app-open delay. See WAPCENTRAL_INTEGRATION_STATUS.md for the rules and the device evidence.
