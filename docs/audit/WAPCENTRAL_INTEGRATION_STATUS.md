# WAPCentral integration - status, blockers and owner actions

Source of truth: `WAPCentral_WazApp_Integration_Guide.md` (Document Version 2.0 / WAPCentral 1.0, generated 24 Oct 2026; git-ignored because it contains the platform key).
Rule followed in Phase 5: implement only what the guide documents completely; **do not invent** class names, response shapes, endpoints or IDs. Everything else is listed below as a blocker with the exact thing needed.

## 1. Implemented (guide section 9: Remote App Service Control)

| Guide requirement | Implementation | Evidence |
|---|---|---|
| `GET /api/platform/v1/apps/{appId}/service-status` with `X-App-Id` (+ `X-App-Key` standard auth, "public or standard") | `lib/integrations/wapcentral/` (`WapCentralConfig`, `ServiceControlClient`) using `package:http`; key sent only when the build provides `--dart-define=WAP_APP_KEY` (never in source) | `service_control_client_test` (14), opt-in live test |
| Response `{success, data{enabled,title,message,buttonText,destinationUrl}}`; defaults when fields missing | `ServiceStatus.fromData` with the guide's defaults (`Service Notice`, `Service is currently unavailable.`, `Learn More`, `https://webappypie.com`) | tests incl. the real shape observed live (only `enabled` + `updatedAt{_seconds,_nanoseconds}`) |
| Cold start check | `ServiceGate` asks right after the first frame (does not delay launch: the app is local-first) | `service_gate_test` |
| Foreground/resume re-check | lifecycle `resumed` triggers a check; overlapping checks collapse | tests |
| Blocking, non-dismissible notice with title/message/button; app inert underneath; Android back cannot dismiss it | full-app overlay (`MaterialApp.builder`) + `WazApp.didPopRoute` consumes back while blocked | widget tests (real `WazApp`) |
| Button opens `destinationUrl` in the external browser | `url_launcher`, `LaunchMode.externalApplication`; only http/https links are accepted (an `intent:`/`file:`/`javascript:` value is ignored) | tests |
| Fail open on timeout, offline, DNS, HTTP 5xx/4xx/3xx, bad JSON, missing/invalid config | every failure => `enabled: true`, logged as a one-line warning (reason only) | tests |
| Auto-dismiss on restoration | next check returning `enabled: true` (or failing open) removes the notice | tests |
| Never log/embed the key (guide sections 2, 12) | key absent from source, `toString()` redacted, logs carry no URL/headers/body | `the key never reaches the logs` test |
| Permissions minimal | `INTERNET` added (only use: this check) + `https` VIEW query for `url_launcher` on Android 11+ | manifest |
| Privacy disclosure | Settings > Privacy > "Service check" states what is sent | UI text |

**Live verification (2026-10-25, read-only GET, no key):** `https://wapcentral.webappypie.com/api/platform/v1/apps/app_1792836068231/service-status` answered `200` `{"success":true,"appId":"app_1792836068231","service":"service_control","version":"v1","data":{"enabled":true,"updatedAt":{"_seconds":...,"_nanoseconds":...}},"timestamp":"..."}`. The production client parsed it (`source: server, enabled: true`). So the endpoint is public as the guide says; differences from the guide's example payload: `updatedAt` is a Firestore-style object (not an ISO string) and the text fields are absent while the service is enabled - the client tolerates both.

### Deliberate deviations from the guide's reference snippet (and why)
1. **No default key in source.** The snippet uses `String.fromEnvironment('WAP_APP_KEY', defaultValue: '<the key>')`, which embeds the key in every build and in git; guide section 2 rule 1 forbids that. We pass no default.
2. **Not blocking launch on the check.** The snippet awaits the check before `runApp` and uses `navigatorKey.currentContext!` (null at that point). We start the check after the first frame so offline/slow networks never delay local features (guide section 14: "Do NOT block app launch on network error"); the notice covers the app as soon as a "disabled" answer arrives (normally well under a second).
3. **Only http/https destination links** are opened.
4. **Duplicate requests collapse** (in-flight guard).

## 2. Blocked - nothing implemented (no guessing)

