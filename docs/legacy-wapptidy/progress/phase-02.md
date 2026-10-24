# Phase 02 — Onboarding and Permissions Detail

**Status:** Done  
**Completed:** 2026-09-17  
**Requirements:** REQ-ONB-01 to REQ-ONB-05

---

## What was built

### Dependencies added
- `permission_handler: ^12.0.3` — runtime permission requests for `READ_MEDIA_*`
- `shared_preferences: ^2.5.5` — onboarding-seen flag persistence

### AndroidManifest.xml permissions
Added with explicit API-level comments (no MANAGE_EXTERNAL_STORAGE — ever):
- `READ_MEDIA_IMAGES`, `READ_MEDIA_VIDEO`, `READ_MEDIA_AUDIO` (API 33+)
- `READ_MEDIA_VISUAL_USER_SELECTED` (Android 14+ partial access)
- `READ_EXTERNAL_STORAGE` with `maxSdkVersion="32"` (legacy fallback API 26–32)

### Service layer

| File | Purpose |
|---|---|
| `lib/core/services/onboarding/onboarding_service.dart` | Interface: `hasCompletedOnboarding()`, `markOnboardingComplete()` |
| `lib/core/services/onboarding/fake_onboarding_service.dart` | In-memory fake, configurable `startCompleted`, `reset()` |
| `lib/core/services/onboarding/real_onboarding_service.dart` | SharedPreferences-backed real impl |

`MediaPermissionState` enum updated: renamed `partial` → `limited` (Android 14+ selected-photos), added `restricted` (MDM/parental controls).

`onboardingServiceProvider` added to `providers.dart` — uses `RealOnboardingService` (real SharedPreferences) unlike Phase 0 services which are all fakes.

### Screens

| File | REQ | Description |
|---|---|---|
| `lib/features/onboarding/presentation/splash_screen.dart` | REQ-ONB-01 | Logo + name + tagline, 1.2–1.6s enforced via parallel Future.wait + extra delay |
| `lib/features/onboarding/presentation/onboarding_screen.dart` | REQ-ONB-02 | Exactly 3 slides, Skip always visible, animated page dots with Semantics "Step N of 3" |
| `lib/features/onboarding/presentation/permission_rationale_screen.dart` | REQ-ONB-03 | Real screen user reads BEFORE system dialog; explains each permission + privacy assurance |
| `lib/features/onboarding/presentation/permission_request_screen.dart` | REQ-ONB-04 | Triggers system dialog via `mediaAccessService.requestPermission()`; handles all 5 states |
| `lib/features/onboarding/presentation/permission_denied_screen.dart` | REQ-ONB-04 | Handles denied + permanentlyDenied; WidgetsBindingObserver detects return from Settings; never a dead end |
| `lib/core/widgets/partial_access_banner.dart` | REQ-ONB-05 | Persistent banner on every media screen when Android 14+ limited access; driven by `mediaPermissionStateProvider` |

### Router changes
- Initial location changed from `/` to `/splash`
- New route constants: `splash`, `onboarding`, `permissionRationale`, `permissionRequest`, `permissionDenied`
- All 5 permission-flow screens wired as top-level GoRoutes (outside the shell)

### Permission state machine
```
/splash
  ├─ onboarding done? → /  (home shell)
  └─ not done?        → /onboarding
                           └─ Get started / Skip → /permission-rationale
                                                      ├─ Grant access  → /permission-request
                                                      │                    ├─ granted  → markDone → /
                                                      │                    ├─ limited  → markDone → /  (+ banner)
                                                      │                    ├─ denied   → /permission-denied
                                                      │                    ├─ permDen  → /permission-denied
                                                      │                    └─ restricted → /permission-denied
                                                      └─ Not now       → /permission-denied
                                                                           ├─ Try again    → /permission-request
                                                                           ├─ Open Settings → system settings (observer re-checks)
                                                                           └─ Continue without access → markDone → /
```

### Tests (34 total, 34/34 pass)

**New in Phase 2 (`test/features/onboarding/permission_flow_test.dart`):**
- FakeOnboardingService: starts not completed, markComplete persists, startCompleted=true, reset
- Permission state handling: granted/limited complete onboarding, denied does not
- permanentlyDenied and restricted reflected correctly
- openAppSettings no-op on fake
- PartialAccessBanner: limited → should show, granted → should not show
- Provider override respected in widget tree

**Updated:**
- `test/widget_test.dart` — tests splash content without routing through go_router (avoids pending-timer assertion from 1.2s delay)

## Real-device verification checklist
These must be verified on a physical Android 14+ device before marking DoD complete:

- [ ] Fresh install → splash → onboarding 3 slides → rationale → grant → home
- [ ] Skip from slide 1 → rationale → grant → home
- [ ] Rationale "Not now" → denied screen → "Try again" → grant → home
- [ ] Grant → deny once → "Try again" → grant → home
- [ ] Deny twice → permanentlyDenied state → "Open Settings" → grant → home (via observer)
- [ ] Android 14+: "Select photos and videos" → home with partial-access banner visible
- [ ] Banner disappears immediately after upgrading to full access in Settings
- [ ] App restart after completing onboarding → goes directly to home (no splash re-run)

## Carried debt / notes
- `RealMediaAccessService` (Phase 3): must implement `requestPermission()` using `permission_handler` with `Permission.photos`, `Permission.videos`, `Permission.audio`, checking Android version for API 33+ vs legacy path. Phase 2 flow is fully tested against `FakeMediaAccessService`.
- `mediaPermissionStateProvider` is a `FutureProvider` — Phase 3 should upgrade to `StreamProvider` that re-emits on every `AppLifecycleState.resumed` event for reactive banner updates.
