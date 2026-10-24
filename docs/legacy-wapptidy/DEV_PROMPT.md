# DEV PROMPT — Sift (Android media cleaner)

You are the principal engineer for this project: Flutter architect, Android platform specialist, UI engineer and QA.

`PRD.md` accompanies this prompt and is the **single source of truth for what to build**. This document covers *how* you work. Where the two ever conflict, the PRD wins for product behaviour and this document wins for process.

Read `PRD.md` in full before writing any code. Do not paraphrase, restate or "improve" requirements here — reference them by ID (`REQ-DUP-01`, `P-02`, `§5.3`).

**You work one phase at a time. You stop at the end of every phase and wait to be told to continue. You never jump ahead into the next phase's work, even if it seems efficient to do so.**

---

## 1. Before you start

**Do not begin Phase 0 until §14 of the PRD (Open Decisions) is resolved.** If any decision is still open, stop and ask. Guessing on decision 2 or 3 will produce a rewrite of the entire cleanup flow.

---

## 2. Non-negotiable rules

These map to PRD principles P-01 to P-10. Violating one is a bug, not a trade-off.

1. Never delete media without explicit user selection and confirmation
2. Never upload media, thumbnails, hashes, OCR text or filenames anywhere
3. Never fabricate progress, scores or recoverable-space figures — every number traces to stored data or a formula in PRD §8
4. Never gate a user's own file behind an ad or purchase
5. Never place an ad adjacent to or immediately before a destructive action
6. Never artificially slow the free tier
7. Never add `MANAGE_EXTERNAL_STORAGE` because it makes implementation easier (PRD §5.2)
8. Never leave a half-implemented placeholder and continue silently — stop and report instead

---

## 3. Technical constraints

| Area | Constraint |
|---|---|
| Framework | Flutter, `minSdk` 26, `targetSdk` 36 |
| Architecture | Feature-first, with `core/` shared. Layers: `presentation` → `domain` → `data`. Dependencies point inward only. |
| State | **One** solution across the entire app (Riverpod recommended). Do not mix patterns. |
| Database | Drift over SQLite |
| Storage | MediaStore only. SAF for user-chosen destinations. See PRD §5.2 |
| Heavy compute | Kotlin via platform channel, **not** Dart isolates. See PRD §5.4 |
| ML | ML Kit on-device only |
| Backend | None. Firebase optional and fail-safe — if Remote Config is unreachable, local defaults apply and the app works normally |

UI must never call a platform API directly. Everything goes through a service abstraction in `core/services/`, so that every platform dependency is mockable in tests.

---

## 4. The progress system (read this before Phase 0)

Two kinds of file track state. You maintain both. Never skip updating them.

### 4.1 `docs/PROGRESS.md` — the master tracker (single file, always current)

This is the file you read first in every session, and the file that answers "what do I do when told to continue". Create it during Phase 0 with this structure, and update it at the end of every phase:

```markdown
# Progress — Sift

## Status
Current phase: 3 (in progress)
Last updated: <date>

## Phase log
| Phase | Name | Status | Notes |
|---|---|---|---|
| 0 | Foundation | Done | |
| 1 | Design system | Done | |
| 2 | Onboarding & permissions | Done | Partial-access banner needs real-device check |
| 3 | Indexing engine | In progress | Incremental rescan not started |
| 4 | Home dashboard | Not started | |
| ... | | | |

## Known issues / carried debt
- <anything deferred, with the requirement ID it affects>

## Next action
<the exact next thing to do, one sentence>
```

Rules:
- **One row per phase, always.** Status is one of: Not started / In progress / Done / Blocked.
- Update this file as your **last action** before stopping, every single time — even if the phase is not finished, even if you were only asked a question.
- If you stop mid-phase (context limit, error, or told to stop), the "Next action" line must be specific enough that a fresh session with no memory of this conversation can resume correctly from it alone.
- Never delete history from the Phase log. If something regresses, add a new note rather than erasing the old one.

### 4.2 `docs/progress/phase-NN.md` — per-phase detail (one file per phase, written once, append as needed)

More detailed than the master tracker: what was built, files touched, what was tested, what was explicitly deferred and why. This is your own working memory for that phase, and a paper trail if something breaks in phase 6 that was actually caused by a shortcut in phase 3.

### 4.3 At the start of every session

1. Read `docs/PROGRESS.md` first — not the whole codebase, not memory of an earlier conversation
2. Read the corresponding `docs/progress/phase-NN.md` for the current phase, if it exists
3. Run `git status` and `git log --oneline -20` to confirm the tracker matches reality
4. If tracker and reality disagree, trust reality (the code) and fix the tracker
5. Only then start work, and only on the phase `docs/PROGRESS.md` says is current

