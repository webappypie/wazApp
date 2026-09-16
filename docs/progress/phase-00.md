# Phase 00 — Foundation Detail

**Status:** In progress  
**Started:** 2026-09-17  
**Engineer:** Antigravity

---

## What was built

### Flutter project
- Package: `com.wapptidy.app`
- App name: WappTidy
- `minSdk` = 26, `targetSdk` = 36 (PRD §5.1)
- Platforms: Android only

### Dependencies resolved
| Package | Version | Purpose |
|---|---|---|
| flutter_riverpod | 3.4.3 | State management |
| riverpod_annotation | 4.0.7 | Code-gen annotations |
| go_router | 14.8.1 | Navigation |
| drift | 2.35.0 | SQLite ORM |
| sqlite3_flutter_libs | 0.5.42 | Native SQLite |
| logging | 1.3.0 | Structured logger |
| firebase_core | 3.15.2 | Firebase (fail-safe) |
| firebase_remote_config | 5.5.0 | Remote config |
| equatable | 2.1.0 | Value equality |
| mocktail | 1.0.5 | Test mocking |

### Core files created
```
lib/
  main.dart                           ← entry point, error boundary, logger init
  app.dart                            ← WappTidyApp root widget
  core/
    logging/app_logger.dart           ← structured logger (only file allowed to use print())
    error/app_error.dart              ← sealed typed error hierarchy
    error/error_handler.dart          ← global error boundary + friendly error widget
    database/app_database.dart        ← Drift DB, empty schema, WAL+FK enabled
    di/providers.dart                 ← Riverpod providers for all services
    router/app_router.dart            ← go_router with 5-tab StatefulShellRoute
    services/
      analytics/{interface,fake}      ← REQ (PRD §10 event list enforced)
      remote_config/{interface,fake}  ← REQ-ADS-09 keys declared
      purchases/{interface,fake}      ← PremiumEntitlement stream
      ads/{interface,fake}            ← REQ-ADS-01/08 enforced at interface level
      media_access/{interface,fake,media_item} ← MediaStore abstraction + domain model
      background_task/{interface,fake} ← P-02 detect-only documented at interface
  features/
    home/presentation/home_screen.dart      ← placeholder
    clean/presentation/clean_screen.dart    ← placeholder
    organize/presentation/organize_screen.dart ← placeholder
    bin/presentation/bin_screen.dart        ← placeholder
    settings/presentation/settings_screen.dart ← placeholder
test/
  widget_test.dart                    ← smoke test: app boots, 5 nav destinations present
  core/services/fake_services_test.dart ← 20 tests covering all 6 fake implementations
```

### Key decisions encoded in Phase 0 code
- No `MANAGE_EXTERNAL_STORAGE` — will not be added (DEV_PROMPT rule 7, PRD §5.2)
- `avoid_print: true` lint enabled — only `app_logger.dart` suppresses it file-level
- All service providers return Fake implementations — real impls swapped in later phases without touching callers
- `isPremiumProvider` uses Riverpod 3's `.value` (not deprecated `.valueOrNull`)
- Ad policy keys in `RemoteConfigService` interface — REQ-ADS-09 enforced at design time
- `FakeAdsService.blocking = true` mode exists specifically for Phase 7 REQ-BIN-03 testing

### Deferred to later phases
- Real MediaStore Kotlin platform channel → Phase 3
- Real AdMob SDK → Phase 8
- Real Play Billing → Phase 8
- Real Firebase Remote Config → Phase 8
- WorkManager background tasks → Phase 8
- All feature screens → Phase 1–8

### Drift schema
Version 1: empty (no tables). WAL journal mode and foreign keys enabled.  
Next version bump: Phase 3 (adds `media_items` table per REQ-IDX-02).

## Issues / notes
- build_runner first-run AOT compilation is slow (~2–3 min) — subsequent runs use cache.
- `firebase_remote_config` web package pulled in but unused on Android; excluded from analysis_options.yaml.
- `riverpod_annotation` upgraded from 2.x → 4.x (matched flutter_riverpod 3.x). This was a breaking change resolved during Phase 0.

## Next action (Phase 1)
Run `flutter analyze` (must be zero warnings), run all tests, then begin Phase 1 — Design system.
