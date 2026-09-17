# Phase 15 — Documents & Voice Notes / Audio Cleaner (REQ-CLN-01, P-01, P-02, P-03)

**Status:** Done  
**Completed:** 2026-09-17  
**Requirements:** REQ-CLN-01, P-01, P-02, P-03; PRD §5.2, §7.5, §8.1  
**Goal:** Expand WappTidy's cleanup suite with dedicated category cleaners for WhatsApp Voice Notes & Audio Clips and WhatsApp Documents (PDF, Office, Archives), complete with interactive audio player preview, system viewer document launch (`ACTION_VIEW`), custom list view tiles, and Home opportunity cards.

---

## What was built

### 1. Platform & MediaStore Indexing Enhancements
- **`MediaIndexer.kt`:**
  - Expanded selection clause to index documents (`application/%` and `text/%`) alongside images, videos, and audio without requiring `MANAGE_EXTERNAL_STORAGE` (PRD §5.2 scoped storage compliance).
  - Added `"WhatsApp Voice Notes"` and `"WhatsApp Business Documents"` to `WHATSAPP_BUCKETS`.
- **`MediaActionHandler.kt` & `MainActivity.kt`:**
  - Added `openMedia` method to launch `Intent.ACTION_VIEW` with `FLAG_GRANT_READ_URI_PERMISSION`, enabling users to inspect documents in their device's default reader app before cleanup (`P-01`).
  - Added `openMediaItem` to `MediaAccessService` and `MediaActionCoordinator`.

### 2. Audio Playback Subsystem (P-01)
- **`AudioPlaybackService` (`lib/core/services/audio/audio_playback_service.dart`):**
  - Contract defining `play()`, `pause()`, `resume()`, `stop()`, `seek()`, and `setSpeed()` (1.0x, 1.5x, 2.0x).
  - Stream-based reactive state snapshots: `AudioPlaybackStatus` (`idle`, `playing`, `paused`, `completed`, `error`), position, duration, and progress ratio.
- **`PlatformAudioPlaybackService` & `FakeAudioPlaybackService`:**
  - Native platform channel bridge connecting to `com.wapptidy/audio_player`.
  - In-memory test fake supporting seek, state transitions, and ticker-based playback progress.
- **Dependency Injection:** Exposed `audioPlaybackServiceProvider` in `lib/core/di/providers.dart`.

### 3. Domain & Data Sources
- **`CategoryItem` Extensions (`lib/features/clean/domain/category_models.dart`):**
  - Added `isDocument`, `isVoiceNote`, `fileExtension`, and `documentTypeLabel` (`PDF Document`, `Word Document`, `Spreadsheet`, `Presentation`, `Archive`, `Text File`).
- **`VoiceNotesDataSource` (`lib/features/clean/data/voice_notes_data_source.dart`):**
  - Categorizes audio items into Push-to-Talk voice notes (`PTT-`) vs. music/clips (`AUD-`).
  - Sub-groups items into 'Voice Notes' and 'Audio Clips' with metadata badges.
- **`DocumentsDataSource` (`lib/features/clean/data/documents_data_source.dart`):**
  - Classifies non-media shared files into `PDF Documents`, `Office Documents`, `Archives`, and `Other Documents`.
- **`RealHomeRepository` (`lib/features/home/data/real_home_repository.dart`):**
  - Generates `voice_notes` and `documents` cleanup opportunity cards on the Home dashboard when matching clutter exists in the SQLite index.

### 4. Presentation & Interactive Previews
- **`MediaListRow` Leading Tile Indicator (`lib/core/widgets/media_tiles.dart`, `category_screen.dart`):**
  - Audio and documents render distinct, color-tinted 56x56 icon tiles in list view (deep orange for voice notes, purple for audio clips, red for PDFs, blue for Office docs, amber for archives).
- **`MediaPreviewSheet` (`lib/features/clean/presentation/media_preview_sheet.dart`):**
  - **Audio & Voice Notes:** Integrated interactive player card with play/pause, scrub slider, time indicators, and playback speed menu (1x, 1.5x, 2x).
  - **Documents:** Integrated file card with type badge and "Open in System Viewer" button.
- **`VoiceNotesScreen` (`lib/features/clean/presentation/voice_notes_screen.dart`):**
  - List-mode `CategoryScreen` with filter chips: `All`, `Voice Notes`, `Audio Clips`, `Old (>6m)`, `Large (>5 MB)`.
  - Header banner displaying total audio space and file count.
- **`DocumentsScreen` (`lib/features/clean/presentation/documents_screen.dart`):**
  - List-mode `CategoryScreen` with filter chips: `All`, `PDFs`, `Office Docs`, `Archives`, `Large (>10 MB)`.
  - Header banner displaying total document volume.
- **Navigation:**
  - Registered `/clean/voice-notes` and `/clean/documents` in `app_router.dart`.

---

## Verification & Tests

1. **Audio Playback Unit Tests (`test/core/services/audio_playback_service_test.dart`):**
   - Verified initial state, play/pause/resume transitions, seeking within duration bounds, speed changes, stop reset, and error simulation.
2. **Voice Notes Unit & UI Tests (`test/features/clean/voice_notes_test.dart`):**
   - Verified classification of PTT voice notes vs. audio clips and exclusion of protected files.
   - Verified rendering of header, total space, list items, opening preview sheet, and triggering audio playback.
3. **Documents Unit & UI Tests (`test/features/clean/documents_test.dart`):**
   - Verified classification of PDFs, Office documents, and archives, and exclusion of media items.
   - Verified rendering of document rows, badges, and "Open in System Viewer" action.
4. **Static Analysis & Suite Run:**
   - `flutter analyze`: 0 issues found.
