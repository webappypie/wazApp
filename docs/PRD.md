# PRD — Smart Media Cleaner & Organizer (Android)

**Version:** 2.0 (merged, deduplicated)
**Status:** §14 open decisions resolved 2026-09-17 — Phase 0 in progress
**Platform:** Android only, Flutter
**Launch market:** India

> This document is the single source of truth for *what* we build and *why*.
> The companion `DEV_PROMPT.md` covers *how* we build it. It references this document by requirement ID and must not restate requirements.

---

## 1. Product definition

A storage manager built for the mess that messaging apps create. Not a junk cleaner.

**Positioning statement:** See what takes space. Keep what matters. Clean the rest safely.

**Core philosophy:** Organize first. Clean safely. Never delete without review.

The app answers these user questions:
- Why is chat media using so much storage?
- What is consuming the most space?
- Which files are exact duplicates?
- Which media is old and forgettable?
- Which files should I move instead of delete?
- How fast is my storage growing?
- How much space can I realistically recover?

### 1.1 Naming and trademark

The product must **not** ship with "WhatsApp" in the Play Store title. That is a Meta trademark violation and a rejection/takedown risk.

- Confirmed brand name: **WappTidy** (resolved 2026-09-17; "Wapp" is not the full WhatsApp trademark — verify final legal clearance before store submission)
- Play title: `WappTidy — Media Cleaner & Organizer`
- "for WhatsApp" may appear in the long description only, in a functional, non-branded way
- No WhatsApp logo, no WhatsApp green, no WhatsApp typography anywhere

### 1.2 Why not Files by Google

Files by Google already offers free duplicate detection, large-file cleanup and a "chat app junk" card. Our differentiation is **not** cleaning. It is:

1. **Organize, not just delete** — move, archive, protect, collections
2. **Growth intelligence** — how much media you accumulate per week/month and from what
3. **India-specific categories** — greetings, forwards, festival images, screenshot intelligence
4. **Review-first safety** — nothing disappears without you seeing it

Every roadmap decision must strengthen at least one of these four. If it does not, it is not a priority.

---

## 2. Product principles

| ID | Principle |
|---|---|
| P-01 | Core media analysis happens on-device. No media, thumbnails, hashes, OCR text or filenames leave the device. |
| P-02 | Never delete automatically. Every destructive action requires explicit selection plus confirmation. |
| P-03 | No fake data ever: no fabricated progress, no invented AI scores, no inflated recoverable-space numbers. |
| P-04 | No fear messaging, no "your phone is at risk", no red-alert dashboards. |
| P-05 | Recovery of a user's own file is never gated behind an ad or a purchase. |
| P-06 | No ad may be placed adjacent to, or immediately before, a destructive action. |
| P-07 | Free users are never artificially slowed to make Premium look faster. |
| P-08 | Files are never trapped in a proprietary app-only format. Archive = a real folder on the device. |
| P-09 | Request the minimum Android permission that makes the feature work. |
| P-10 | No custom backend. Firebase optional and fail-safe. |

---

## 3. Success metrics

Without these the PRD is a wishlist. Instrument from day one.

### 3.1 North star
**GB recovered per monthly active user.** Target: ≥ 1.5 GB in first 30 days per activated user.

### 3.2 Activation funnel (targets for v1)

| Metric | Target |
|---|---|
| Install → media permission granted | ≥ 70% |
| Permission granted → first scan completed | ≥ 85% |
| First scan → at least one cleanup action | ≥ 45% |
| D1 retention | ≥ 30% |
| D7 retention | ≥ 15% |
| D30 retention | ≥ 8% |

### 3.3 Business

| Metric | Target |
|---|---|
| Ad ARPDAU (India, free tier) | ₹0.30–0.60 |
| Premium conversion (of MAU, lifetime) | 0.8–1.5% |
| Crash-free sessions | ≥ 99.5% |
| Play rating after 1,000 reviews | ≥ 4.3 |

