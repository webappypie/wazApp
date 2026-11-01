# WAPCentral Integration Contract

## Source of truth
Owner says the WAPCentral guide is in the project root. Locate the actual filename (possibly `WAPCentral_App_Integration_Guide.md`) and read it fully before implementation. Do not invent SDK classes, endpoints, config keys, event names, app IDs or platform setup.

## Integration areas
Centrally managed notifications/notification centre, ad providers/placements, cross-promotions, app registration/config, consent/privacy, test mode and offline/cache behaviour — only where the guide documents them.

## Workflow
1. Record guide filename/version.
2. Extract Android/iOS setup, dependencies, initialization order, IDs/config keys, callbacks and limitations.
3. Inspect Firebase files and existing integration code.
4. Map each guide requirement to code and test status.
5. Follow exact documented setup.
6. Use test ads in development; never click live ads.
7. Premium suppresses relevant ads only after confirmed entitlement.
8. Core media flows keep working offline.
9. No app-owned server and no user-media uploads.
10. Missing capabilities are questions/blockers, not an excuse to guess.

## Firebase
Config presence does not require every Firebase service. Use only services required by code/guide. Validate file placement and app/project IDs without printing secrets. Never commit service-account private keys, signing keys, tokens or admin credentials.

## Architecture and validation
Keep a single integration adapter/service boundary, explicit init/error state, safe no-content/offline fallback, documented placement IDs and premium suppression tests. Test offline, malformed/missing config, test mode, real promotion response, notification opt-in/denial/token refresh and no-media-upload guarantee.

## WazApp implementation (updated)
The guide is `WAPCentral_WazApp_Integration_Guide.md`. The four SDKs are path packages in the sibling `../WAPCentral/sdks/` checkout. Code lives in `lib/integrations/wapcentral/` (`ads/`, `notifications/`, `promo/`, `wap_startup.dart`, plus the original service-control gate). Keyed features need `--dart-define-from-file=dart_defines.json` (see `dart_defines.example.json`); without the key they are off and local features are unaffected. Placements: `home_native`, `saved_banner`; never in Private Folder, viewer, editors, permission setup, Settings or next to destructive actions. Verification status and blockers: `docs/audit/WAPCENTRAL_INTEGRATION_STATUS.md`.
