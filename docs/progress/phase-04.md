# Phase 04 — Home Dashboard Detail

**Status:** Done  
**Completed:** 2026-09-17  
**Requirements:** REQ-HOM-01 to REQ-HOM-04, REQ-HOM-07; PRD §8.1, §8.3

---

## What was built

### Domain models (`lib/features/home/domain/home_models.dart`)

Pure Dart — no Flutter, Drift, or platform dependencies.

| Type | Purpose |
|---|---|
| `HealthScoreInputs` | Raw byte counts for each §8.1 formula component |
| `HealthLabel` | `good / moderate / high` per §8.1 threshold (< 0.05 / < 0.15 / ≥ 0.15) |
| `HealthScoreComponent` | One breakdown row: label, ratio, deduction, label |
| `HealthScoreResult` | Final score 0–100 + component list; `HealthScoreResult.compute()` implements §8.1 exactly |
| `RecoverableFile` | Single candidate with contentUri, sizeBytes, category |
| `RecoverableSpaceResult` | `compute()` enforces §8.3 "each file counted exactly once" via a seen-set |
| `OpportunityCard` | Card data: id, title, subtitle, fileCount, totalBytes, routePath |
| `RecentActivityEntry` | Action label, filesCount, bytesRecovered, timestamp |
| `HomeDashboard` | Aggregates all sections; `HomeDashboard.empty` for fresh installs |

### Formulas — PRD §8.1 (exact implementation)

```
duplicate_ratio   = duplicate_bytes / total_bytes
large_video_ratio = bytes_in_videos_over_100MB / total_bytes
old_ratio         = bytes_older_than_1y / total_bytes
clutter_ratio     = (screenshot + blurry + greeting bytes) / total_bytes

score = 100
      - min(30, duplicate_ratio   * 100)
      - min(25, large_video_ratio * 60)
      - min(25, old_ratio         * 50)
      - min(20, clutter_ratio     * 80)

score = clamp(score, 0, 100)
```

Phase 4 state: duplicate_bytes = 0 (Phase 6 adds detection). PRD §8.1 rule: "categories not yet implemented contribute 0".

### PRD §8.3 — double-counting guard (SHIP BLOCKER)

`RecoverableSpaceResult.compute()` maintains a `seen` Set<String> of content URIs. If the same URI appears multiple times across categories, only the first (highest-priority category) is counted. A unit test marked **SHIP BLOCKER** verifies this:

```dart
// Same URI submitted twice → total must be 500, not 1000
expect(r.totalRecoverableBytes, 500,
    reason: 'Double-counting ship blocker: same URI counted twice');
```

### Data layer

| File | Notes |
|---|---|
| `real_home_repository.dart` | Queries Drift for large-video bytes, old-media bytes, screenshot bytes (bucket heuristic), month-over-month delta via `dateAddedSec`, opportunity card counts |
| `fake_home_repository.dart` | Configurable default dashboard (4 GB, known health inputs), `recordActivity()` appends entries |

### Providers (`home_providers.dart`)

- `homeRepositoryProvider` — Real impl by default; overridable in tests
- `homeDashboardProvider` — `FutureProvider.autoDispose<HomeDashboard>`
- `refreshHomeDashboardProvider` — sentinel for post-action cache invalidation

### Home screen UI

| Section | Requirement | Notes |
|---|---|---|
| Hero card | REQ-HOM-01 | Total size, recoverable badge, month-over-month delta (↑ growth = kColorWarning, ↓ = kColorSuccess), "Review Cleanup" CTA navigates to Clean tab |
| Health score | REQ-HOM-02 | `CircularProgressIndicator` gauge 0–100; tap opens bottom sheet with all 4 component rows (ratio bars, Good/Moderate/High labels, "Never an AI score" disclaimer) |
| Ad slot | REQ-HOM-07 | `NativeAdContainer` — zero layout space when Premium or not enough content above |
| Opportunity cards | REQ-HOM-03 | Real DB counts and sizes; icon resolved via `_iconForCard(id)` static lookup (avoids non-const `IconData`); taps route to category screen |
| Recent activity | REQ-HOM-04 | Empty state on fresh install: "No cleanup sessions yet"; entries show formatted bytes + relative time |

**Design rules enforced:**
- P-03: all numbers from DB — no fake values
- P-04: no red dashboards, no fear language
- REQ-HOM-07: Premium users see no ad node in the layout at all

---

## Tests — 71/71 pass

**New in Phase 4 (`test/features/home/home_formulas_test.dart`)** — 21 tests:

| Group | Tests |
|---|---|
| Health score | empty=100, all-zero=100, max-dup-30, max-vid-25, max-old-25, max-clutter-20, all-max→0, hand-calculated 4GB dataset (±1 tolerance), 4 components returned, HealthLabel thresholds, score always 0–100 |
| Recoverable space | single candidate, **SHIP BLOCKER double-count**, protected excluded, empty=0, all-protected=0, 10 files sum, byCategory populated |
| HomeDashboard.empty | score=100, recoverable=0, formatted="0 B" |

---

## Carried debt
- `homeRepositoryProvider` uses `RealHomeRepository` which returns empty `recentActivity: []` — Phase 7 (Actions) will persist activity entries to a new Drift table and join them here.
- Large-video candidates are tagged `RecoverableCategory.duplicate` as a placeholder until Phase 6 adds real exact-dup detection. Phase 6 must re-tag correctly and re-run the no-double-count invariant.
- `screenshotBytes` uses `LIKE '%Screenshot%'` bucket heuristic — Phase 6 (REQ-SCR-01) refines this with dimension heuristics.
- Month-over-month delta uses `dateAddedSec` from `MediaItems` — REQ-ANL-01/02 snapshots (Phase 8) will provide a proper history table.
- `iconData` field on `OpportunityCard` domain model retains the codepoint field for potential future serialisation but the widget uses `_iconForCard(id)` to stay const-safe.
