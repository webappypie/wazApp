# WAPCentral integration - status, evidence and blockers

Source of truth: `WAPCentral_WazApp_Integration_Guide.md` (v2.0 / WAPCentral 1.0, 24 Oct 2026; git-ignored because it contains the platform key).
Rule: implement only what the guide and the SDK sources document; no invented endpoints, no fake ads/impressions/notifications.

> **Supersedes the Phase 5 status.** Blocker "B1 - the WAP SDKs are not available" was wrong/obsolete: the four SDKs exist as path packages in the sibling checkout `D:\Mobile-App\WAPCentral\sdks\` (`wap_core_sdk`, `wap_ads_sdk`, `wap_notifications_sdk`, `wap_promo_sdk`, all `0.1.0`) and are used by the sibling app ShotNest. They are now wired in via `path:` dependencies (`../WAPCentral/sdks/...`). **A fresh clone needs that sibling checkout** (or a private registry) to build.

## 1. Build-time inputs

| Input | How | Without it |
|---|---|---|
| `WAP_APP_KEY` | `flutter run --dart-define-from-file=dart_defines.json` (git-ignored; copy `dart_defines.example.json`) or `--dart-define=WAP_APP_KEY=<key>`. Never in source. | Ads, notification feed/registration and promotions are **off** (zero-size slots, "not available" screens). Service-status check, and every media feature, still work. |
| AdMob App ID | `android/app/build.gradle.kts` `manifestPlaceholders["admobAppId"]`: Google **test** App ID for debug/profile, WazApp production App ID for `release` (the App ID cannot be fetched at runtime). | - |
| Firebase | `android/app/google-services.json` (project `wazapp-512609`, package `com.webappypie.wazapp`) + `com.google.gms.google-services` plugin 4.4.4 | FCM unavailable; app unaffected |

## 2. Implemented (code in `lib/integrations/wapcentral/`)

| Area | Implementation | Automated evidence |
|---|---|---|
| Service control (guide s9) | unchanged `ServiceControlClient` + `ServiceGate` (REST, fail-open, resume re-check) | 25 existing tests |
| Start-up (s11) | `wap_startup.dart`: runs **after the first frame** (hook in `lib/app.dart`), each module independent and guarded; resume re-checks ads config, notification permission/feed, promo | - |
| Ads (s8) | `ads/`: `wap_ads_sdk` initialised with `WapAdsOptions` (config from `GET /ads/config`), AdMob served directly by `AdMobWapProvider` (ported from ShotNest) using the ad-unit IDs WAPCentral returns; the SDK's mock AppLovin/Meta/InMobi/Unity adapters are replaced by no-fill providers; house ads only from a server `customAdFallback` campaign (https only, counted when 50% visible); Google UMP consent before the first request; non-release builds request **only Google test units**; `AdSlot` collapses to zero height on disabled/offline/no-fill; placements `home_native`, `saved_banner` | `test/integrations/ads_test.dart` (11) |
| Notifications (s10) | `notifications/`: `wap_notifications_sdk` + `WapNotificationApi` (adapter to the live response shapes), `NotificationsController` (feed, unread, optimistic read with pending-retry, foreground/tap handling), FCM token registered via `WapNotifications.registerDevice` **only while the OS permission is granted** (never prompts; `syncRegistration()` is called by the permission layer after a grant, on start and on resume); `NotificationsScreen`, `NotificationBellButton`, `NotificationPreferencesScreen` (category preferences via SDK `getPreferences/updatePreferences`, mandatory categories locked); links limited to https | `notifications_test.dart` (15) |
| Promotions (s5/s8) | `promo/`: `wap_promo_sdk` cache-first, RS256-verified (public key only), frequency-capped by the SDK; extra gate: title + safe destination (https / `market://details`); `PromoCard` renders nothing unless a valid signed campaign exists | `promo_test.dart` (5) |
| Key hygiene | key only via dart-define, `toString` redaction, SDK logging off, logs print outcomes only (never token/key/device id) | existing + new tests |
| Native config | `settings.gradle.kts`, `app/build.gradle.kts`, `AndroidManifest.xml`: google-services plugin, `POST_NOTIFICATIONS`, AdMob APPLICATION_ID + `DELAY_APP_MEASUREMENT_INIT`/optimise flags, FCM default channel | **not yet built** - see s3 |

Unit/widget results: `flutter test test/integrations` -> 56 tests green (25 service control + 31 new); `flutter analyze lib/integrations test/integrations` clean.

## 3. NOT verified (be explicit)

- **No Gradle build has been run for the new native config** (AGP 9.1.0 + google-services 4.4.4 + firebase/google_mobile_ads plugins). First debug build may need version adjustments.
- **Nothing exercised on a device**: Firebase init, UMP consent form, a real test banner/native ad render, FCM token acquisition/registration, a real push, the feed against WAPCentral.
- **Everything key-gated is untestable without `WAP_APP_KEY`**: ads config, notifications register/feed/preferences, promo fetch. Whether `/ads/config`, `/notifications` or `/promotion` accept key-less requests is unknown (the service-status endpoint is public).
- Live WAPCentral state at the time of writing is unknown (the guide says Ads = Enabled/Testing, Notifications = Enabled, Promotion enabled). Ad unit IDs for banner/native must be present in `/ads/config`; the guide's production table lists them but the client never hardcodes them.
- Promo verification key (`promo-signing-v1`) was copied from the ShotNest integration of the same platform, not re-exported from KMS for WazApp; it works only if WAPCentral signs WazApp promotions with the same key.

## 4. Blockers / owner actions