### 3.4 Guardrail metrics (regression = stop ship)
- Accidental-deletion complaints per 1,000 users
- Restore-from-bin rate (a spike means our suggestions are wrong)
- Scan abandonment rate
- Ad-attributed crash/ANR rate

---

## 4. Target users

Heavy WhatsApp users in India with 64–128 GB devices: family-group members, students, small-business owners, office workers. Characterised by 10,000+ media files, 15–40 GB of chat media, and repeated "storage full" notifications.

Localisation: English and Hindi at launch. Hinglish-friendly microcopy. Additional regional languages post-v1.

---

## 5. Technical foundation — resolved decisions

These were ambiguous in the original draft and are now **decided**. Changing them invalidates downstream requirements.

### 5.1 Android targets
- `minSdk` = 26 (Android 8.0)
- `targetSdk` = 36 (current Play requirement)
- Primary test matrix: Android 11, 13, 14, 15, 16

### 5.2 Storage access strategy — **Decision: MediaStore-only for v1**

Chat media on Android 11+ lives at `Android/media/com.whatsapp/WhatsApp/Media/`. Images, video and audio there **are** indexed by MediaStore and readable with `READ_MEDIA_IMAGES` / `READ_MEDIA_VIDEO` / `READ_MEDIA_AUDIO`. Non-media files (PDF, DOCX, ZIP) are **not** reachable under scoped storage without All Files Access.

**v1 ships with no All Files Access.** Consequences, accepted:

| Capability | v1 status |
|---|---|
| Photos, videos, audio, voice notes, GIFs, stickers | Supported |
| Documents (PDF/DOC/XLS/PPT/ZIP) | **Deferred to v2** |
| Delete other-apps' media | Via `MediaStore.createDeleteRequest` / `createTrashRequest` (batched system dialog) |
| Move / Copy to user folder | Write to MediaStore-owned collections (Pictures / Movies / Download) or an SAF-picked tree outside `Android/` |
| Reading old `/sdcard/WhatsApp` path (Android ≤10 upgraders) | Supported where MediaStore indexes it |

v2 may add an **optional** All Files Access flow, requested only when the user opens the Documents feature, with the Play "file management app" declaration and demo video prepared in advance. It is never required for core cleanup.

### 5.3 Recycle Bin — **Decision: system trash, retention is not a Premium lever**

Two options were evaluated:

- *App-private copy*: copy to app storage, delete original. Rejected — the file still occupies space, so a "cleaner" that frees nothing for 7 days is self-defeating, and it inflates app size.
- *MediaStore trash* (`IS_TRASHED`, Android 11+): system-managed, roughly 30 days, space accounting handled by the OS. **Selected.**

Implications:
- Retention duration is **not under our control**, therefore "30-day bin" is removed from the Premium tier (see §11)
- On Android 10 and below, no trash API exists. Show an honest pre-delete warning: deletion is permanent on this device.
- The Bin tab lists trashed items via MediaStore with restore and permanent-delete actions
- REQ-BIN-* requirements reflect this, not the original design

### 5.4 Processing architecture
Flutter UI, **native Kotlin** for anything heavy. Perceptual hashing, blur scoring and classification of 10,000+ images in Dart isolates will not meet the performance budget. Use a platform channel to a Kotlin worker using ML Kit and `RenderScript`-free bitmap ops.

### 5.5 Performance budget (hard requirements)

| Operation | Budget |
|---|---|
| Cold start to interactive Home | < 1.8 s |
| Full first index, 15,000 files (metadata only) | < 45 s |
| Exact-hash pass, 15,000 files | < 3 min |
| Perceptual hash + blur, 10,000 images | < 5 min |
| Peak RAM during scan | < 350 MB |
| Grid scroll | 60 fps, no dropped-frame clusters > 3 |
| Incremental rescan, 200 new files | < 8 s |

Never decode a full-resolution image for a grid thumbnail.

---

## 6. Scope and phasing

The original plan had 70 sections and 33 phases. That is a team-scale, multi-year product. It is cut to a shippable v1.

### 6.1 v1 — MUST ship

