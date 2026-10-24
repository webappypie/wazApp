# WazApp — AI Agent Handoff

## Mission
Audit the entire existing codebase, identify fake/stubbed/broken/incomplete features, then implement and verify the agreed P0/P1 product. Do not start with a blind rewrite.

## Mandatory audit first
1. Inspect repository structure, git branch/status/history, toolchain, dependencies, entry points, platform folders, routing/state management, storage/database, media pipeline, integrations and tests.
2. Locate Firebase configuration files and record filenames/project association without dumping sensitive values.
3. Locate and read the full WAPCentral integration guide from the root. Use the exact filename present; the guide is authoritative. Never invent APIs, endpoints, keys, app IDs or provider setup.
4. Run existing analyzers, tests and builds. Record exact commands and observed results.
5. Search for TODO/FIXME, mock/demo data, hard-coded counters, fake success/progress, empty callbacks, stub methods, ignored exceptions, disabled tests, placeholder screens and unreachable controls.
6. Create an evidence-based feature matrix: `working`, `partial`, `stubbed/fake`, `broken`, `missing`, `blocked by environment`, or `not applicable`.
7. Rank findings P0/P1/P2, identify privacy/data-loss risks and propose a low-risk plan.
8. Write audit files under `docs/audit/` before major changes.

## Rules
- A control is not complete because it looks right; it must perform its real operation and handle loading, errors, cancellation, retries and success.
- Never fake production data or claim success before verifying the result.
- Do not disable tests just to get a green build.
- Keep core media operations local and usable offline.
- No silent uploads or app-owned backend without explicit approval.
- Never auto-delete. Duplicate detection only warns; destructive actions require confirmation.
- App-private storage is not automatically encryption. Do not claim AES-256-GCM unless correctly implemented, key-managed and tested.
- Use platform-supported APIs and handle permission/version differences.
- Do not change package/bundle IDs, signing, Firebase identity, production ad IDs or billing product IDs without owner approval.
- Use test ads and billing sandbox during development.
- Protect secrets and do not print them into logs or audit reports.

## Required audit artifacts
`docs/audit/BASELINE_AUDIT.md`, `FEATURE_MATRIX.md`, `ARCHITECTURE_FINDINGS.md`, `IMPLEMENTATION_LOG.md`, `KNOWN_LIMITATIONS.md`, and `RELEASE_EVIDENCE.md`.

## Final report
Report changed files/features, verified P0/P1 status, actual tests/build commands and results, device/OS coverage, Firebase/WAPCentral/billing status, security findings, remaining blockers, and artifact paths only when files were actually generated.
