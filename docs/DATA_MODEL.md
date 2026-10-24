# Data Model and Local Storage

Adapt to existing database; don't replace a sound schema without migration evidence.

## Suggested MediaItem fields
`id` stable ID; `localUri/path`; `mediaType`; `sourceType` (status/imported/created/edited); `fileName`; `mimeType`; `fileSizeBytes`; `createdAt/importedAt/modifiedAt`; `width/height/durationMs`; `isFavourite/isPrivate/isEdited`; `thumbnailPath/cacheKey`; optional `contentHash` if safe and useful.

Optional `EditProject`: source reference, edit parameters, updated time and output references. `AppSettings`: onboarding, preferences, notification choice and cached premium state with store revalidation. `ProcessingJob`: type/status/progress, source/destination, error code and timestamps.

## Rules
Keep DB/files consistent; recover stale records; stable IDs rather than filenames; avoid unnecessary personal metadata; exclude private media from ordinary queries; version migrations; clean abandoned temporary files safely; no cloud media backup under current scope.