Media indexing engine · Home dashboard · Exact duplicates · Large videos · Screenshots (size/date grouping, no ML classification) · Old media · Delete · Move / Copy · Protect · Recycle Bin · Settings · Themes · Ads infrastructure · Premium purchase · Onboarding and permissions

### 6.2 v2 — SHOULD

Similar photos (perceptual) · Blur detection · Suggested-best-shot · Video compression · Swipe Clean · Scheduled background scans · Storage growth analytics · Documents (with optional All Files Access)

### 6.3 v3 — COULD

OCR and smart search · Screenshot ML classification · Memes and greetings · Smart collections · Google Drive backup · Repeated-media detection

### 6.4 WON'T (this cycle)
Face grouping · iOS · Subscriptions · Any cloud sync of analysis data · Automatic unattended backup

---

## 7. Requirements

Priority: **M** = Must (v1), **S** = Should (v2), **C** = Could (v3).

### 7.1 Onboarding and permissions

| ID | P | Requirement |
|---|---|---|
| REQ-ONB-01 | M | Splash screen: logo, name, tagline "Clean less. Organize smarter." 1.2–1.6 s. Single splash only. |
| REQ-ONB-02 | M | Maximum 3 onboarding screens: (1) media organized, (2) nothing deleted automatically, (3) analysis stays on device. |
| REQ-ONB-03 | M | A contextual rationale screen explains why media access is needed **before** the Android system dialog fires. |
| REQ-ONB-04 | M | Handle denied, permanently-denied and partial-access (Android 14+ selected-photos) states with a route to system settings. |
| REQ-ONB-05 | M | Partial photo access must degrade gracefully with an explicit "you've limited access, results will be incomplete" banner, not a crash or an empty screen. |

### 7.2 Indexing engine

| ID | P | Requirement |
|---|---|---|
| REQ-IDX-01 | M | Discover chat media via MediaStore filtered to known chat-app media paths (`com.whatsapp`, `com.whatsapp.w4b`, legacy `/WhatsApp/`). |
| REQ-IDX-02 | M | Persist per file: `media_id`, content URI, mime, size, width, height, duration, `date_added`, `date_modified`, folder bucket, scan_version. |
| REQ-IDX-03 | M | First launch = full index. Subsequent launches = incremental only (new, modified, deleted), keyed on `date_modified` and generation ID. |
| REQ-IDX-04 | M | Scan must support pause, resume, cancel, deterministic progress, and recovery after process death. |
| REQ-IDX-05 | M | Progress UI shows real stages and real counts (`12,481 items analyzed`, `24.6 GB processed`). Percentages must never jump backwards or be fabricated (P-03). |
| REQ-IDX-06 | M | Detect and index WhatsApp Business (`com.whatsapp.w4b`) separately, with a source filter in the UI. |
| REQ-IDX-07 | M | Handle a file disappearing mid-scan (externally deleted) without failing the batch. |

### 7.3 Home dashboard

| ID | P | Requirement |
|---|---|---|
| REQ-HOM-01 | M | Hero card: total chat-media size, potential recoverable size, month-over-month delta, primary CTA "Review Cleanup". |
| REQ-HOM-02 | M | Media Health score 0–100 with the deterministic formula in §8. Never an "AI score". Tapping it shows the component breakdown. |
| REQ-HOM-03 | M | Cleanup opportunity cards: icon, category, file count, total size, optional preview collage. No oversized CTAs. |
| REQ-HOM-04 | M | Recent activity summary (last cleanup, GB recovered). |
| REQ-HOM-05 | S | Storage growth chart with 7-day / 30-day / 6-month / all-time ranges. |
| REQ-HOM-06 | S | Smart insights derived from real stored data, e.g. "Large videos account for 42% of your chat storage." Never manipulative phrasing. |
| REQ-HOM-07 | M | For Premium users no ad container is laid out at all; the layout collapses without a gap. |

### 7.4 Cleanup categories