| # | Item | Needed |
|---|---|---|
| 1 | Key | Provide `WAP_APP_KEY` locally (`dart_defines.json`) to test ads/notifications/promo on the device. |
| 2 | SDK source | The SDKs are path packages outside this repo: decide whether to vendor them, publish to a private registry, or document the sibling-checkout requirement for CI/release. |
| 3 | Guide inconsistency (carried) | Section 5 requires `wap_promo_sdk`; section 8 says external house promotions are not required. Implemented as: SDK-driven first-party promotion surface that stays hidden unless the server sends a signed campaign. Confirm intent. |
| 4 | Guide inconsistency (carried) | Guide's manifest snippet shows the test App ID while listing production IDs. Implemented: test App ID for debug/profile, production App ID for release (config only; release builds not made). |
| 5 | AdMob production | `app-ads.txt` on the developer domain; AdMob account/payment approval; UMP consent message configured in the AdMob console (otherwise the consent form never appears and ads rely on defaults). |
| 6 | Remove Ads / billing | Unchanged: no billing product ID supplied; no purchase flow exists, so ads are never suppressed by a fake entitlement. |
| 7 | iOS | Not built here. Needs `GoogleService-Info.plist` (present), the AdMob iOS App ID in `Info.plist`, push capability/APNs key, and a privacy manifest review. |
| 8 | Disclosures | Privacy text/data-safety form must now cover AdMob, FCM and the WAPCentral notification/promo requests (app id, device id random UUID-like, FCM token, platform, app version). |

## Device verification with the platform key (2026-10-25, debug build, Android 13 phone)
Built with `--dart-define-from-file=dart_defines.json` (git-ignored; key never in source, docs or logcat - logcat searched for the key: 0 hits).

| Guide item | Observed |
|---|---|
| Ads config (`/ads/config`) | fetched: version `be0a91bf...`, `enabled=true`, `testMode=true`, formats banner/native/interstitial/rewarded/appOpen |
| Test mode | debug build requested Google TEST units only (log: `serving=Google TEST units`); WAPCentral also reports testing mode |
| Ad render | AdMob native test ad ("Test Ad: Google Ads") rendered on Home; Google's native ad validator overlay (debug) reported "No implementation issues found" |
| Ad placement hygiene | only Home (native) and Saved (banner); not in Private, viewer, editors, setup, settings |
| FCM / device registration | `push registration accepted: true` (server response) after Firebase init |
| Notification feed | real item from WAPCentral listed, bell showed unread badge 1 |
| Notification preferences | real categories from the server; mandatory ones locked; toggling "Feature Announcements" persisted when the screen was reopened (restored afterwards) |
| Health `GET /health` | `curl` with app headers: HTTP 200 `status: healthy` (not called from the app: no user value) |
| Service status (guide section 9) | covered earlier (live GET + tests) |
| Promotions | no campaign was returned, so nothing rendered (correct fail-quiet behaviour); a real campaign render was NOT observed |

Not verified: an actual push delivered to the device (needs a send from the WAPCentral dashboard), interstitial/rewarded/app-open formats (not used by WazApp placements), consent (UMP) form display, offline behaviour with the key, release-mode production unit IDs (never requested in debug by design).

Guide gaps still open: Crashlytics (recommended, not added), `app-ads.txt` hosting (owner), AdMob production App ID is only used in the release manifest placeholder, iOS `GADApplicationIdentifier`/Podfile setup (needs a Mac), the guide's own promotions contradiction (section 5 vs 8).

## Full-screen ad placements (2026-10-25)
Implemented in `ads/admob_provider.dart` (real Google Mobile Ads interstitial, app-open and rewarded loading behind the `FullScreenAdsApi` seam; debug/profile builds request Google's test units only) and `ads/full_screen_ads.dart` (when to show). WAPCentral still controls whether each format is on, the units and its own cooldown/caps (`wap_ads_sdk` FrequencyManager); WazApp adds conservative local rules:

| Format | Placement | Rules |
|---|---|---|
| Interstitial `interstitial_after_save` | after a status-save batch finished with at least one item really saved | every 3rd such batch; >= 4 min after any full-screen ad; never on failure/cancel, never while editing or in the Private Folder |
| App open `app_open_return` | returning to the app | >= 10 min in background (so pickers, WhatsApp, Settings and the share sheet never trigger it); at most once per 4 h; only on Home/Saved/Create/Settings; not while the WAPCentral service notice is up; not right after another ad |
| Rewarded `support_rewarded` | Settings > Support WazApp > "Watch a short ad" (visible only when WAPCentral has rewarded on) | user tap only; the reward is a thank-you, no feature is locked behind it |

Tests: `test/integrations/full_screen_ads_test.dart` (6) cover every rule above with a fake driver and clock.

Device (debug, test units, Android 13): rewarded - the test video played, the ad showed "Reward granted", closing it returned to Settings with "Thank you for supporting WazApp!". Interstitial - a request for Google's test interstitial unit was logged when the 3rd save batch finished (after accidental taps while driving the UI); the ad itself was not captured on screen, so treat the interstitial display as logged, not eyeballed. App open - covered by unit tests only (needs a 10+ minute background; not run on the device).

## Push delivery check
A dashboard send was reported, but on the device nothing arrived: no notification in the system tray, no FCM message in logcat, and the in-app feed still showed only the earlier "Test" item. Registration itself was accepted by the server (see the section above). Not confirmed: whether the send targeted this device's token/app, whether it was sent after the 07:49 registration, and whether MIUI background restrictions applied (the phone also runs Do Not Disturb). Needs a re-send with the app in the background while logcat is watched.