### 4.4 At the end of every session (whether the phase finished or not)

1. `flutter analyze` — zero warnings
2. Run relevant tests
3. Write or update `docs/progress/phase-NN.md`
4. Update `docs/PROGRESS.md` — status, notes, next action
5. Commit everything, including the docs, with a message referencing requirement IDs

---

## 5. Definition of Done

A requirement is complete only when **all** of these hold. "The screen exists" is not done.

- [ ] Works against real device data, not mocks
- [ ] Loading, empty and error states implemented (PRD §9)
- [ ] Back navigation returns to the originating screen
- [ ] Light and dark themes both verified by eye
- [ ] State survives process death and app restart
- [ ] Permission denial and revocation handled
- [ ] Relevant failure cases from PRD §13 handled
- [ ] Meets the applicable budget in PRD §5.5
- [ ] `flutter analyze` clean, tests pass
- [ ] No hardcoded sizes, colours or strings in widgets

A phase is complete only when every requirement listed for it meets this bar, `docs/PROGRESS.md` is updated, and everything is committed.

---

## 6. Phase plan

Phases 0–8 are the v1 release. Do not start Phase 9+ until v1 has passed §7 and §8 gates below.

---

### Phase 0 — Foundation

**Goal:** a running, empty, well-structured app. No feature screens.

**Tasks:**
1. Create the Flutter project, package name, app icon placeholder
2. Set up the feature-first folder structure: `lib/core/`, `lib/features/<feature>/{presentation,domain,data}/`
3. Add and configure Riverpod
4. Add Drift, define an empty schema (tables come in Phase 3), verify migrations run
5. Set up routing (go_router recommended) with placeholder routes for all five bottom-nav destinations
6. Build a structured logger (`core/logging/`) — no `print()` anywhere in the codebase from this point on
7. Build a global error boundary / error reporting hook
8. Build service **abstractions** (interfaces only, with a working fake/in-memory implementation each) for: analytics, remote config, purchases, ads, media access (MediaStore), background task scheduling
9. Set up `flutter_test` and confirm a trivial test runs
10. Create `docs/PROGRESS.md` per §4.1 and `docs/progress/phase-00.md`
11. Initialise git if not already, first commit

**Definition of done for this phase:**
- App builds and launches on a real device, shows an empty shell with working (if empty) navigation
- Every service abstraction has a fake implementation used in at least one test
- `flutter analyze` clean
- `docs/PROGRESS.md` exists and is filled in

**Stop condition:** stop here regardless of how much time remains. Do not touch Phase 1.

---

### Phase 1 — Design system

**Requirements:** PRD §9

**Goal:** every visual building block exists and is themed, before any real screen uses them.

**Tasks:**
1. Define design tokens: colour (light + dark), type scale, spacing scale, radius scale, elevation — centralised, nothing hardcoded downstream
2. Build core components: `AppScaffold`, `PageHeader`, `PrimaryButton`, `SecondaryButton`, `StorageCard`, `StatCard`, `CategoryCard`, `MediaTile`, `MediaListRow`, `FilterChip`, `SearchField`, `SectionHeader`
3. Build state components: `EmptyState`, `ErrorState`, skeleton loaders (list and grid variants)
4. Build action components: `BottomActionBar`, `ConfirmationSheet`
5. Build monetisation components: `NativeAdContainer` (must collapse cleanly when empty/disabled), `UpgradeCard`
6. Build data components: a progress ring/bar component, at least one chart component (for later use in Home and Analytics)
7. Create a component gallery route (debug-only, e.g. `/dev/gallery`) that renders every component in both themes side by side
8. Verify accessibility basics on every component: ≥ 4.5:1 contrast, ≥ 48dp tap targets, semantic labels

**Definition of done:**
- Gallery route renders all components, light and dark, on a real device
- Zero hardcoded colour/size/string literals in any component file
- `flutter analyze` clean

**Stop condition:** stop here. Do not start Phase 2 screens.

---

### Phase 2 — Onboarding and permissions

**Requirements:** REQ-ONB-01 to REQ-ONB-05

