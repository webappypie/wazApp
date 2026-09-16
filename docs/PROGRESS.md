# Progress — WappTidy

## Status
Current phase: 3 (Done)
Last updated: 2026-09-17

## Phase log
| Phase | Name | Status | Notes |
|---|---|---|---|
| 0 | Foundation | Done | 21/21 tests pass, flutter analyze clean, committed 8c2f93d |
| 1 | Design system | Done | 0 issues, 21/21 tests, all components + gallery |
| 2 | Onboarding & permissions | Done | 34/34 tests pass; real-device checklist in docs/progress/phase-02.md |
| 3 | Indexing engine | Done | 50/50 tests; Kotlin MediaStore querier; schema v2; incremental diff; progress UI |
| 4 | Home dashboard | Not started | |
| 5 | Category framework | Not started | |
| 6 | v1 categories | Not started | |
| 7 | Actions and Bin | Not started | |
| 8 | Settings, ads, premium, polish | Not started | |

## Known issues / carried debt
- `FakeMediaAccessService` yields items in one batch; real Phase 3 impl must yield smaller batches for REQ-IDX-05 progress reporting.
- Phase 0 providers use Fake implementations. Real implementations swapped in providers.dart in later phases.
- `mediaPermissionStateProvider` is a FutureProvider; upgrade to StreamProvider re-emitting on AppLifecycleState.resumed for reactive partial-access banner.
- `lastModifiedCursor` in IndexingService.startScan() hardcoded to 0; Phase 4 should read ScanStateTable.lastModifiedCursor for proper incremental resume.
- Performance §5.5 budgets (45s full / 8s incremental / 350MB RAM) must be measured on real device with 15,000+ files before Phase 8 sign-off.

## Next action
Start Phase 4 (Home dashboard): hero StorageCard with total/recoverable size, Media Health score per PRD §8.1 formula, recoverable-space calculation per §8.3 (no double-counting), cleanup opportunity cards, ad slot wired to Premium state.
