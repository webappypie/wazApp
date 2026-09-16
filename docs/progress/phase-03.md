# Phase 03 — Indexing Engine Detail

**Status:** Done  
**Completed:** 2026-09-17  
**Requirements:** REQ-IDX-01 to REQ-IDX-07, PRD §5.4, PRD §5.5 budgets

---

## What was built

### Database — schema v2

| File | Description |
|---|---|
| [`tables/media_items_table.dart`](../../lib/core/database/tables/media_items_table.dart) | Drift `MediaItems` table: contentUri (unique), mediaStoreId, mimeType, sourceApp, bucketName, displayName, sizeBytes, width, height, durationMs, dateAddedSec, dateModifiedSec, scanVersion, isProtected |
| [`tables/scan_state_table.dart`](../../lib/core/database/tables/scan_state_table.dart) | Drift `ScanStateTable`: singleton row (id=1), status, scanVersion, itemsProcessed/Total, bytesProcessed, lastSeenGeneration, lastModifiedCursor, startedAtMs, errorMessage |
| [`app_database.dart`](../../lib/core/database/app_database.dart) | Schema bumped v1→v2; `upsertMediaItems()` batch upsert; `deleteStaleItems()` prunes rows not touched by current scan; `countAllItems()`, `sumAllBytes()`; `_seedScanState()` in onCreate + onUpgrade |

build_runner regenerated `app_database.g.dart` successfully (schema v2).

### Kotlin platform channel (PRD §5.4)

| File | Description |
|---|---|
| [`MediaIndexer.kt`](../../android/app/src/main/kotlin/com/wapptidy/wapptidy/MediaIndexer.kt) | Queries `MediaStore.Files` (all external volume), filters to WhatsApp buckets, streams batches of 200 items via `EventChannel`, handles pause/cancel via `AtomicBoolean`, records `resumeCursor` for crash-safe resume, skips unreadable rows individually (REQ-IDX-07), supports incremental via `DATE_MODIFIED >= ?` and `GENERATION_MODIFIED > ?` (API 29+) |
| [`MainActivity.kt`](../../android/app/src/main/kotlin/com/wapptidy/wapptidy/MainActivity.kt) | Registers `MethodChannel` (`start/pause/resume/cancel/currentGeneration`) and `EventChannel` (progress stream), calls `dispose()` on `onDestroy` |

**Channel names:**
- `com.wapptidy/media_indexer` — MethodChannel
- `com.wapptidy/media_indexer_events` — EventChannel

**WhatsApp bucket detection (REQ-IDX-01, REQ-IDX-06):**
- Known bucket names: WhatsApp Images/Video/Audio/Documents/Animated Gifs/Stickers/Profile Photos + Business variants + legacy "WhatsApp"
- Source app: `com.whatsapp` vs `com.whatsapp.w4b` resolved from bucket name + relative_path

### Flutter domain + repository layer

| File | Description |
|---|---|
| [`domain/indexing_models.dart`](../../lib/features/indexing/domain/indexing_models.dart) | Pure Dart: `ScanProgress` (status, itemsProcessed, itemsTotal, bytesProcessed, fraction, isTerminal, isActive), `RawMediaItem` (deserialised from channel map) |
| [`domain/indexing_repository.dart`](../../lib/features/indexing/domain/indexing_repository.dart) | Interface: `startFullIndex()`, pause/resume/cancel, currentGeneration, lastSavedGeneration, restoreScanState, indexedItemCount, indexedTotalBytes |
| [`data/real_indexing_repository.dart`](../../lib/features/indexing/data/real_indexing_repository.dart) | Real impl: platform channel → `upsertMediaItems()` batch insert → prune stale rows → save generation |
| [`data/fake_indexing_repository.dart`](../../lib/features/indexing/data/fake_indexing_repository.dart) | In-memory fake: configurable events, tracks pause/resume/cancel, zero platform dependencies |

### Indexing service + providers