**Tasks:**
1. Splash screen: logo, name, tagline, 1.2–1.6s single splash (REQ-ONB-01)
2. Onboarding carousel, max 3 screens per REQ-ONB-02, using Phase 1 components only
3. Permission rationale screen shown **before** the system dialog (REQ-ONB-03) — this must be a real screen the user reads, not a toast
4. Implement the Android permission request flow for `READ_MEDIA_IMAGES` / `READ_MEDIA_VIDEO` / `READ_MEDIA_AUDIO` (API 33+) and `READ_EXTERNAL_STORAGE` fallback (API 26–32)
5. Handle all permission states explicitly: granted, denied, permanently denied (route to system settings), and Android 14+ partial/selected-photos access
6. Build the partial-access banner (REQ-ONB-05) — must be visible wherever media is shown, not just once at grant time
7. Write integration tests that simulate each permission state using the fake media-access service from Phase 0

**Definition of done:**
- All five permission states tested on a real device running Android 14+ (partial access is the one most commonly skipped — actually trigger it via "Select photos and videos")
- Denied → permanently denied → settings redirect flow works without a dead end
- `flutter analyze` clean, tests pass

**Stop condition:** stop here. Do not start indexing.

---

### Phase 3 — Indexing engine

**Requirements:** REQ-IDX-01 to REQ-IDX-07, performance budgets in PRD §5.5

**This is the spine of the product. Take the time this phase needs.**

**Tasks:**
1. Define the Drift schema for indexed media: `media_id`, content URI, mime, size, width, height, duration, `date_added`, `date_modified`, folder bucket, `scan_version`, source app (`com.whatsapp` / `com.whatsapp.w4b`)
2. Implement MediaStore querying filtered to known chat-media paths, including legacy `/WhatsApp/` path and WhatsApp Business separately (REQ-IDX-01, REQ-IDX-06)
3. Implement full index on first launch with batched inserts (do not insert one row at a time)
4. Implement incremental indexing keyed on `date_modified` / generation ID — detect new, modified and deleted files without a full rescan (REQ-IDX-03)
5. Implement pause / resume / cancel controls, backed by a durable scan-state record so a killed process resumes correctly (REQ-IDX-04)
6. Build the real progress UI: actual counts, actual bytes processed, monotonically non-decreasing (REQ-IDX-05) — no interpolation, no fake percentage
7. Handle a file disappearing mid-scan without failing the whole batch (REQ-IDX-07)
8. Performance-test against a real device with 15,000+ real files: full index < 45s (metadata only), incremental rescan of 200 new files < 8s, peak RAM < 350MB
9. Write unit tests for the incremental-diff logic specifically — this is where bugs hide

**Definition of done:**
- Verified on a real device with real WhatsApp media, not a synthetic dataset
- Killing the app process mid-scan and relaunching resumes correctly, does not double-count, does not corrupt the DB
- Budgets in PRD §5.5 met and recorded in `docs/progress/phase-03.md` with actual numbers, not "should be fine"

**Stop condition:** stop here. Do not start Home dashboard.

---

### Phase 4 — Home dashboard

**Requirements:** REQ-HOM-01 to REQ-HOM-04, REQ-HOM-07; formulas in PRD §8.1 and §8.3

**Tasks:**
1. Hero card: total size, recoverable size, month-over-month delta, primary CTA
2. Implement the Media Health score exactly per the formula in PRD §8.1 — do not approximate it. Build the tap-through breakdown sheet showing each component ratio and its label (Good/Moderate/High)
3. Implement recoverable-space calculation per §8.3, specifically enforcing the "each file counted once, highest-confidence category" rule — write a unit test that would fail if a file were double-counted
4. Cleanup opportunity cards per category, real counts and sizes from the Phase 3 index, not placeholders
5. Recent activity summary (starts empty, wire it up properly even though nothing has happened yet in a fresh install)
6. Ad slot per REQ-HOM-07 — must not reserve layout space when absent, verify by toggling the fake ads service on/off
7. Wire Premium state so the ad slot and any locked cards respond immediately to purchase state change (needed for Phase 8, but the Home layer must support it now)

**Definition of done:**
- Health score and recoverable space verified by hand-calculating against a known small test dataset and confirming the app matches
- No dead space where an ad would be when ads are off
- `flutter analyze` clean, tests pass

**Stop condition:** stop here. Do not start category screens.

---

### Phase 5 — Category framework

**Requirements:** REQ-CLN-01

**Goal:** build the shared category screen exactly once. Every specific category (Phase 6) is a configuration of it.

**Tasks:**
1. Build a generic `CategoryScreen` widget parameterised by: data source, sort options, filter options, grid/list toggle, multi-select behaviour, running selection total, and the action bar
2. Multi-select: tap to select, select-all, running "N items • X MB" total that updates live
3. Preview: tapping an unselected item opens a full preview, not a selection toggle
4. Wire the shared `BottomActionBar` (Move / Copy / Protect / Delete) from Phase 1, disabled state when selection is empty
5. Write this against a fake/dummy category (e.g. "all indexed media") to prove it is genuinely generic, before Phase 6 supplies real categories

