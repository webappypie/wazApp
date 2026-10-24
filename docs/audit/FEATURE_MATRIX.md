# Feature Matrix

Statuses: working / partial / stubbed-fake / broken / missing / blocked-by-environment / not-applicable.
"Working" here means exercised by automated tests on the host; **nothing is device-verified yet** (see KNOWN_LIMITATIONS E5). The Phase 0 matrix (baseline, WappTidy) is preserved in git history at `3c18c57`.

_Last updated: end of Phase 1 (2026-10-24, branch `feature/wazapp`)._

| Feature | Pri | Status | Evidence / files | Verification | Blocker / next |
|---|---|---|---|---|---|
| Identity (WazApp, `com.webappypie.wazapp` / `.ios`) | P0 | working | `build.gradle.kts`, Kotlin pkg, `pubspec.yaml`, iOS `project.pbxproj` | debug APK builds; iOS not built | none |
| Startup / navigation | P0 | working | `main.dart`, `app_router.dart` (splash → onboarding → 3-tab shell; bad-route guard) | `onboarding_flow_test.dart` | Create/Private tabs added with their phases |
| Onboarding & permissions | P0 | working | `onboarding_screen.dart`; no runtime permission needed (SAF + pickers); no false "granted" claims | `onboarding_flow_test.dart` | notification opt-in comes with Phase 5 |
| Android status discovery (WhatsApp / Business separate) | P0 | partial | `StatusAccessHandler.kt` (SAF tree grant, persisted permission, wrong-folder validation, listing), `home_screen.dart` access setup, rescan on resume, pull-to-refresh | Dart side: `home_screen_test.dart` (fake bridge); native: **compiled only** | **blocked-by-environment**: install on phone refused (E5); no statuses present (E6); Android 11/12/14 not available |
| Save status (single/multi, progress, cancel, retry, partial failure, duplicates) | P0 | partial | `LibraryService.saveStatus(es)`, native verified copy (`.part`+size+decode), `library_actions.dart` | `library_service_test.dart` (21), `home_screen_test.dart` | native copy unverified on device |
| iOS Photos/Files import, library, share | P0 | partial | same Dart import path; iOS scaffold (`ios/`); Home shows import-only honest copy when status access unsupported | `home_screen_test.dart` (unsupported platform), import logic tests | **blocked-by-environment**: no Xcode; iOS video thumbnails not generated |
| Import from Photos/Files (all platforms) | P0 | partial | `importFlow`, `LibraryService.importFiles` (type check, size verify, decode probe, rollback) | `library_service_test.dart` | picker UI unverified on device |
| Local library: grid, filters (All/Photos/Videos/Favourites/Recent), search, favourites, multi-select, bulk favourite/share/export/delete with count confirmation | P0 | working (host) | `saved_screen.dart`, `library_models.dart` | `saved_screen_test.dart`, filter tests | device check |
| Viewer (pinch-zoom photos, video controls only for video, favourite/share/export/delete/details, missing-file recovery) | P0 | partial | `viewer_screen.dart`, `status_preview_screen.dart` | `viewer_screen_test.dart` (photo viewer, favourite, details, missing file); video playback unexercised | video playback + device check |
| Metadata integrity (missing files, interrupted writes) | P0 | working (host) | `reconcile()`, `.part` cleanup at startup, delete ordering | `library_service_test.dart` | call `reconcile()` periodically (not yet scheduled) |
| Photo editor / export | P1 | missing | no code, no UI entry | – | Phase 2 |
| Hindi/English status maker | P1 | missing | – | – | Phase 2 |
| Video editor / export | P1 | missing | – | – | Phase 3 |
| Private Folder | P1 | missing (schema column `isPrivate` reserved, excluded from library queries) | `saved_media_table.dart`, test "excludes private items" | – | Phase 4 |
| Storage Manager | P1 | partial | Settings shows WazApp library count/size (`usedBytes`) | manual calc only | duplicates/large files/bulk delete → Phase 4 |
| WAPCentral service control / ads / notifications / promotions | P1 | missing | no integration code (SDKs unavailable, B1) | – | Phase 5, blocked by B1/B4 |
| Remove Ads purchase / restore / entitlement | P1 | missing (fake grant removed) | – | – | Phase 5, blocked by B3 |
| Cloud backup | out of scope | removed | – | – | – |
| Accessibility | P1 | partial | semantic labels on tiles/controls, ≥48 dp targets via tokens; not audited with TalkBack/large text | – | Phase 6 |
| Theme (system/light/dark, persisted) | P1 | working (host) | `ThemeModeNotifier` | `onboarding_flow_test.dart` | – |
| Offline core flows / privacy | P0 | working | no network code exists; INTERNET permission not declared | code review | re-verify after Phase 5 |
| Release build / signing | P0 | partial | no silent debug signing; R8 rules updated | see RELEASE_EVIDENCE | keystore (B5) |
| Automated tests | P0 | working | 51 tests (library service 22, saved screen 6, viewer 3, status home 10, onboarding/settings 5, core 5) | `flutter test` all pass | add viewer/native tests |
