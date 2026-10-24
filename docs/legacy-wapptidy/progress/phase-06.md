# Phase 06 — v1 Categories Detail

**Status:** Done  
**Completed:** 2026-09-17  
**Requirements:** REQ-DUP-01, REQ-DUP-02, REQ-DUP-03, REQ-DUP-04, REQ-VID-01, REQ-SCR-01, REQ-OLD-01  
**Goal:** Implement the 4 v1 cleaning categories by configuring the Phase 5 `CategoryScreen` framework without forking it.

---

## What was built

### 1. Exact Duplicates (REQ-DUP-01 .. 04)
- **Native Android Engine (`android/app/src/main/kotlin/com/wapptidy/wapptidy/DuplicateDetector.kt`):**
  - High-performance Kotlin 2-stage hash algorithm per PRD §5.4:
    - **Stage 1:** Bucket candidates by exact byte size. Discard unique sizes without disk I/O.
    - **Stage 2:** Partial 64 KB hash (first 32 KB + last 32 KB) using SHA-256 to eliminate collisions cheaply.
    - **Stage 3:** Full SHA-256 hash computed on collision candidates via Android `ContentResolver` streaming (no full-file in-memory loading).
  - Groups sorted by date: oldest item is flagged as `isOriginal = true`.
  - Registered on `MethodChannel("com.wapptidy/duplicate_detector")` in `MainActivity.kt`.
- **Data Source (`lib/features/clean/data/duplicates_data_source.dart`):**
  - Bridges Flutter to Kotlin detector via platform channel with in-memory size-bucketing fallback for test environments.
  - Computes `totalPotentialSavings` and attaches formatted `groupTitle` and `badgeLabel` ("Original" vs "Duplicate").
- **Presentation (`lib/features/clean/presentation/duplicates_screen.dart`):**
  - Reuses generic `CategoryScreen` with `initialViewMode: CategoryViewMode.list`.
  - **REQ-DUP-02:** Group title displays copy count, total size, and potential saving (`Save X MB`).
  - **REQ-DUP-03:** Non-original copies are pre-selected on load; the Original is preserved unselected. Deletion still mandates confirmation via `ConfirmationSheet`.
  - **REQ-DUP-04:** Dedicated banner highlights exact byte-for-byte matching with an explicit note separating it from visual/AI similarities.

### 2. Large Videos (REQ-VID-01)
- **Data Source (`lib/features/clean/data/large_videos_data_source.dart`):**
  - Drift query for `video/%` MIME types with size threshold (default $\ge 50$ MB).
- **Presentation (`lib/features/clean/presentation/large_videos_screen.dart`):**
  - Interactive chip filters: 50 MB+, 100 MB+, 250 MB+, 500 MB+, 1 GB+.
  - Sortable by File Size, Date Added/Modified, and Duration (`CategorySortKey.duration`).
  - Rows render video thumbnail, duration badge (`m:ss` or `h:mm:ss`), and human-readable file size.

### 3. Screenshots (REQ-SCR-01)
- **Data Source & Heuristic (`lib/features/clean/data/screenshots_data_source.dart`):**
  - Heuristic classifier (no ML in v1 per PRD):
    - Bucket name check: contains "screenshot" (case-insensitive).
    - Aspect ratio check: tall/narrow mobile screen ratio ($\ge 1.75$ or $\le 0.57$) for PNG/JPEG image files.
- **Presentation (`lib/features/clean/presentation/screenshots_screen.dart`):**
  - Relative date filters: Today, 7 days, 30 days, 6 months, 1 year+.
  - Standard 3-column grid view optimized for fast visual screenshot auditing.

### 4. Old Media (REQ-OLD-01)
- **Data Source (`lib/features/clean/data/old_media_data_source.dart`):**
  - Queries media with `dateModifiedSec` older than cutoff age (default $\ge 90$ days / 3 months).
  - Sub-groups items by media type: Images, Videos, Audio, Documents.
- **Presentation (`lib/features/clean/presentation/old_media_screen.dart`):**
  - Age filters: 3m+, 6m+, 1y+, 2y+, 3y+.
  - Type filters: All, Images, Videos, Audio.
  - Header banner displays the total recoverable space for the selected age threshold.

### 5. Shared Framework Enhancements
- Added `badgeLabel` parameter and `_BadgeChip` widget to `lib/core/widgets/media_tiles.dart` for visual status chips ("Original", "Duplicate").
- Extended `CategorySortKey` with `duration` in `lib/features/clean/domain/category_models.dart`.
- Extended `CategoryScreen` (`lib/features/clean/presentation/category_screen.dart`) with:
  - `initialSelectedIdsBuilder` for pre-selection without breaking generic behavior.
  - `headerBannerBuilder` for category-specific contextual summaries.
  - Group header rendering in list view for clustered categories (Duplicates, Old Media).
- Configured routes in `lib/core/router/app_router.dart`:
  - `/clean/duplicates`
  - `/clean/large-videos`
  - `/clean/screenshots`
  - `/clean/old-media`

---

## Verification & Tests

- **Unit & Widget Test Suite (`test/features/clean/v1_categories_test.dart`):**
  - `REQ-DUP`: Two-stage grouping, oldest Original marking, potential saving calculation, pre-selection of non-original copies, original unselected, ConfirmationSheet on delete.
  - `REQ-VID`: 50MB threshold filtering, size filter chips (50MB, 100MB, 500MB, 1GB), duration formatting.
  - `REQ-SCR`: Heuristic bucket name vs aspect ratio detection, date filter chips.
  - `REQ-OLD`: Type sub-grouping, recoverable size banner display, age filters.
- **All 89 tests passing:**
  - `flutter test --reporter=compact`: 89/89 passed.
  - `flutter analyze`: 0 issues found.