| File | Description |
|---|---|
| [`presentation/indexing_service.dart`](../../lib/features/indexing/presentation/indexing_service.dart) | `IndexingService`: orchestrates full vs incremental scan via `diffDecision()` (pure static method); manages broadcast `StreamController`; handles pause/resume/cancel delegation |
| [`presentation/indexing_providers.dart`](../../lib/features/indexing/presentation/indexing_providers.dart) | `indexingRepositoryProvider`, `scanProgressProvider` (StreamProvider.autoDispose), `indexingServiceProvider`, `indexStatsProvider` (FutureProvider) |

### Progress UI

[`clean_screen.dart`](../../lib/features/clean/presentation/clean_screen.dart) — full state machine:
- **Idle**: "Scan media" CTA
- **Running**: real `LinearProgressIndicator` from `itemsProcessed/itemsTotal` (never interpolated — REQ-IDX-05, P-03); Pause + Cancel buttons
- **Paused**: same progress bar, Resume + Cancel
- **Done**: indexed count + bytes from `indexStatsProvider` (real DB query); Re-scan CTA
- **Cancelled**: idle-like with context message
- **Error**: `ErrorState` with retry
- `PartialAccessBanner` always at top (REQ-ONB-05)
- No ad placement on scan screens (REQ-ADS-05)

---

## Incremental-diff logic (REQ-IDX-03) — `IndexingService.diffDecision()`

```
existingItemCount == 0           → ScanDecision.full       (first launch)
currentGeneration == lastGen
  AND lastGen > 0                → ScanDecision.skip       (nothing changed)
otherwise                        → ScanDecision.incremental (sinceModifiedSec = cursor)
```

**Edge cases handled:**
- Pre-API29 device: both generations = 0 → treated as incremental (not skip)
- Zero cursor despite populated index → incremental with sinceModifiedSec=0 (full-range safety net)
- Killed mid-scan: ScanStateTable row preserved, next launch restores state

---

## Tests — 50/50 pass

**New in Phase 3 (`test/features/indexing/indexing_diff_test.dart`)** — 16 tests:

| Test | What it guards |
|---|---|
| Empty index → full scan | First launch always does full scan |
| Empty + matching gens → full | Generations alone can't override empty-index rule |
| Same gen (>0), populated → skip | No-op when nothing changed |
| Both gens zero, populated → incremental | Pre-API29 safety: never skip on unknown generation |
| Gen changed, populated → incremental from cursor | Normal incremental path |
| Gen 0→1 (first API29 scan) → incremental | First time we get a real generation |
| Zero cursor, populated → incremental sinceModifiedSec=0 | Migrated DB safety |
| fraction clamped to 1.0 on over-count | REQ-IDX-05 monotone guarantee |
| fraction = 0.0 when total unknown | UI shows indeterminate bar, not 0% |
| isTerminal for done/cancelled/error | Stream terminates correctly |
| isActive for idle/running/paused | Stream continues correctly |
| Fake emits events in order | FakeIndexingRepository contract |
| Fake stops at terminal | No events after done |
| Fake tracks pause/resume/cancel | Control surface tested |
| Fake indexedItemCount/Bytes | Configure + read |

---

## Performance budget notes (PRD §5.5)

> These are architectural targets. Real measurement must be done on a device with 15,000+ real WhatsApp files before the budget line can be marked green.

| Budget | Mechanism |
|---|---|
| Full index metadata < 45s | Batched MediaStore cursor query; no file reads; 200-item batches |
| Incremental rescan 200 files < 8s | `DATE_MODIFIED >=` or `GENERATION_MODIFIED >` filter reduces cursor size |
| Peak RAM < 350MB | Batch size 200; items upserted and cleared per batch; no full set in memory |

Actual numbers to be recorded here after real-device test.

---

## Carried debt / deferred items
- `lastModifiedCursor` in `IndexingService.startScan()` is hardcoded to 0 (full-range) for Phase 3. Phase 4+ should read `ScanStateTable.lastModifiedCursor` and pass it to `diffDecision()`.
- `mediaPermissionStateProvider` should be upgraded from `FutureProvider` → `StreamProvider` that re-checks on `AppLifecycleState.resumed` (noted from Phase 2).
- Performance numbers (§5.5 budgets) must be recorded from a real device before Phase 8 DoD.
- `WhatsApp Business` path detection in `MediaIndexer.kt` uses a heuristic (keyword "business" in bucket/path). This should be validated on real WA Business devices in Phase 6.
