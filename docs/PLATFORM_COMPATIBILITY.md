# Platform Compatibility and Media Access

## Android
Inspect current min/target SDK and toolchain before changing them. Test storage behaviour across supported API versions. Use SAF/user-granted folder access where appropriate and persist URI permissions when supported. Scoped storage and OEM differences mean a hard-coded directory is not enough. Validate WhatsApp and WhatsApp Business separately. Handle Android 13+ media permissions and Android 14+ selected/partial access where relevant. Avoid broad storage permission unless necessary and policy-compliant. Verify copies and outputs.

## iOS
An app cannot generally inspect another app's private container or assume access to WhatsApp's status cache. Use Photos/Files picker, document importer and share sheet. Limited Photos access is a valid state. Export with appropriate permission or via share sheet. Do not promise background access to the whole library without support.

## Media formats
Build a format matrix from actual dependencies. Test claimed formats (e.g. JPEG/PNG/HEIC and MP4/H.264 only where supported), orientation, aspect ratio, output dimensions, duration, audio and playability. Reject unsupported/corrupt inputs with useful errors.

## Device matrix
Record device, OS, build, permissions, source type/size, expected/actual result and evidence. Emulator/simulator tests do not replace physical-device validation for storage, codec, notification or billing behaviour.