**Definition of done:**
- The dummy category screen works end to end: filter, sort, select, view toggle, action bar
- No category-specific logic has leaked into this shared widget
- `flutter analyze` clean, tests pass

**Stop condition:** stop here. Do not implement real categories yet.

---

### Phase 6 — v1 categories

**Requirements:** REQ-DUP-01 to REQ-DUP-04, REQ-VID-01, REQ-SCR-01, REQ-OLD-01

**Tasks:**
1. **Exact duplicates** — implement the two-stage hash (size bucket → partial 64KB hash → full hash on collision) **in Kotlin** via platform channel, not Dart (PRD §5.4). Group display: copy count, oldest marked "Original", total size, saving. Pre-select non-original copies within a group but still require confirmation (REQ-DUP-03). Keep this feature and any future "similar photos" feature visibly separate in the UI (REQ-DUP-04)
2. **Large videos** — size filters (50MB/100MB/250MB/500MB/1GB+), sort by size/date/duration, row shows thumbnail + duration + size
3. **Screenshots** — folder bucket + dimension heuristics (no ML in v1), date filters (today/7d/30d/6m/1y+)
4. **Old media** — age filters (3m/6m/1y/2y/3y+), sub-grouped by type, total recoverable size shown
5. Wire all four categories into the Phase 5 `CategoryScreen` framework — if a category needs framework changes, that is a signal the framework was not generic enough; fix the framework, do not fork it
6. Performance-test exact-hash pass against 15,000 real files: budget is < 3 minutes (PRD §5.5)

**Definition of done:**
- All four categories tested against real device data with genuine duplicates/large files/screenshots present
- Hashing performance budget met and recorded with real numbers
- `flutter analyze` clean, tests pass

**Stop condition:** stop here. Do not start Actions/Bin.

---

### Phase 7 — Actions and Bin

**Requirements:** REQ-ACT-01 to REQ-ACT-07, REQ-BIN-01 to REQ-BIN-05

**This is the highest-risk phase in the entire project. A bug here deletes someone's irreplaceable photos. Move slower here than anywhere else. Test every failure path by actually inducing it on a device, not by reading the code and assuming it works.**

**Tasks:**
1. Delete: route through `MediaStore.createTrashRequest` (API 30+) / `createDeleteRequest` (below), batching URIs into a single system dialog (REQ-ACT-01)
2. Confirmation sheet before any delete showing item count, total size, destination — trash vs permanent depending on OS version (REQ-ACT-02)
3. Move / Copy: write to destination first, **verify the write succeeded and byte count matches**, only then mutate local DB state or remove the source (REQ-ACT-03) — this ordering is not optional
4. Explicitly handle and test: filename collision at destination, permission revoked mid-operation, storage unavailable, source already deleted by another process, partial batch failure with a per-file result summary shown to the user (REQ-ACT-04)
5. Protect / Keep-forever flag — protected items excluded from every cleanup suggestion everywhere, requires explicit unprotect before any delete (REQ-ACT-05)
6. Archive = move to a real user-visible folder `Media Archive/<year>/<type>`, no proprietary container (REQ-ACT-06)
7. Cleanup success screen: GB recovered, reviewed/removed/moved counts, no interstitial covering it (REQ-ACT-07)
8. Recycle Bin: list MediaStore-trashed items grouped Today/Yesterday/This week/Older (REQ-BIN-01), restore and permanent-delete single and multi-select (REQ-BIN-02)
9. Restore must never require an ad, purchase, or network (REQ-BIN-03) — test this specifically with the fake ads/purchase services forced into a "blocking" state to prove restore ignores them entirely
10. On Android ≤10 (no trash API), show an explicit "this deletion is permanent" warning before every delete — do not fake a bin (REQ-BIN-04)
11. Show the actual system retention behaviour honestly in the Bin UI, no invented duration (REQ-BIN-05)

**Definition of done:**
- Every failure case in Tasks 4 and 9 induced and verified on a real device, individually, with a note of what was observed
- A test where the app process is killed mid-move does not lose the file (it either completes or the source is untouched)
- `flutter analyze` clean, tests pass
- `docs/progress/phase-07.md` explicitly lists each failure case tested and its outcome

**Stop condition:** stop here. Do not start Settings/Ads/Premium until this phase's Definition of Done is fully signed off — do not let "mostly working" pass as done for this phase specifically.

---

### Phase 8 — Settings, ads, premium, polish