| Area | Guide says | What is missing / why it is blocked | Exact owner action |
|---|---|---|---|
| **B1 - WAP SDKs** (`wap_core_sdk`, `wap_ads_sdk`, `wap_notifications_sdk`, `wap_promo_sdk`) | Sections 5, 6, 11 say they are required | Not on pub.dev (`pub.dev/packages/wap_core_sdk` -> 404), not in the repo, no source/registry/docs supplied; only `WapCore.initialize`, `WapAds.initialize`, `WapNotifications.initialize` appear in a snippet, with no API reference | Provide the git URL / private pub registry / local path (and API docs, or the package README) for all four SDKs |
| **B4 - Ads config** `GET /ads/config`, `POST /ads/custom/track` | Listed in the catalog (section 7), "SDK fetches the effective configuration" | **No request/response schema** in the guide (placements, formats, caps, unit IDs, house-ad format, tracking payload); test-mode switching is "injected by WAPCentral" with no described mechanism | Provide the OpenAPI/JSON examples for both endpoints, or the SDK |
| **B4 - Notifications** `POST /notifications/devices/register`, `GET /notifications` | Catalog only | **No payload schema** (token field names, platform, device id, locale, opt-in flags), no feed item schema, read-sync mechanism, deep-link format; FCM token registration without it would be a guess | Provide request/response examples or the SDK |
| **B4 - Promotions** `wap_promo_sdk` | Section 5 says required; section 8 says external house promotions are "disabled and NOT required" | **Contradiction** + no API at all | Owner decides: promotions on or off for WazApp, and supplies the SDK/API if on |
| **Firebase / FCM** | FCM required for notifications (section 4) | Config files are in place (`android/app/google-services.json`, `ios/Runner/GoogleService-Info.plist`) but `firebase_core`/`firebase_messaging` and the google-services Gradle plugin are **deliberately not added**: a token with nowhere documented to send it would only add permissions (`POST_NOTIFICATIONS`) and data collection for no working feature | Unblocked by B1/B4 |
| **AdMob** (App ID in manifest, `google_mobile_ads`) | Section 8 | (a) Guide contradicts itself: it prescribes the **test** App ID for the manifest while listing production IDs and saying never to hardcode ad units; (b) ad-unit IDs must come from `/ads/config` (B4); (c) no consent flow (UMP/GDPR/India DPDP) is specified, and ads without a consent decision are a store-policy risk; (d) `app-ads.txt` hosting is an owner task | Confirm manifest App ID policy (test vs production per build type), supply B4, decide consent approach, publish `app-ads.txt` |
| **Remove Ads purchase / restore / revoked entitlement** | PRD P1 | **No billing product ID** (Play Console / App Store Connect) and no configured store listing; `in_app_purchase` could be added but nothing could be bought or tested in a sandbox; entitlement must never be granted without store confirmation (the earlier fake grant was removed in Phase 1) | Create the one-time product in Play Console (and App Store Connect), give the product ID(s), add licence-tester accounts |
| **Health** `GET /health` | Release checklist item "cold-start check succeeds" | Public; response shape not documented. Not needed by the app; a status-code-only probe adds a request for no user value | Optional: document the payload if a health check is wanted |
| **Key handling** | Key is printed in the guide; "AI team can implement WAPCentral authentication directly" | A key compiled into an APK is extractable by anyone, so it is **not a secret on the client**. The service-status endpoint does not need it. Once ads/notifications exist WAPCentral must enforce access server-side (package name / signature / rate limits), not rely on the key | Confirm server-side app verification; rotate the key if the guide was shared beyond the team; pass it only via `--dart-define` (CI secret) |
| **Guide hygiene** | - | The guide file with the unmasked key sits in the repo root; it is git-ignored, but any copy that was committed elsewhere would leak it | Keep it out of version control (already ignored) |

### Guide inconsistencies to resolve (carried from the Phase 0 audit)
1. Promotions: required (section 5) vs "NOT required" (section 8).
2. AdMob manifest App ID: test ID in the snippet vs production ID in the table; a manifest cannot be fetched at runtime.
3. Key as a `defaultValue` in the snippet vs "never hardcode secrets".
4. Snippet calls `showBlockingDialog(navigatorKey.currentContext!, ...)` before `runApp`.
5. Section 6 says `appKey` passed to `WapCore.initialize`/`WapAds`/`WapNotifications` with no description of what each does with it.

## 3. What a release build needs
- `--dart-define=WAP_APP_KEY=<key>` is **optional today** (service-status is public) and will be required once B1/B4 land.
- Real signing keystore (B5), production ad/billing configuration (B3/B7), privacy-policy text covering the service check, and the data-safety form entries: "app identifier + IP address sent to WAPCentral for a service-availability check; no user content".
