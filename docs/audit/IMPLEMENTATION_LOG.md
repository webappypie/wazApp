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
