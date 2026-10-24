# Phase 01 — Design System Detail

**Status:** Done  
**Completed:** 2026-09-17  

---

## What was built

### Design tokens (`lib/core/design/tokens.dart`)
- **Colour palette** — Material 3 `ColorScheme` for light and dark; brand primary `#1C6EF2`; semantic colours (`kColorSuccess`, `kColorWarning`, `kColorDestructive`) shared across both themes
- **`AppColors`** — `AppColors.light`, `AppColors.dark`, `AppColors.card(context)` for card backgrounds
- **`AppTextStyles`** — Full M3 type scale (displayLarge → labelSmall); exposed as `TextTheme`
- **`AppSpacing`** — 8-pt grid: xs(4) / sm(8) / md(16) / lg(24) / xl(32) / xxl(48) / xxxl(64); `pagePadding`, `cardPadding`, `sectionGap` constants
- **`AppRadius`** — xs(4) / sm(8) / md(12) / lg(16) / xl(24) / full(999); pre-built `BorderRadius` constants for cards, chips, buttons, bottom sheets
- **`AppElevation`** — none(0) / low(1) / card(2) / modal(6) / dialog(12)
- **`AppTheme.light()` / `AppTheme.dark()`** — assembles all tokens into `ThemeData`; overrides: `CardTheme`, `ElevatedButtonTheme`, `OutlinedButtonTheme`, `ChipTheme`, `NavigationBarTheme`, `DividerTheme`, `InputDecorationTheme`

### Component library (`lib/core/widgets/`)

| File | Components |
|---|---|
| `app_scaffold.dart` | `AppScaffold`, `PageHeader`, `SectionHeader` |
| `buttons.dart` | `PrimaryButton` (loading, icon, semantic), `SecondaryButton` (+ destructive variant) |
| `cards.dart` | `StorageCard` (hero), `StatCard` (metric), `CategoryCard` (tap target) |
| `media_tiles.dart` | `MediaTile` (grid, selection overlay, video chip, protected badge), `MediaListRow` |
| `filter_chip.dart` | `AppFilterChip` (selected = colour + checkmark icon, REQ-SET-03), `FilterChipRow` |
| `search_field.dart` | `SearchField` (clear button, semantic textField label) |
| `state_widgets.dart` | `EmptyState`, `ErrorState`, `SkeletonListLoader`, `SkeletonGridLoader` |
| `action_widgets.dart` | `BottomActionBar` (Move/Copy/Protect/Delete), `ConfirmationSheet` (P-02) |
| `monetisation_widgets.dart` | `NativeAdContainer` (collapses for Premium / unready), `UpgradeCard` |
| `data_widgets.dart` | `ProgressRing` (Media Health score ring), `AppProgressBar`, `SimpleBarChart` |

### Component gallery (`lib/features/dev/presentation/gallery_screen.dart`)
- Route `/dev/gallery` — guarded by `kDebugMode` in router; not reachable in release
- Side-by-side light/dark rendering toggle
- Demos all Phase 1 components with real interaction (selection, loading states, score variants)
- Accessible from Home screen via debug-only "Component Gallery" button

### Accessibility (REQ-SET-03 compliance)
- All interactive components: `Semantics` wrapper with `label`, `button`, `selected`, `enabled`
- `EmptyState` and `ErrorState` marked as `liveRegion: true` (screen reader announcements)
- `FilterChip` selected state: colour + checkmark icon (never colour alone)
- `ProgressRing` always carries numeric label (never relies on colour alone)
- All buttons ≥ 52 dp height (> 48 dp minimum)

## Verification
- `flutter analyze`: **0 issues**
- `flutter test`: **21/21 passed**

## Carried debt / notes
- `ProgressRing._scoreColor` takes `BuildContext` but doesn't use `colorScheme` — parameter kept for potential future theme-aware semantic colours in Phase 4.
- `NativeAdContainer` is a stub — real AdMob widget wired in Phase 8.
- `StorageCard` CTA uses inline `ElevatedButton` rather than `PrimaryButton` to allow narrower sizing — acceptable exception.
