# Phase 09 — Similar Photos (v2) & Pre-release QA (§7)

**Status:** Done  
**Completed:** 2026-09-17  
**Requirements:** REQ-SIM-01, REQ-SIM-02, REQ-DUP-04; PRD §7 (Pre-release QA)  
**Goal:** Perceptual similarity grouping (64-bit dHash / Hamming distance) on decoded thumbnails, suggested-best-shot evaluation (sharpness, resolution, exposure), labeled "Suggested" (never "Safe to delete"), distinct screen route (`/clean/similar-photos`) separate from exact duplicates, and completed Pre-release QA audit.

---

## What was built

### 1. Pre-release QA (§7) Sign-Off (`docs/QA_REPORT.md`)
- Performed complete audit per PRD §7 and DEV_PROMPT.md §7:
  - **§7.1 Failure Audit:** Incomplete scans resume from checkpoint; mid-delete cancellations leave surviving files untouched; SAF permission revocations prompt re-grant; database corruption regenerates schema cleanly; disk full states abort gracefully without data truncation.
  - **§7.2 Ad Policy Audit:** Full verification of all 8 REQ-ADS rules. Verified 0 ads on Bin/restore screens, 0 ads on confirmation sheets, 0 ads gating user files.
  - **§7.3 Play Policy Audit:** Storage permissions scoped strictly to WhatsApp media directories; 100% on-device processing; zero telemetry of filenames, thumbnails, or hashes.
  - **§7.4 Release Cleanup:** Debug flags disabled in production configurations; no mock data paths in release builds; log levels secured.
  - **§7.5 Test Matrix:** 135 unit, integration, and UI tests passing project-wide with zero warnings on `flutter analyze`.

### 2. Domain & Algorithm Layer (`REQ-SIM-01`, `REQ-SIM-02`)
- **`PerceptualHash` (`lib/features/clean/domain/perceptual_hash.dart`):**
  - Implements 64-bit difference hash (dHash) algorithm based on a 9x8 grayscale downsampled bitmap matrix.
  - `computeFromGrayscale9x8()`: Produces 64-bit bitmask by comparing adjacent pixels in each row ($P[x, y] > P[x+1, y]$).
  - `hammingDistance()`: Bitwise XOR and population count (`toRadixString(2).replaceAll('0', '').length`).
  - `clusterSimilar()`: Graph-connected component clustering grouping media items where Hamming distance $\le \text{threshold}$ (default $\le 10$).
- **`BestShotEvaluator` (`lib/features/clean/domain/best_shot_evaluator.dart`):**
  - Evaluates each cluster using a composite score: $\text{score} = \text{resolution} \times \text{sharpness} \times \text{exposure}$.
  - Labels the best item in each cluster as `"Suggested"`.
  - **Critical Rule (REQ-SIM-02):** Best shot is labeled `"Suggested"`, **never** `"Safe to delete"`.
  - `decorateCluster()`: Attaches group titles (`"Cluster #N"`) and marks the top-ranked shot with `badgeLabel = 'Suggested'`.

### 3. Native Android Thumbnail Hash Engine
- **`PerceptualHashEngine.kt` (`android/app/src/main/kotlin/com/wapptidy/wapptidy/PerceptualHashEngine.kt`):**
  - Processes decoded thumbnails only, never repeated full-resolution decodes (`REQ-SIM-01`).
  - Uses `BitmapFactory.Options` with `inSampleSize = 8` to downsample to thumbnail size, then rescales to 9x8 grayscale.
  - Computes 64-bit dHash natively for high-throughput batch computation.
- **`MainActivity.kt`:**
  - Registers MethodChannel `com.wapptidy/perceptual_hash` for `computeBatchHashes` and `computeHash`.

### 4. Data Layer & Presentation (`REQ-DUP-04`)
- **`SimilarPhotosDataSource` (`lib/features/clean/data/similar_photos_data_source.dart`):**
  - Queries indexed images from Drift database.
  - Excludes protected items per `REQ-ACT-05`.
  - Computes batch hashes via native engine and clusters similar images.
  - Pre-selects non-suggested copies while keeping the `"Suggested"` item unselected by default.
  - Computes `totalPotentialSavings`.
- **`SimilarPhotosScreen` (`lib/features/clean/presentation/similar_photos_screen.dart`):**
  - Independent route: `/clean/similar-photos` (`AppRoutes.similarPhotos`).
  - Distinct screen identity never merged with Exact Duplicates (`REQ-DUP-04`).
  - Header banner displays potential savings and explains: *"Groups photos with similar framing or burst shots. The best shot is marked 'Suggested' based on sharpness and resolution (REQ-SIM-02)."*

---

## Verification & Tests

- **Similar Photos Test Suite (`test/features/clean/similar_photos_test.dart`):**
  - `REQ-SIM-01`: `computeFromGrayscale9x8` returns 64-bit integer.
  - `REQ-SIM-01`: `hammingDistance` calculates differing bits correctly.
  - `REQ-SIM-01`: `clusterSimilar` groups items with Hamming distance $\le$ threshold.
  - `REQ-SIM-02`: `BestShotEvaluator` selects highest quality/resolution photo as `"Suggested"`.
  - `SimilarPhotosDataSource`: Pre-selects non-suggested copies and leaves `"Suggested"` unselected.
  - `REQ-ACT-05`: Protected items are strictly excluded from clustering.
  - `REQ-DUP-04 & UI`: `SimilarPhotosScreen` renders contextual banner, displays `"Suggested"` badge, and triggers `ConfirmationSheet` on delete.
- **Full Project Verification:**
  - `flutter analyze`: **0 issues found** (clean static analysis).
  - `flutter test`: **135 / 135 tests passed** (100% passing across all unit and widget tests).
