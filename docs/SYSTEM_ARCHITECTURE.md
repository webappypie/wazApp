# System Architecture

## Principles
Local-first, modular, testable and resilient offline. Adapt to existing repository conventions; this document is a target, not a mandate to rewrite a sound architecture.

## Suggested layers
1. Presentation: screens, components, view state and accessibility.
2. Domain/application: use cases and business rules.
3. Data: media index, metadata database, preferences, local storage and repositories.
4. Platform adapters: Android storage access, iOS Photos/Files/share sheet, native media processing, notifications and device authentication.
5. Integration boundary: documented WAPCentral SDK/config and store billing. No new app-owned server.

## Suggested feature modules
`core/`, `features/onboarding/`, `status_discovery/`, `media_library/`, `media_viewer/`, `photo_editor/`, `video_editor/`, `status_maker/`, `private_folder/`, `storage_manager/`, `notifications/`, `promotions_ads/`, `premium/`, `data/media/`, `data/database/`, `platform/android/`, `platform/ios/`. Reuse existing coherent modules rather than relocating everything unnecessarily.

## Core flows
**Save:** user action → access validation → source validation → copy → verify destination → persist metadata → update UI. On failure, preserve source and show actionable error.

**Edit/export:** source → bounded preview → non-destructive edit state → background render/encode → temporary output → validate → finalize → persist metadata → share/export.

**WAPCentral:** documented initialization/config → consent/eligibility checks → placement request → valid content or no-content state. Network failure must not break core features. All API details must come from the root guide.

## Persistence
Use existing database if sound. Suggested metadata: stable ID, local path/URI, type, MIME, size, timestamps, dimensions/duration, favourite/private/edited flags, thumbnail reference and optional content hash. Version migrations, reconcile missing files, avoid filename-only IDs, and keep private items out of normal queries.

## Performance and errors
Move filesystem work, hashing, thumbnail generation and encoding off the UI thread. Bound concurrency/memory, make long jobs cancellable, use incremental indexing and bounded thumbnail caches. Use typed errors for permission denied, source unavailable, unsupported/corrupt media, low storage, cancellation, encode/database/billing/integration failures.

## Dependency policy
Check maintenance, licensing, platform support and binary size before adding libraries. Record material decisions in `docs/adr/`.