| ID | P | Requirement |
|---|---|---|
| REQ-CLN-01 | M | Every category screen supports: sort, filter, grid/list toggle, multi-select, select-all, running "N items • X MB" total, preview, and the action bar (Move, Copy, Protect, Delete). |
| REQ-DUP-01 | M | Exact duplicates detected by content hash. Two-stage: size bucket, then partial hash (first+last 64 KB), then full hash only on collision. |
| REQ-DUP-02 | M | Group display: number of copies, oldest copy marked "Original", total size, potential saving. |
| REQ-DUP-03 | M | Never pre-select everything. The app may pre-select non-original copies inside an exact-hash group, but confirmation is still required. |
| REQ-DUP-04 | M | Exact duplicates and visually similar photos are separate features and must never be merged in the UI. |
| REQ-VID-01 | M | Large-video filters: 50 MB+, 100 MB+, 250 MB+, 500 MB+, 1 GB+. Sort by size, date, duration. Row shows thumbnail, `05:42 • 624 MB`. |
| REQ-SCR-01 | M | Screenshots identified by folder bucket and dimension heuristics. Date filters: today, 7d, 30d, 6m, 1y+. |
| REQ-OLD-01 | M | Old-media filters: 3m, 6m, 1y, 2y, 3y+, sub-grouped by media type, with total recoverable size. |
| REQ-SIM-01 | S | Perceptual similarity grouping. Operates on decoded thumbnails, never repeated full-res decodes. |
| REQ-SIM-02 | S | Suggested-best-shot scored on sharpness, resolution, exposure. Labelled "Suggested", never "Safe to delete". |
| REQ-BLR-01 | S | Blur detection with two confidence tiers (Very blurry / Possibly blurry). Shallow depth of field and intentional motion must not be flagged below high confidence. |
| REQ-MEM-01 | C | Meme/greeting classification via on-device ML Kit OCR keyword matching plus dimension heuristics. Labels must read "Likely meme" / "Likely greeting". |
| REQ-REP-01 | C | Repeated media by content similarity. Terminology is "Repeated Media". Never claim forward counts — that metadata is not available to us (P-03). |

### 7.5 Actions

| ID | P | Requirement |
|---|---|---|
| REQ-ACT-01 | M | Delete routes through `MediaStore.createTrashRequest` on Android 11+, `createDeleteRequest` otherwise, batching URIs into one system dialog. |
| REQ-ACT-02 | M | Confirmation sheet before any delete: item count, total size, and destination (trash vs permanent). |
| REQ-ACT-03 | M | Move and Copy to a user-chosen destination. Verify the write succeeded and the bytes match before mutating local DB state or removing the source. |
| REQ-ACT-04 | M | Handle destination filename collision, permission loss mid-operation, storage unavailable, source already deleted, and partial batch failure with a per-file result summary. |
| REQ-ACT-05 | M | Protect / Keep-forever flag. Protected items are excluded from all cleanup suggestions and require explicit unprotect before deletion. |
| REQ-ACT-06 | M | Archive = move into a real user-visible folder (`Media Archive/<year>/<type>`). No proprietary container (P-08). |
| REQ-ACT-07 | M | Cleanup success screen: GB recovered, files reviewed, removed, moved. No interstitial covering this screen. |
| REQ-ACT-08 | S | Swipe Clean: left delete, right keep, up archive, tap preview. Undo always available. Gestures explained before first use and remappable in Settings. No ads inside the swipe sequence (P-06). |
| REQ-ACT-09 | S | Video compression showing original size, estimated output, quality profile, live progress, cancellable. Original is never removed until output is validated **and** the user chose replacement. |

### 7.6 Recycle Bin

| ID | P | Requirement |
|---|---|---|
| REQ-BIN-01 | M | Bin lists MediaStore-trashed items grouped Today / Yesterday / This week / Older, with thumbnail, original location, size, deletion date. |
| REQ-BIN-02 | M | Restore and permanent-delete, single and multi-select. |
| REQ-BIN-03 | M | Restore must never require an ad, a purchase, or a network connection (P-05). |
| REQ-BIN-04 | M | On Android 10 and below, where no trash API exists, warn clearly before deletion that it is permanent. Do not fake a bin. |
| REQ-BIN-05 | M | Show the system retention period honestly. Do not promise a duration we do not control. |

