# Progress — WappTidy

## Status
Current phase: 16 (Done)
Last updated: 2026-09-17

## Phase log
| Phase | Name | Status | Notes |
|---|---|---|---|
| 0 | Foundation | Done | 21/21 tests pass, flutter analyze clean, committed 8c2f93d |
| 1 | Design system | Done | 0 issues, 21/21 tests, all components + gallery |
| 2 | Onboarding & permissions | Done | 34/34 tests pass; real-device checklist in docs/progress/phase-02.md |
| 3 | Indexing engine | Done | 50/50 tests; Kotlin MediaStore querier; schema v2; incremental diff; progress UI |
| 4 | Home dashboard | Done | 71/71 tests; §8.1 health score; §8.3 no-double-count; hero card; opportunity cards |
| 5 | Category framework | Done | 82/82 tests; generic CategoryScreen; sort/filter; grid/list; preview; multi-select |
| 6 | v1 categories | Done | 89/89 tests; Kotlin 2-stage hash duplicates; large videos; screenshots heuristics; old media |
| 7 | Actions and Bin | Done | 100/100 tests; Scoped Storage delete dialogs; write-first Move/Copy; Protect guard; ad-free Bin |
| 8 | Settings, ads, premium, polish | Done | 128/128 tests; Grouped settings; Theme switching; AdManager REQ-ADS-01..09; Play billing & offline cache |
| 9 | Similar photos & QA sign-off | Done | 135/135 tests; Pre-release QA §7 sign-off (docs/QA_REPORT.md); 64-bit dHash perceptual clustering; Best shot 'Suggested' |
| 10 | Blur detection | Done | 142/142 tests; REQ-BLR-01 multi-scale Laplacian variance; two confidence tiers; shallow DoF protection |
| 11 | Video compression | Done | 149/149 tests; REQ-ACT-09 write-first verification; quality profiles; estimated savings; cancellable transcode |
| 12 | Swipe Clean | Done | 156/156 tests; REQ-SWP-01..05 gesture card deck, instant undo, batch review confirmation, ad-free compliance |
| 13 | Scheduled Background Scans & Notifications | Done | 169/169 tests; REQ-SET-04, REQ-SET-05, P-02; WorkManager periodic scans, 3 notification channels, quiet hours (22:00-08:00) |
| 14 | Storage Growth Analytics with Historical Backfill | Done | 178/178 tests; REQ-ANL-01..04, P-03; SQLite snapshot table, cold-start backfill engine, 7D/30D free, 6M/All premium, area/line chart |
| 15 | Documents & Voice Notes / Audio Cleaner | Done | 191/191 tests; REQ-CLN-01, P-01..03; Audio playback preview, system viewer document launch, list-mode category screens, Home opportunity cards |
| 16 | Google Drive Cloud Backup / Offload | Done | 204/204 tests; REQ-BAK-01..03, P-01..03; drive.file restricted scope, live byte/file progress, failed retry, post-backup 'Review originals' CTA |

## Known issues / carried debt
- `FakeMediaAccessService` yields items in one batch; real Phase 3 impl must yield smaller batches for REQ-IDX-05 progress reporting.
- Phase 0 providers use Fake implementations. Real implementations swapped in providers.dart in later phases.
- `mediaPermissionStateProvider` is a FutureProvider; upgrade to StreamProvider re-emitting on AppLifecycleState.resumed for reactive partial-access banner.
- `lastModifiedCursor` in IndexingService.startScan() hardcoded to 0; Phase 4 should read ScanStateTable.lastModifiedCursor for proper incremental resume.
- Performance §5.5 budgets (45s full / 8s incremental / 350MB RAM) must be measured on real device with 15,000+ files before release.

## Next action
Phase 17: Production Release Packaging, Proguard / R8 Verification & Play Store Asset Readiness.



