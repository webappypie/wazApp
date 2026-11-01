# Platform Compatibility and Media Access

## Android
Inspect current min/target SDK and toolchain before changing them. Test storage behaviour across supported API versions. Use SAF/user-granted folder access where appropriate and persist URI permissions when supported. Scoped storage and OEM differences mean a hard-coded directory is not enough. Validate WhatsApp and WhatsApp Business separately. Handle Android 13+ media permissions and Android 14+ selected/partial access where relevant. Avoid broad storage permission unless necessary and policy-compliant. Verify copies and outputs.

## iOS
An app cannot generally inspect another app's private container or assume access to WhatsApp's status cache. Use Photos/Files picker, document importer and share sheet. Limited Photos access is a valid state. Export with appropriate permission or via share sheet. Do not promise background access to the whole library without support.

## Media formats
Build a format matrix from actual dependencies. Test claimed formats (e.g. JPEG/PNG/HEIC and MP4/H.264 only where supported), orientation, aspect ratio, output dimensions, duration, audio and playability. Reject unsupported/corrupt inputs with useful errors.

## Device matrix
Record device, OS, build, permissions, source type/size, expected/actual result and evidence. Emulator/simulator tests do not replace physical-device validation for storage, codec, notification or billing behaviour.

## WhatsApp sources on Android (implemented)
WhatsApp (`com.whatsapp`) and WhatsApp Business (`com.whatsapp.w4b`) are separate sources end to end: separate installed-app detection (`<queries>` for both packages), separate folder grants (`tree_whatsapp` / `tree_business`), separate listings, separate source keys for duplicate detection, separate rows in Permissions & Access. A grant for one app never enables the other; the native resolver rejects a folder that belongs to the other app.

| Android | Status folder | How WazApp gets in |
|---|---|---|
| 11+ (API 30+) | `Android/media/<package>/WhatsApp[ Business]/Media/.Statuses` | user picks the folder once with the system folder picker (SAF), grant is persisted; the picker opens on the expected folder as a hint |
| 10 and older | `WhatsApp[ Business]/Media/.Statuses` in shared storage | same picker; hint path differs |

Real states reported (never inferred): not installed, not set up, granted, access lost (grant dropped), folder missing (granted but `.Statuses` gone). Access is re-read when the app resumes, when Settings is opened, and before every save. Expired statuses surface as "no longer available" at copy time. No storage permission is requested; `MANAGE_EXTERNAL_STORAGE` and `READ_MEDIA_*` are deliberately not declared.

## Permissions handled by WazApp
| Item | API | Notes |
|---|---|---|
| Status folders | SAF `ACTION_OPEN_DOCUMENT_TREE` + persistable URI | per source |
| Photos / files | system pickers, MediaStore insert for gallery export (API 29+) | no runtime permission; Android 9 and older share via the share sheet instead |
| Notifications | `POST_NOTIFICATIONS` via `permission_handler` (API 33+); below 33 only system settings can change it | prompted only on a tap; a second refusal leads to system settings, never a loop |
| Private Folder lock | `local_auth` (biometrics or screen lock) | needs a device screen lock; Settings deep link when none exists |

iOS: no access to WhatsApp's container; Photos/Files import and the share sheet only. `permission_handler` needs the notification macro in the Podfile when the iOS project is first built on a Mac (not verifiable on Windows).