### 7.7 Organize

| ID | P | Requirement |
|---|---|---|
| REQ-ORG-01 | M | Organize tab: Protected, Archive, Recently Added, Largest Media. |
| REQ-ORG-02 | C | Smart Collections (Receipts, Tickets, Bills, Travel, Work) referencing files, never duplicating them. |
| REQ-ORG-03 | C | Local search across filename, metadata and on-device OCR text. Raw search text is never logged remotely. |
| REQ-ORG-04 | S | Document organizer, gated behind the optional All Files Access flow (§5.2). |

### 7.8 Analytics and growth

| ID | P | Requirement |
|---|---|---|
| REQ-ANL-01 | S | Local snapshot table: date, total size, size by type, duplicate size, potential cleanup, space recovered. |
| REQ-ANL-02 | S | **Backfill history at first launch** by bucketing every indexed file by its `date_added`. This solves the cold-start problem — the growth chart is meaningful on day one rather than after 30 days. |
| REQ-ANL-03 | S | Charts for 7d / 30d / 6m / all-time, plus largest contributing media type. |
| REQ-ANL-04 | M | All figures computed from stored data. No estimates presented as measurements (P-03). |

### 7.9 Backup

| ID | P | Requirement |
|---|---|---|
| REQ-BAK-01 | C | User-initiated Google Drive backup using the **`drive.file` scope only** — it is non-sensitive and avoids OAuth restricted-scope verification. Never request the full `drive` scope. |
| REQ-BAK-02 | C | Show items, total size, live progress, completed, failed, retry. |
| REQ-BAK-03 | C | Never delete local originals after upload. Post-backup CTA reads "Review originals", not "Delete originals". |

### 7.10 Settings and system

| ID | P | Requirement |
|---|---|---|
| REQ-SET-01 | M | Grouped settings: Scanning, Cleanup, Appearance, Privacy, Premium, Support, Legal, About. No single flat list. |
| REQ-SET-02 | M | Light, Dark and System themes, all first-class. Dark is designed, not inverted. |
| REQ-SET-03 | M | Accessibility: dynamic type, ≥ 4.5:1 contrast, semantic labels, ≥ 48 dp targets. Cleanup confidence is never signalled by colour alone. |
| REQ-SET-04 | S | Scheduled scan: daily / every 3 days / weekly, charging-only option. Scans detect only. Never auto-delete (P-02). |
| REQ-SET-05 | M | Notification categories individually controllable. Conservative defaults. |
| REQ-SET-06 | M | Privacy page explaining on-device processing in plain language, plus "clear analysis history". |

---

## 8. Deterministic formulas

P-03 forbids invented scores. These are the actual definitions.

### 8.1 Media Health score

```
duplicate_ratio   = duplicate_bytes      / total_bytes
large_video_ratio = bytes_in_videos_over_100MB / total_bytes
old_ratio         = bytes_older_than_1y  / total_bytes
clutter_ratio     = (screenshot + blurry + likely_greeting bytes) / total_bytes

score = 100
      - min(30, duplicate_ratio   * 100)
      - min(25, large_video_ratio * 60)
      - min(25, old_ratio         * 50)
      - min(20, clutter_ratio     * 80)

score = clamp(score, 0, 100)
```

Component labels: ratio < 0.05 → Good, < 0.15 → Moderate, ≥ 0.15 → High.
Categories not yet implemented contribute 0 and their weight is redistributed proportionally. The breakdown sheet must show these inputs.

### 8.2 Quick Cleanup session estimate

```
review_seconds_per_item = 2.0  (grouped duplicates: 4.0 per group)
session_items = floor(target_seconds / review_seconds_per_item)
```

Items are selected highest recoverable-bytes-per-second first. A "2-minute review" is a genuine workload estimate, never an artificial feature limit.

### 8.3 Potential recoverable space

