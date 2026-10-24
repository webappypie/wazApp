# WazApp — Status Saver & Media Editor

**Tagline:** Save. Style. Share.  
**Android application ID:** `com.webappypie.wazapp`  
**iOS bundle identifier:** `com.webappypie.wazapp.ios`

WazApp is a local-first status saver and lightweight photo/video editor. This is an existing codebase to audit and improve, not permission to blindly rebuild it.

## Start here
1. Read `AI_AGENT_HANDOFF.md` and `prompts/MASTER_AGENT_PROMPT.md`.
2. Inspect the actual repository, git status, tests, builds and architecture.
3. Locate Firebase config files and the WAPCentral guide in the root. Read the guide fully before touching notifications, ads or promotions.
4. Run a baseline audit before editing, then follow `docs/PHASE_ROADMAP.md`.

## Product principles
- Real working features only; no fake buttons, hard-coded success, or placeholder production flows.
- Local-first/offline-first core media features. No app-owned backend or media server.
- No silent media uploads, cloud media backup or cloud AI.
- Follow actual WAPCentral guide; never invent APIs, IDs or endpoints.
- Android access must use supported user-granted mechanisms. iOS must not claim access to WhatsApp's private status folders.
- Preserve working code and user data. Avoid unnecessary rewrites.
- Never commit service-account keys, signing keys, tokens or other privileged secrets.

## Branding/legal
WazApp is a working name supplied by the owner, not a claim of WhatsApp/Meta affiliation. Verify trademark, domain, store-name and brand-confusion risk before public release. Use original artwork and do not copy WhatsApp's official logo or imply endorsement.
