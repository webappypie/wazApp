# Release Checklist

## Code
- [ ] Baseline/final audits complete; no fake production flows.
- [ ] Analyzer/tests pass or exceptions documented.
- [ ] Migrations tested against existing user data.
- [ ] No unhandled async errors or UI-thread media processing.

## Android
- [ ] ID `com.webappypie.wazapp` verified.
- [ ] SDK/permissions reviewed for current Play policy.
- [ ] Supported status access tested across target OS/device range.
- [ ] Release build uses release signing, not debug key.
- [ ] AAB generated and install/update tested.

## iOS
- [ ] Bundle `com.webappypie.wazapp.ios` verified.
- [ ] Photos/Files import and share/export tested.
- [ ] No false private WhatsApp-folder claims.
- [ ] Usage descriptions, signing, archive/TestFlight build and privacy disclosures verified.

## WAPCentral/Firebase
- [ ] Actual guide read and followed.
- [ ] Config files correctly placed; privileged secrets protected.
- [ ] Test mode/offline behaviour verified; no media uploads.
- [ ] Notification opt-in/denial and premium ad suppression verified.

## Monetization and product
- [ ] Real product ID supplied; purchase/restore/failure/revocation tested in sandbox.
- [ ] Brand/trademark/domain/store-name risk checked.
- [ ] Privacy policy/data disclosures match actual behaviour.
- [ ] Real final-build screenshots used.
- [ ] All P0/P1 verified or explicitly owner-approved as deferred.
