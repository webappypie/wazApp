# WazApp — Save. Style. Share.

**Android application ID:** `com.webappypie.wazapp`  
**iOS bundle identifier:** `com.webappypie.wazapp.ios`

WazApp is a local-first status saver and (planned) photo/video editor. This repository was converted in place from an earlier "WappTidy" cleaner app — see `docs/adr/ADR-001-rename-wapptidy-in-place.md`; the old docs are in `docs/legacy-wapptidy/`.

## Current status
Phase 1 (core saver + library) is implemented for Android and scaffolded for iOS. Editors, status maker, Private Folder, Storage Manager, WAPCentral/ads/notifications and billing are **not implemented yet**. See `docs/audit/FEATURE_MATRIX.md`, `KNOWN_LIMITATIONS.md` and `RELEASE_EVIDENCE.md` for exact, evidenced status.

## Develop
```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # Drift code generation
flutter analyze
flutter test
flutter build apk --debug
```
Release builds need `android/key.properties` (see `android/key.properties.example`). For a local R8 check only: `flutter build apk --release --android-project-arg=allowDebugSigning=true` (output is debug-signed and must never be distributed).

## How status access works
Android: the user chooses the WhatsApp / WhatsApp Business `.Statuses` folder once (system folder picker, persisted grant, no storage permission). WazApp only reads it and copies chosen items into its private library. iOS cannot read WhatsApp's storage: use Import from Photos/Files. Details: `docs/adr/`.

## Product principles
- Real working features only; no fake buttons, hard-coded success, or placeholder production flows.
- Local-first/offline-first core media features. No app-owned backend or media server. No silent uploads, cloud backup or cloud AI.
- Follow the actual WAPCentral guide; never invent APIs, IDs or endpoints.
- Never auto-delete user files. Private storage is not described as encryption.
- Never commit service-account keys, signing keys, tokens or the WAPCentral guide (it contains the platform `X-App-Key`; it is git-ignored).

## Branding/legal
WazApp is a working name supplied by the owner, not a claim of WhatsApp/Meta affiliation. Verify trademark, domain, store-name and brand-confusion risk before public release. Original artwork only.

## Start here (agents)
`AI_AGENT_HANDOFF.md`, `prompts/MASTER_AGENT_PROMPT.md`, `docs/PHASE_ROADMAP.md`.
