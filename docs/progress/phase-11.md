# Phase 11 — Video Compression (REQ-ACT-09, REQ-CMP-01..04)

**Status:** Done  
**Completed:** 2026-09-17  
**Requirements:** REQ-ACT-09, REQ-CMP-01 to REQ-CMP-04; PRD §5.4, §8.3, §11  
**Goal:** On-device hardware-accelerated video compression with quality profiles, size estimation heuristics, cancellable live progress, output verification, and safe replacement options.

---

## What was built

### 1. Domain & Estimation Layer (`REQ-CMP-01`, `REQ-CMP-02`)
- **`VideoQualityProfile` (`lib/features/clean/domain/compression_models.dart`):**
  - `balanced`: 720p @ 2.5 Mbps video + 128 kbps audio (~45-55% size reduction).
  - `highQuality`: 1080p @ 4.5 Mbps video + 192 kbps audio (~30% reduction).
  - `maximumSavings`: 480p @ 1.0 Mbps video + 96 kbps audio (~75% reduction).
- **`CompressionEstimate`:**
  - Calculates estimated output using target bitrate $\times$ video duration, or profile fallback ratio if duration metadata is missing.
  - Computes `estimatedSavingsBytes` and `estimatedSavingsPercentage`.
  - **Critical Rule:** Explicitly labeled **"Estimated"** in UI prior to compression.
- **`CompressionProgress` & `CompressionResult`:**
  - Tracks lifecycle: `preparing` $\rightarrow$ `transcoding` $\rightarrow$ `verifying` $\rightarrow$ `completed`.
  - Holds verified output path, original vs compressed byte sizes, and actual savings.

### 2. Native Android Engine (`android/app/src/main/kotlin/com/wapptidy/wapptidy/VideoCompressorEngine.kt`)
- On-device hardware-accelerated transcoding pipeline.
- Writes to an isolated temporary cache file (`comp_{timestamp}.mp4`), never modifying the original in-place.
- Streams live progress percentage to Flutter via EventChannel.
- **REQ-CMP-04 Interruption Safety:** Supports immediate cancellation via atomic flag; unlinks and deletes partial output files if aborted or failed.
- **REQ-ACT-09 Verification:** Validates that output file exists and has non-zero length before reporting success.
- Registered MethodChannel `com.wapptidy/video_compressor` and EventChannel `com.wapptidy/video_compressor_events` in `MainActivity.kt`.

### 3. Service Layer (`lib/features/clean/services/video_compression_service.dart`)
- `estimateSavings()`: Previews bitrate-based reduction.
- `compressVideo()`: Executes native transcode with live progress callbacks.
- `cancelCompression()`: Invokes native cancellation and cancels event listeners.
- **`finalizeReplacement()` (`REQ-ACT-09`, `REQ-CMP-03`):**
  - Guarantees original is **never** touched unless output is verified (`isVerified == true`).
  - If user selects "Replace Original": moves original item to Bin/Trash via `MediaActionCoordinator`.
  - If user selects "Keep Both Files": retains original completely untouched.

### 4. Interactive Presentation (`lib/features/clean/presentation/widgets/video_compression_sheet.dart`)
- Modal bottom sheet displaying:
  - Video title and current size.
  - Quality profile selection with interactive tiles.
  - Banner showing: "Estimated Savings: XX MB (~YY%)".
  - Live progress indicator with "Cancel Transcode" button.
  - Completion view showing verified actual savings and 2 explicit action buttons:
    - *"Replace Original (Move to Bin)"*
    - *"Keep Both Files"*
- Updated `LargeVideosScreen` (`large_videos_screen.dart`) with a contextual banner explaining on-device compression benefits.

---

## Verification & Tests

- **Video Compression Test Suite (`test/features/clean/video_compression_test.dart`):**
  - `REQ-CMP-01`: Profiles define clear resolution and bitrate constraints.
  - `REQ-CMP-02`: `CompressionEstimate` calculates bitrate-based savings for 60s video.
  - `REQ-CMP-02`: `CompressionEstimate` falls back to profile ratio when duration is 0.
  - `REQ-ACT-09`: Original is **never** deleted when user chooses Keep Both Files.
  - `REQ-ACT-09 & REQ-CMP-03`: Original is moved to bin only when `replaceOriginal` is true and output is verified.
  - `REQ-ACT-09`: Unverified compression result throws `StateError` and aborts replacement.
  - `REQ-CMP-04 & UI`: `VideoCompressionSheet` interaction renders profiles, estimated banner, runs transcode, and handles user choice.
- **Full Project Verification:**
  - `flutter analyze`: **0 issues found** (clean static analysis).
  - `flutter test`: **149 / 149 tests passed** (100% passing across all unit and widget tests).
