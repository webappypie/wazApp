# WazApp — Master Product Requirements Document

**Tagline:** Save. Style. Share.  
**Android ID:** `com.webappypie.wazapp`  
**iOS bundle:** `com.webappypie.wazapp.ios`

## 1. Vision
A polished, privacy-conscious utility to save status media that the user is permitted and technically able to access, manage it locally, make lightweight photo/video edits, create text status images, and share finished media through supported platform handoff.

## 2. Goals
- Dependable, permission-compliant status discovery/saving.
- Cohesive local media library and quick editing tools.
- Premium UI with thoughtful empty/loading/error states.
- Offline-first core functionality.
- Documented WAPCentral integration for notifications, ads and promotions.
- Remove fake/stubbed features and verify end-to-end behaviour.
- Implement all agreed P0/P1 features for initial release unless owner explicitly approves a deferral.

## 3. Non-goals
No social feed, chat service, mandatory account, app-owned media server, silent uploads, cloud backup, cloud AI, permission bypasses, or automatic deletion. Never promise iOS access to WhatsApp's private status storage or imply official WhatsApp/Meta affiliation.

## 4. Priority
- **P0:** startup/crash/data safety, permissions, core saver/import, local library/viewer, privacy, platform compliance.
- **P1:** photo editor, video editor, text status maker, private folder, storage manager, WAPCentral notifications/ads/promotions, one-time Remove Ads, accessibility and release quality.
- **P2:** enhancements not required to ship the agreed first release.

## 5. Functional requirements

### Onboarding and permissions — P0
Explain the app before asking permissions. Ask contextually, handle denied/limited/revoked access, provide settings recovery where supported, and never claim permission is granted unless the OS confirms it.

### Android status saver — P0
Discover status media only through supported, user-authorized paths. Validate actual WhatsApp and WhatsApp Business behaviour separately across supported Android versions/devices. Prefer SAF/user-granted folder access where suitable and MediaStore only for legitimately exposed media. No hidden APIs, root or bypasses. Support photos/videos, accurate thumbnails/metadata, preview, single/multi-save, progress, cancellation, retry, partial failure, incremental rescan and safe duplicate handling. A hard-coded path alone is not proof of compatibility.

### iOS media acquisition — P0
Use Photos/Files pickers for user-selected media, maintain a local library, export via appropriate Photos permission or share sheet, and hand off sharing to WhatsApp with the user completing publication. Never display a fake feed of WhatsApp statuses.

### Local library and viewer — P0
All/photos/videos/recent/favourites, search and meaningful filters, responsive grid/list if implemented, preview, share, favourite, delete, multi-select, bulk actions with confirmation, progress and recoverable error states. Handle missing/corrupt files and stale metadata.

### Photo editor — P1
Crop, rotate, flip, brightness, contrast, saturation, supported filters and sharpness only if truly supported; text with font/size/colour/alignment and supported outline/shadow; basic stickers/emoji; undo/redo/reset. Preserve original, export a new file, validate it, and report real progress/errors.

### Video editor — P1
Trim, crop, mute and text overlays/adjustments only where supported. Offer only real encoder-supported quality options. Background encoding, progress, cancellation/retry and output validation (exists, playable, duration, dimensions, audio state). Preserve original by default.

### Quick Status Maker — P1
Create actual image statuses with background/gradient/quote templates, Hindi and English, around 20–30 genuinely distinct presets, text controls, line wrapping, preview and save/share. Test Devanagari shaping and font fallback.

### Private Folder — P1
Move selected items to app-private storage and optionally gate access with device authentication. Keep items out of normal library/search where appropriate. Explain uninstall/data-loss implications. App-private storage/authentication alone is not encryption; never make false encryption claims.

### Storage Manager — P1
Accurately report WazApp-managed storage, identify large files and probable duplicates with explainable criteria, and allow confirmed bulk deletion. Never auto-delete or claim access to files outside permission scope.

### WAPCentral notifications — P1
Follow the actual root guide. Implement only documented notification/notification-centre capabilities. Handle permission opt-in/denial, token refresh, opt-out and offline states as the guide specifies. No parallel app-owned notification backend.

### Ads and promotions — P1
Use WAPCentral-controlled config/placements/providers as documented. Test mode in development. Ads must not masquerade as app controls or block core flows. Premium suppresses applicable ads after verified entitlement. Offline/invalid config must not break core features; use safe no-content state unless guide specifies valid cache. No fake campaign/impression data.

### One-time Remove Ads — P1
Use platform-compliant billing and an owner-configured product ID. Implement purchase, pending/cancel/failure, restore and revoked/refunded entitlement handling. Never hard-code premium or report success before store confirmation. If product IDs are missing, document the exact setup blocker.

### Firebase
Presence of config files does not mean all Firebase services are needed. Inspect and use only services required by current code or WAPCentral guide. No media uploads or new backend. Keep privileged credentials out of source control/logs.

## 6. UX and quality
Original green/teal status-inspired identity, not copied official WhatsApp assets. Clear hierarchy, consistent navigation, accessible touch targets/contrast, large-text resilience, responsive layouts, useful loading/empty/error states, no UI-thread media work, bounded memory and validated exports.

## 7. Privacy
Core media remains on-device; user explicitly initiates import/export/share/delete; no silent uploads/cloud backup/cloud AI. See `SECURITY_PRIVACY.md`.

## 8. Acceptance criteria
Feature is complete only when end-to-end behaviour is evidenced, success/failure/permission/offline paths are tested, no fake production data remains, relevant automated tests pass, data integrity/privacy are reviewed, and evidence is logged under `docs/audit/RELEASE_EVIDENCE.md`.
