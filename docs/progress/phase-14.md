# Phase 14 — Storage Growth Analytics with Historical Backfill (REQ-ANL-01, REQ-ANL-02, REQ-ANL-03, REQ-ANL-04, P-03)

**Status:** Done  
**Completed:** 2026-09-17  
**Requirements:** REQ-ANL-01, REQ-ANL-02, REQ-ANL-03, REQ-ANL-04, P-03; PRD §5.4, §11.3  
**Goal:** Local storage snapshot persistence, cold-start historical backfill engine reconstructing 30-day cumulative growth trajectory from MediaStore timestamps on first launch, time-range trend analytics (7D, 30D, 6M, All-time), custom area/line chart with scrubbing tooltips, and PRD §11.3 premium paywall gating.

---

## What was built

### 1. Snapshot Persistence Schema (REQ-ANL-01)
- **Database Table (`storage_snapshots` in `lib/core/database/app_database.dart`):**
  - Stores daily aggregated points:
    - `date_epoch_day` (INTEGER PRIMARY KEY)
    - `total_bytes` (INTEGER)
    - `image_bytes` (INTEGER)
    - `video_bytes` (INTEGER)
    - `audio_bytes` (INTEGER)
    - `document_bytes` (INTEGER)
    - `duplicate_bytes` (INTEGER)
    - `potential_cleanup_bytes` (INTEGER)
    - `space_recovered_bytes` (INTEGER)
    - `created_at` (INTEGER)
  - Index `idx_storage_snapshots_date` on `date_epoch_day`.
  - Upsert mechanism (`ON CONFLICT(date_epoch_day) DO UPDATE`) to refresh today's point dynamically.

### 2. Cold-Start Historical Backfill Engine (REQ-ANL-02, P-03)
- **Historical Backfill Engine (`AnalyticsRepository.backfillFromIndex()` in `lib/features/analytics/data/analytics_repository.dart`):**
  - Solves the cold-start problem where new users would otherwise see an empty graph for 30 days.
  - Queries all indexed media items from `AppDatabase`.
  - Groups items by epoch day using `dateAddedSec ~/ 86400`.
  - Computes running cumulative sums across media types (videos, images, audio, documents).
  - Bridges intermediate calendar days preserving cumulative totals so curves remain continuous.
  - **P-03 Truthful Calculation:** Every single historical point derives directly from actual MediaStore creation timestamps. No fabricated trends, simulated curves, or synthetic points.

### 3. Trend Analytics & Breakdown Engine (REQ-ANL-03)
- **Domain Layer (`lib/features/analytics/domain/analytics_models.dart`):**
  - `TimeRange`:
    - `sevenDays`: 7 days, Free tier
    - `thirtyDays`: 30 days, Free tier
    - `sixMonths`: 180 days, Premium gated (PRD §11.3)
    - `allTime`: Unbounded, Premium gated (PRD §11.3)
  - `AnalyticsTrends.compute()`:
    - Calculates `currentTotalBytes`, `netGrowthBytes`, `growthPercentage`, and `dailyAverageBytes`.
    - Handles positive/negative delta and zero-division edge cases.
  - `MediaTypeBreakdown`:
    - Computes category ratios, ranked breakdown list, and flags the `largestContributor`.

### 4. Interactive Growth Chart & UI (REQ-ANL-03, PRD §11.3)
- **Custom Painter Chart (`lib/features/analytics/presentation/widgets/storage_growth_chart.dart`):**
  - Area curve with smooth Bezier line and vertical gradient fill.
  - Horizontal guideline grids with formatted storage labels (MB/GB).
  - Interactive touch scrubbing with vertical scrub indicator and floating tooltip detailing date, cumulative volume, and daily delta.
- **Storage Analytics Screen (`lib/features/analytics/presentation/storage_analytics_screen.dart`):**
  - Top summary cards (Current Total, Net Growth for selected range, Daily Average).
  - Segmented time-range filter tabs with lock icons on Premium ranges (`6M`, `All`).
  - Interactive growth chart card.
  - Media type breakdown card featuring multi-color proportion bar and "Largest Contributor" highlight badge.
  - Cold-start attribution card explaining historical timeline reconstruction.
  - Premium upgrade paywall dialog with feature highlights when non-entitled users tap 6M or All-time.
- **Home Screen & Navigation Integration (`lib/core/router/app_router.dart`, `lib/features/home/presentation/home_screen.dart`):**
  - Registered route `/analytics` (`AppRoutes.storageAnalytics`).
  - Added "Trends" button in the Home hero card linking directly to storage analytics.

---

## Verification & Tests

1. **Backfill Engine Unit Tests (`test/features/analytics/backfill_engine_test.dart`):**
   - Verified that cold-start backfill accurately computes running cumulative storage from distinct media timestamps.
   - Verified gap-day propagation ensures continuous curves.
   - Verified `takeCurrentSnapshot()` refreshes today's snapshot accurately.
2. **Trend Analytics Unit Tests (`test/features/analytics/analytics_trends_test.dart`):**
   - Verified 7D/30D are free tier; 6M/All-time are Premium gated.
   - Verified mathematical correctness of net growth, percentage, and daily average.
   - Verified largest contributor determination.
   - Verified graceful handling of empty or single-point snapshots.
3. **Screen & Widget Tests (`test/features/analytics/storage_analytics_screen_test.dart`):**
   - Verified metric cards, time range tabs, chart canvas, breakdown bar, and largest contributor badge.
   - Verified range switching between 7D and 30D.
   - Verified paywall dialog trigger when selecting 6M or All without Premium entitlement.
4. **Static Analysis & Suite Run:**
   - `flutter analyze`: 0 issues found.