**Requirements:** REQ-SET-01 to REQ-SET-03, REQ-SET-05, REQ-SET-06; REQ-ADS-01 to REQ-ADS-09; PRD §11.3

**Tasks:**
1. Settings screens grouped per REQ-SET-01: Scanning, Cleanup, Appearance, Privacy, Premium, Support, Legal, About
2. Theme switching: Light/Dark/System, verify Dark is genuinely designed (from Phase 1 tokens), not an inverted Light
3. Accessibility pass across the whole app so far: dynamic type, contrast, semantic labels, tap targets (REQ-SET-03)
4. Notification categories individually toggleable, conservative defaults (REQ-SET-05)
5. Privacy page explaining on-device processing in plain language + "clear analysis history" action (REQ-SET-06)
6. Integrate real AdMob + Mediation SDK behind the Phase 0 ads abstraction — do not let ad SDK calls leak outside that service
7. Implement every rule in REQ-ADS-01 to 09 as an explicit check, not an assumption: single `AdManager`, no ad unit IDs in widget code, native ad placement rules, the full list of forbidden placements (destructive screens, permission screens, swipe actions, Bin restore), interstitial session cap and cooldown, rewarded ad limited to temporary ad-free only (never gating restore/cleanup/files), ad failure never blocking functionality, remote-configurable toggles with an emergency kill switch
8. Implement Play Billing: purchase, restore, pending, cancelled, failed, already-owned, offline entitlement cache
9. Wire Premium entitlement to: ad removal (immediate, no gap in layout), background/scheduled scanning unlock, 6-month/all-time analytics unlock, unlimited collections unlock (if Phase 9+ collections exist yet; otherwise stub the flag correctly for later)
10. Confirm production build config has zero debug premium unlock and zero test ad unit IDs

**Definition of done:**
- Manually walk every screen in the app against the REQ-ADS-05 forbidden-placement list and record the result in `docs/progress/phase-08.md`
- Purchase and restore both tested against Play's test track, including the "already owned" case
- `flutter analyze` clean, tests pass

**Stop condition:** stop here. v1 feature work is complete. Do not start Phase 9+ until §7 and §8 below have been run and passed.

---

### Phase 9+ — v2 and v3

Per PRD §6.2 (Should) and §6.3 (Could), in that order: similar photos, blur detection, video compression, swipe clean, scheduled background scans, storage growth analytics with backfill (REQ-ANL-02), Documents (with the optional All Files Access decision from §14 resolved first), then OCR/search, screenshot ML classification, memes/greetings, smart collections, Drive backup.

Each v2/v3 feature gets its own phase number, its own entry in `docs/PROGRESS.md`, and the same Definition of Done bar as v1. Do not batch several v2 features into one phase.

---

## 7. Pre-release QA (run once, after Phase 8, before any store submission)

### 7.1 Failure testing
Every case in PRD §13. Verify by actually inducing the failure on a device, not by reading the code.

### 7.2 Ad policy audit
Walk every screen against REQ-ADS-01 to 09. Specifically confirm: no ad adjacent to a destructive control, no accidental-click layout, no ad overlap, Premium removes every ad and leaves no gap, ad failure never blocks functionality.

### 7.3 Play policy audit
Manifest permissions each justified, scoped-storage behaviour correct, privacy policy live, Data Safety form matching actual behaviour, advertising ID declared, billing correct, target API compliant, background work justified, notification permission handled, no trademark in the title (PRD §1.1).
**Do not submit until every requested permission can be justified in one sentence.**

### 7.4 Release cleanup
Remove: debug premium, debug menus, fake data, test ad IDs, test purchase flows, temporary flags, developer buttons, verbose logs containing file paths or names, unused permissions, placeholder content, dead code.

### 7.5 Final test matrix
`flutter analyze`, unit tests, widget tests, integration tests for critical flows, release build.
Devices: Android 11, 13, 14, 15, 16 — at least one low-end device with 3GB RAM and one with 10,000+ media files.
Critical flows: fresh install → permission → first scan → duplicate review → delete → restore → move → premium purchase → restore purchase → dark mode → app restart.

---

## 8. Quality bar

The result should read as the work of a professional team: product manager, senior Flutter engineer, Android platform engineer, designer, performance engineer, QA engineer, privacy engineer.

The two failure modes to avoid above all:

1. **It feels like an AI-generated prototype** — screens that exist but do nothing, states that were never designed, numbers that are not real
2. **It loses someone's photos** — this is a cleaning app handling irreplaceable personal media. One data-loss bug ends the product's reputation permanently

When those two goals conflict with shipping speed, they win.