```
recoverable = duplicate_copy_bytes
            + similar_group_non_best_bytes   (v2)
            + blurry_high_confidence_bytes   (v2)
            + estimated_compression_savings  (v2, labelled "estimated")

Protected items are always excluded.
Each file is counted exactly once, using its highest-confidence category.
```

Double-counting a file across categories is a ship blocker.

---

## 9. Design direction

Closer to a premium finance or productivity app than a typical Android cleaner.

**Avoid:** neon graphics, cartoon brooms, gradient overload, giant BOOST buttons, red-alert dashboards, fake speedometers, bright green everywhere, animation for its own sake.

**Use:** generous whitespace, precise typography, subtle elevation, restrained rounded cards, soft borders, real data visualisation, consistent iconography, skeleton loaders.

**Visual hierarchy:** (1) storage used and recoverable, (2) categories and recommendations, (3) analytics and history.

**Navigation:** five bottom-nav destinations — Home, Clean, Organize, Bin, Settings. Search reachable from Home and Organize. Navigation state survives tab switches; back from a detail screen returns to its origin.

**Empty state example:** "No duplicates found. Your library looks clean. We'll check again during the next scan."
**Error state example:** "We couldn't access this folder. Update media permissions to continue scanning." Never surface a raw exception.

Full token values (type scale, radii, spacing, elevation, colour) live in the design system, not in this PRD. The single binding rule here: no arbitrary hardcoded sizes in widgets.

---

## 10. Privacy and data handling

Analytics may record product events only: `app_open`, `scan_started`, `scan_completed`, `category_opened`, `cleanup_completed`, `bytes_recovered`, `move_completed`, `bin_restore`, `premium_view`, `purchase_completed`, `ad_impression`.

**Never transmitted:** filenames, document names, OCR text, thumbnails, file paths, contact or group identifiers, extracted payment or receipt text, raw search queries.

Compliance deliverables before submission: privacy policy URL, Play Data Safety form, advertising ID declaration, India DPDP Act notice and consent copy.

---

## 11. Monetisation

### 11.1 Model
One-time lifetime purchase. No subscription in v1.

### 11.2 Free tier
All scan categories, all cleanup actions, move, copy, archive, protect, swipe clean, recycle bin, dashboard, foreground scanning. Roughly 95% of functionality.

### 11.3 Premium — revised

The original "30-day bin" benefit is **removed**: §5.3 establishes that retention is OS-controlled, so selling it would be selling something we cannot deliver.

| Benefit | Deliverable? |
|---|---|
| Completely ad-free — no native, no interstitial, no rewarded prompt, no placeholder | Yes, trivially |
| Background and scheduled scanning (free tier scans in foreground) | Yes, via WorkManager |
| Advanced analytics — 6-month and all-time trends (free gets 30 days) | Yes |
| Unlimited custom collections (free gets 3) | Yes, v3 |

"Priority processing" is dropped as a stated benefit. It was unmeasurable and Android background limits make it an unreliable promise, which invites refunds and one-star reviews.

### 11.4 Pricing
Introductory ₹299 lifetime → primary ₹399 → experiment ₹499. Ceiling ₹599–699 once mature. Local Play pricing.

### 11.5 Revenue sanity check

Run this model before committing to the free-heavy tier. At 100,000 installs, 12% D30 retention (12,000 MAU), ₹0.45 ARPDAU and 1% lifetime conversion at ₹399:

```
Ad revenue   ≈ 12,000 × ₹0.45 × 30   ≈ ₹162,000 / month
Premium      ≈ 100,000 × 1% × ₹399   ≈ ₹399,000 one-time
```

If this does not cover costs, the lever to pull is **install volume and retention**, not clawing features back from free. The free-heavy stance is a deliberate differentiator and reversing it undermines §1.2.

---

## 12. Advertising rules

