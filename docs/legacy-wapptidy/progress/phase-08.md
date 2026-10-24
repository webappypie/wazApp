# Phase 08 — Settings, Ads, Premium, Polish

**Status:** Done  
**Completed:** 2026-09-17  
**Requirements:** REQ-SET-01 to REQ-SET-03, REQ-SET-05, REQ-SET-06; REQ-ADS-01 to REQ-ADS-09; PRD §11.3  
**Goal:** Grouped Settings screens, genuine Theme switching (Light/Dark/System), Notification controls, Privacy explanation & analysis history purge, centralized `AdManager` enforcing all advertising policies, offline-cached in-app purchases, and Premium entitlement wiring.

---

## What was built

### 1. Grouped Settings Architecture (REQ-SET-01 .. 06)
- **Domain State (`lib/features/settings/domain/settings_state.dart`):**
  - `AppThemePreference`: `system`, `light`, `dark`.
  - `ScanFrequency`: `daily`, `every3Days`, `weekly`, `off`.
  - `DuplicateKeepRule`: `keepOldest` (original), `keepNewest`.
  - Notification toggles: `notifyScanReminders`, `notifyStorageAlerts`, `notifyWeeklyTips`.
- **Repository (`lib/features/settings/data/settings_repository.dart`):**
  - Backed by `SharedPreferences` for fast local preference persistence.
  - `clearAnalysisHistory()`: Purges cached index from `AppDatabase` and resets scan state without deleting files from disk (`REQ-SET-06`).
- **Controller & Theme Mode (`lib/features/settings/presentation/settings_controller.dart`):**
  - Riverpod `Notifier<SettingsState>` managing reactive updates.
  - `appThemeModeProvider` connected to `MaterialApp.router` in `app.dart` to apply theme changes dynamically without restart.
- **Grouped Screen (`lib/features/settings/presentation/settings_screen.dart`):**
  - 8 distinct sections per `REQ-SET-01`:
    1. **Appearance (REQ-SET-02):** Segmented button selecting System Default, Light, or Dark theme.
    2. **Scanning (REQ-SET-04):** Auto-scan frequency dropdown + charging-only toggle. Explains that scans detect only and never auto-delete (`P-02`).
    3. **Cleanup Preferences:** Duplicate retention rule selector + confirmation prompt toggle.
    4. **Notifications (REQ-SET-05):** Storage alerts (default ON), scan reminders (default OFF), weekly tips (default OFF).
    5. **Privacy & Security (REQ-SET-06):** Clear badge highlighting 100% On-Device Processing + "Clear Analysis History" action guarded by `ConfirmationSheet`.
    6. **Premium (PRD §11):** Shows active lifetime status or "Upgrade to Lifetime Premium" and "Restore Purchases".
    7. **Support:** FAQ dialog + support contact.
    8. **About & Legal:** Privacy policy, Terms of Service, Open source licenses, App build version.

### 2. Advertising Rules & Centralized AdManager (REQ-ADS-01 .. 09)
- **`AdManager` (`lib/core/services/ads/ad_manager.dart`):**
  - **REQ-ADS-01:** Single entry point for all advertising logic; ad unit IDs never appear in widget code.
  - **REQ-ADS-02:** Supports native, rewarded, and limited interstitial. No app-open ads.
  - **REQ-ADS-03:** Home section permitted at most 1 native card.
  - **REQ-ADS-04:** List placement blocked unless real content items above $\ge 10$.
  - **REQ-ADS-05:** Forbidden placements throw `ForbiddenAdPlacementException` if an ad is requested on destructive screens, permission screens, swipe actions, or Bin restore flow.
  - **REQ-ADS-06:** Interstitials allowed only at genuine breaks (post-scan summary, post-cleanup session); capped at max 1 per session with time cooldown.
  - **REQ-ADS-07:** Rewarded ads strictly grant temporary ad-free period; never gate user media, bin restore, or cleanup categories.
  - **REQ-ADS-08:** Fail-safe: ad failures never throw or block functionality; layout collapses cleanly to `SizedBox.shrink()`.
  - **REQ-ADS-09:** Configured via `RemoteConfigService` with master switch, format switches, cooldown settings, and emergency kill switch.
- **`NativeAdContainer` (`lib/core/widgets/monetisation_widgets.dart`):**
  - Observes `adManagerProvider` and `isPremiumProvider`.
  - Automatically collapses to `SizedBox.shrink()` when Premium, ads disabled, or item count threshold not met.

### 3. In-App Purchase Service & Offline Caching (PRD §11, P-10)
- **`AppPurchaseService` (`lib/core/services/purchases/app_purchase_service.dart`):**
  - Manages `free`, `pending`, and `premium` lifecycle states.
  - Persistent offline cache in `SharedPreferences`: users keep their Premium entitlement even when launching offline (`P-10`).
  - Supports `purchase()` and `restorePurchases()`.
  - `isPremiumProvider` reacts immediately to purchase updates across the widget tree.

---

## REQ-ADS-05 Forbidden Placement Audit

Every screen was manually checked against the REQ-ADS-05 forbidden-placement list:
- `SplashScreen`: No ads.
- `OnboardingScreen` (Permission screens): **Zero ads** (Strictly compliant).
- `HomeScreen`: At most one native card between storage overview and analytics. Collapses cleanly when Premium (`REQ-HOM-07`).
- `CleanScreen`: Category overview cards. No ads.
- `CategoryScreen` / Category detail screens: Multi-select media items. No ads beside Delete or in action bar (`REQ-ADS-05`).
- `ConfirmationSheet`: Destructive confirmation dialog. **Zero ads** (Strictly compliant).
- `BinScreen` & Restore flow: **Zero ads** (Non-negotiable `P-05`, strictly compliant).
- `CleanupSuccessScreen`: Recovery summary screen. **Zero ads / No interstitial covering it** (`REQ-ACT-07`).
- `SettingsScreen`: Configuration & Privacy. No ads.

---

## Verification & Tests

- **AdManager Test Suite (`test/core/services/ad_manager_test.dart`):**
  - REQ-ADS-01: Centralized entry point.
  - REQ-ADS-03: Home native ad permitted.
  - REQ-ADS-04: List native ad blocked when items $< 10$, allowed when $\ge 10$.
  - REQ-ADS-05: Forbidden placements throw `ForbiddenAdPlacementException`.
  - REQ-ADS-06: Interstitial session cap and cooldown.
  - REQ-ADS-07: Rewarded ad grants temporary ad-free period only.
  - REQ-ADS-08: Ad failure returns non-blocking status.
  - REQ-ADS-09: Emergency kill switch and format toggles immediately suppress ads.
- **Purchase Service Test Suite (`test/core/services/purchase_service_test.dart`):**
  - Initial free tier default.
  - Purchase upgrades to premium and notifies stream.
  - Offline cache persists across app restarts (`P-10`).
  - `isPremiumProvider` responds immediately.
- **Settings Test Suite (`test/features/settings/settings_test.dart`):**
  - REQ-SET-01: Renders all 8 grouped sections and headers.
  - REQ-SET-02: Theme switching to Dark and Light updates `appThemeModeProvider`.
  - REQ-SET-05: Notification toggles with conservative defaults.
  - REQ-SET-06: Privacy text explaining on-device processing + "Clear Analysis History" with ConfirmationSheet.
  - Premium section displays Upgrade and Restore for free users, and active badge for Premium users.
- **Full Test Suite:**
  - `flutter test`: **128 / 128 tests passed** (100% passing across the entire project).
  - `flutter analyze`: **0 issues found** (clean static analysis).
