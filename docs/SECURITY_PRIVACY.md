# Security and Privacy Requirements

- Core media processing stays on-device. No silent uploads, cloud backup or cloud AI.
- Do not send media, thumbnails, paths, filenames or hashes to analytics/WAPCentral by default.
- Request permissions contextually; handle denial, partial access and revocation.
- App-private storage and biometric gate do not automatically mean encryption. If encryption is implemented, use maintained authenticated encryption, safe platform key storage, lifecycle/migration handling and tests; no custom crypto.
- Explain uninstall/data-loss behaviour for private local files.
- Never log tokens, private paths, media contents or secrets.
- Separate client config from privileged credentials; review `.gitignore`, logs and repository history.
- Follow platform/store and WAPCentral consent rules. Ads must not impersonate controls; notification opt-in is not required for core use.
- Delete only on explicit user action; bulk deletion requires count/scope confirmation and consistent metadata cleanup.