| ID | Requirement |
|---|---|
| REQ-ADS-01 | Single centralised `AdManager`. Ad unit IDs never appear in widget code. |
| REQ-ADS-02 | Formats: native, rewarded, very limited interstitial. No app-open ad in v1. |
| REQ-ADS-03 | Home: at most one native card, placed after the core storage section and before secondary analytics. |
| REQ-ADS-04 | Lists: native placement only after ≥ 10–12 real content rows, then a substantial cooldown. Never inside an image-selection grid where it could be mistaken for the user's media. |
| REQ-ADS-05 | **Never** beside Delete, Restore or Confirm, inside swipe actions, on permission screens, or anywhere in the Bin restore flow. |
| REQ-ADS-06 | Interstitial only at a genuine break (post-scan summary, post-cleanup session). Max 1 per long session, with a time cooldown. Never at startup, on exit, per-category, per-delete, before a confirmation, or back-to-back with another ad. |
| REQ-ADS-07 | Rewarded ads are strictly optional and may only grant a temporary ad-free period. Never grant access to the user's own file, bin restore, or any cleanup category. |
| REQ-ADS-08 | Ad failure must never block app functionality. Layout collapses cleanly. |
| REQ-ADS-09 | Remote-configurable: `ads_enabled`, per-format toggles, `interstitial_session_cap`, `interstitial_cooldown_minutes`, `native_min_content_items`, `reward_ad_free_duration`, plus an emergency kill switch. |

Provider: AdMob as the control layer with AdMob Mediation. Meta Audience Network as an additional bidding source. Do not build custom mediation logic on top of a platform that already mediates.

---

## 13. Release quality gate

Ship blockers, all of them:

no debug premium unlock · no test ad units · no test purchase flow · no hardcoded secrets · no dev banners · no fake or placeholder data · no dead screens · no infinite loading · no duplicated concurrent scans · no blank thumbnails · no stale counts · no incorrect recovered-space figures · no destructive action without confirmation · no ad on a destructive screen · no crash when permission is revoked mid-session · no crash when a file is deleted externally · no unjustified permission in the manifest

Failure cases that must be explicitly tested: permission revoked while running, file deleted externally, storage unavailable, low storage, corrupt image, corrupt video, zero-byte file, 4 GB video, interrupted compression, interrupted move, process killed mid-scan, device restart, app upgrade with existing DB, purchase restored, network unavailable, Firebase unavailable, ad request failure.

---

## 14. Decisions log (resolved 2026-09-17)

All decisions were open at PRD v2.0 draft and resolved before Phase 0.

| # | Decision | Resolution |
|---|---|---|
| 1 | Final brand name and Play title | **WappTidy** / `WappTidy — Media Cleaner & Organizer`. Legal clearance check required before store submission. |
| 2 | MediaStore-only delete UX — system batch dialog on every delete, cannot be suppressed | **Accepted.** Product is satisfied with the OS-native confirmation dialog. |
| 3 | Whether to pursue All Files Access declaration for v2 Documents | **Deferred. Not pursuing.** Documents feature is not in scope for v2 planning at this time. REQ-ORG-04 remains a Could, no AFA declaration will be made. |
| 4 | Build vs licence for perceptual hashing and blur scoring | **License.** Do not build. Evaluate suitable on-device library (e.g. pHash via ML Kit custom model or equivalent) when v2 begins. REQ-SIM-01 and REQ-BLR-01 unblocked. |
| 5 | Premium tier compelling enough to convert at ≥ 0.8% | **Accepted as-is.** Revisit after real user data; lever is install volume and retention, not feature clawback (PRD §11.5). |

---

## 15. Appendix — what was cut and why

| Removed | Reason |
|---|---|
| "30-day Recycle Bin" Premium benefit | Retention is OS-controlled (§5.3). Unsellable. |
| "Priority processing" Premium benefit | Unmeasurable, unreliable under Android background limits. |
| "Forwarded 37 times" style counts | That metadata is not exposed to third-party apps (P-03). |
| Documents in v1 | Requires All Files Access (§5.2). Deferred with an explicit path back. |
| Face grouping | Scope, privacy exposure, and Play sensitivity. |
| Pixel values, radii and type scale | Belong in the design system, not the PRD. |
| 33-phase linear plan | Replaced by v1/v2/v3 scope tiers plus the phase plan in `DEV_PROMPT.md`. |
