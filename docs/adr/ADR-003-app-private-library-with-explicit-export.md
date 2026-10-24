# ADR-003 — Library lives in app-private storage; gallery export is an explicit action

- **Status:** accepted
- **Context:** Saved media needs stable file paths for viewing, editing and sharing, must not be reachable by other apps by default, and must keep Drift metadata consistent with the files.
- **Decision:** Files are stored under `<application support>/library/<random-id>.<ext>`; video thumbnails under `thumbs/`. Metadata is in Drift table `saved_media` (random id, never file name). Writes follow copy → verify → finalise → persist, with rollback of the file on any failure; deletes remove the media file first and keep the row if that fails; `reconcile()` removes rows without files, `*.part` leftovers and orphan thumbnails. "Save to gallery" copies a file to `Pictures/WazApp` or `Movies/WazApp` through MediaStore (Android 10+ only; shown as unsupported otherwise) and Share uses the OS share sheet.
- **Consequences:** items disappear on uninstall/clear-data — stated in Settings. This is *not* encryption and is never described as such.
- **Tests:** `library_service_test.dart` (rollback, reconcile, delete integrity, import validation).
