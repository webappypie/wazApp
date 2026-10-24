# Testing Strategy

## Baseline
Run and record existing checks before modifications. Do not rely on old reports.

## Automated tests
- Unit: use cases, filters, sorting, duplicate heuristics, storage calculations, permission-state mapping and entitlement logic.
- UI/widget: loading/empty/error states, selection, search/filter, editor controls and confirmations.
- Integration: import → index → view → favourite → edit/export → share; Android folder access and iOS picker/share where testable.
- Platform: denied/revoked permissions, lifecycle, orientation and background cancellation.
- Media: valid/corrupt/large/unsupported files, output validation, trim bounds and Hindi rendering.
- Billing: success/cancel/pending/failure/restore/revocation in sandbox.
- WAPCentral: valid/empty config, timeout, malformed config, offline, test mode and premium ad suppression.
- Database: migrations, missing files, stale records and interrupted writes.

## Manual device tests
Record exact OS/model/build/permissions and media details. Do not claim physical testing when only emulator/simulator was used.

## Performance and release
Measure cold start, scan throughput, scrolling, memory, thumbnail and export time. Require passing relevant analyzers/tests, debug/release builds, non-debug release signing, privacy and permission review, WAPCentral test-mode validation and evidence in `docs/audit/RELEASE_EVIDENCE.md`.
