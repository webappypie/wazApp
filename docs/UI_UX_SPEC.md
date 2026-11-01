# WazApp UI/UX Specification

## Brand direction
Familiar, friendly, fast and premium. Use an original green/teal status-inspired palette, not copied WhatsApp logos or official assets. Suggested tokens: deep teal `#075E54`, green `#128C7E`, accent `#25D366`, background `#F7FAF8`, text `#17211F`, muted `#66736F`. Tagline: **Save. Style. Share.**

## Navigation
Prefer existing coherent navigation. Suggested destinations: Home, Saved, Create, Private, Tools/Settings. If five tabs create clutter, use four and place utilities in a clear secondary surface.

## Home
Clear header and explanation. Android shows only genuinely accessible status media. iOS offers Photos/Files import and local library; never show a fake WhatsApp status feed. Primary actions: browse/import, saved library, create status. Scan progress and timestamps must reflect real operations. Promotions only from valid WAPCentral content and clearly labelled; ads must not resemble app controls.

## Library
Real thumbnails, type and video duration, search/filters that actually change results, persistent favourites/recents, multi-select and clear cancel. Bulk deletion confirmation states count and scope.

## Viewer
Full-screen media, correct aspect ratio, safe-area-aware controls, video controls only for video, and save/share/favourite actions. Missing media gets a recoverable error.

## Photo editor
Canvas preview plus compact scrollable tools: Adjust, Crop, Filters, Text, Stickers. Sliders show values and reset. Undo/redo reflect real edit history. Export has actual progress/errors and leaves original intact.

## Video editor
Preview, timeline/trim handles, time/duration, mute state and only supported export choices. Real progress/cancel; warn before discarding edits.

## Status maker
Text canvas, backgrounds/templates, text controls, Hindi/English. Test Devanagari shaping, wrapping, emoji and export; no clipped text. Provide 20–30 genuinely distinct presets.

## Private and storage
Explain app-private storage and authentication state. Do not say encrypted unless true. Storage totals must be accurate; duplicate suggestions never auto-delete. Confirm destructive actions.

## Design system and states
Centralized tokens for spacing, typography, radii, elevation, colour and motion. Every screen needs meaningful loading, empty, denied/partial permission, offline, error/retry and success states as applicable. Accessible contrast/touch targets, large text, safe areas and reduced-motion consideration. Avoid fixed layouts that overflow small screens.

## Screen inventory
Startup, onboarding, permission rationale/recovery, home/discovery, source-access setup, library/search/filter, viewer, save progress, multi-select, photo editor, video editor, status maker/templates, private folder/auth, storage manager, notification centre if supported, premium/remove ads, settings, privacy/about and integration/offline errors.


## Implemented design system (Phase 7)
Reference: the local Clenzy project (patterns only). Tokens: `core/design/tokens.dart` (colours, spacing, radii, type) and `core/design/waz_theme.dart` (`WazTheme` extension: hero gradients, on-hero colours, signature green, `AppMotion`). Fonts: Sora (display) + Plus Jakarta Sans (body), Hind as Devanagari fallback. Components: `AppCard`, `SectionTitle`, `AccentIcon`, `StatusPill`, `Entrance`, `StatusRing`, `MediaTile`, `EmptyState`/`ErrorState`/skeletons. Home shows one hero card per installed WhatsApp app; statuses open in a source screen grouped by day.
