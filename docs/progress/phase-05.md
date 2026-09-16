# Phase 05 — Category Framework Detail

**Status:** Done  
**Completed:** 2026-09-17  
**Requirements:** REQ-CLN-01  
**Goal:** Build the shared, generic category screen once. Every specific category (Phase 6) will be a configuration of it.

---

## What was built

### Domain models (`lib/features/clean/domain/category_models.dart`)
Pure domain models independent of any platform or specific category logic:
- `CategoryItem`: Media model containing `id`, `contentUri`, `displayName`, `mimeType`, `sizeBytes`, `dateAddedSec`, `dateModifiedSec`, `bucketName`, `sourceApp`, `width`, `height`, `durationMs`, `isProtected`, optional `thumbnailProvider`, and fallback `defaultPlaceholder`.
- `CategorySortOption`: Sorting by `dateModified`, `size`, or `name` in ascending or descending direction.
- `CategoryFilterOption`: Filter predicate mapping.
- `CategoryViewMode`: Toggle enum between `grid` and `list`.
- `formatBytes`: Exact byte-formatting helper conforming to PRD P-03.

### Data source contracts & implementations
- `CategoryDataSource` (`lib/features/clean/domain/category_data_source.dart`): Abstract interface defining `getItems()` and optional `watchItems()`.
- `FakeCategoryDataSource` (`lib/features/clean/data/fake_category_data_source.dart`): In-memory configurable test data source supporting dynamic removal and updates.
- `AllIndexedMediaDataSource` (`lib/features/clean/data/all_indexed_media_data_source.dart`): Concrete data source querying all items from Drift's `MediaItems` table.

### Media Preview Sheet (`lib/features/clean/presentation/media_preview_sheet.dart`)
- Triggered when tapping an unselected media item (REQ-CLN-01 Task 3).
- Displays visual thumbnail/player placeholder, filename, resolution, duration, file size, MIME type, folder/bucket, source app (WhatsApp vs WhatsApp Business), and protection status.
- Offers direct "Select" / "Deselect" action and "Close".
- Enclosed in `SingleChildScrollView` to eliminate overflows on any viewport size.

### Generic CategoryScreen (`lib/features/clean/presentation/category_screen.dart`)
Parameterised by:
- Data source (`CategoryDataSource`)
- Sort options (`List<CategorySortOption>`)
- Filter options (`List<CategoryFilterOption>`)
- Grid / List view mode toggle (dynamically switches between `MediaTile` in a 3-column Grid and `MediaListRow` in a List)
- Multi-select behavior:
  - Tapping unselected item opens preview sheet
  - Tapping selected item deselects it
  - Long-pressing any item toggles its selection
  - Select All / Deselect All icon button in AppBar
  - Live running total: displays "N items • X MB"
- BottomActionBar:
  - Wires Move, Copy, Protect (or Unprotect when all selected are protected), and Delete
  - Action buttons disabled when selection is empty
  - Delete triggers `ConfirmationSheet` with destructive styling before calling `onDelete`
- State handling:
  - Loading: `SkeletonGridLoader` / `SkeletonListLoader`
  - Empty: `EmptyState`
  - Error: `ErrorState` with retry

### Routing & Integration
- Route `/clean/all-media` added in `lib/core/router/app_router.dart` as a sub-route under `/clean`.
- "Browse All Indexed Media" action added to `CleanScreen` Done state.

---

## Verification & Tests

Test suite (`test/features/clean/category_framework_test.dart`):
1. `formatBytes` returns accurate formatted string for 0 B, 512 B, 1 KB, 1 MB, 150 MB, 2 GB.
2. `CategoryItem` duration formatting (e.g. 125s -> "02:05") and size formatting.
3. Renders items in Grid view with `MediaTile`.
4. Toggles view mode cleanly between Grid (`MediaTile`) and List (`MediaListRow`).
5. Tapping an unselected item opens `MediaPreviewSheet` with file metadata and resolution.
6. Long-pressing an item selects it and updates live running total (`1 items • 2.0 MB` -> `2 items • 152.0 MB`), and tapping deselects it.
7. Select All selects all items, and deselects all when already selected.
8. Filter chip selection filters items and live selection totals.
9. Sort button opens sort sheet and sorts items (e.g. Largest first places 150 MB item first).
10. Delete in `BottomActionBar` triggers `ConfirmationSheet`, calls `onDelete` on confirm, and transitions to `EmptyState`.
11. Empty data source renders `EmptyState`.

- `flutter analyze`: 0 issues found.
- `flutter test`: 82/82 tests pass.

---

## Stop condition
Phase 5 complete. Stop here per DEV_PROMPT.md. Do not implement real categories yet.
