# Phase 10 — Blur Detection (REQ-BLR-01)

**Status:** Done  
**Completed:** 2026-09-17  
**Requirements:** REQ-BLR-01; PRD §5.4, §5.5, §8.1  
**Goal:** Multi-scale discrete Laplacian variance blur detection with two confidence tiers (Very Blurry / Possibly Blurry), shallow depth-of-field (portrait/macro bokeh) false-positive protection, native Android thumbnail worker, and dedicated route `/clean/blurry-photos`.

---

## What was built

### 1. Native Kotlin Blur Engine (`android/app/src/main/kotlin/com/wapptidy/wapptidy/BlurDetectorEngine.kt`)
- Strictly operates on decoded thumbnails with `inSampleSize = 8` (`PRD §5.4`), never repeated full-resolution decodes.
- Rescales downsampled thumbnail to normalized 128x128 grayscale bitmap.
- Computes discrete $3 \times 3$ Laplacian convolution:
  $$\begin{bmatrix} 0 & 1 & 0 \\ 1 & -4 & 1 \\ 0 & 1 & 0 \end{bmatrix}$$
- Computes global variance $\sigma^2 = \frac{1}{N}\sum (L(x, y) - \mu)^2$.
- Computes regional $3 \times 3$ grid block variance to detect focal subjects in portrait mode and macro photography.
- **Shallow Depth-of-Field (DoF) Protection:** If maximum block variance exceeds sharp threshold ($\ge 500.0$) while global variance is moderate/low, classifies the photo as `sharp` and `isShallowDoF: true`, preserving intentional artistic bokeh.
- Registered MethodChannel `com.wapptidy/blur_detector` in `MainActivity.kt`.

### 2. Domain Layer (`lib/features/clean/domain/blur_detector.dart`)
- **`BlurConfidence` Enum:**
  - `veryBlurry`: High-confidence blur (both global and local block variances are low).
  - `possiblyBlurry`: Moderate-confidence blur (mildly soft or camera shake).
  - `sharp`: Crisp photo or intentional portrait bokeh.
- **`BlurEvaluation` Model:**
  - Holds `globalVariance`, `maxBlockVariance`, `confidence`, and `isShallowDoF`.
- **`BlurDetector` Engine:**
  - `evaluate()`: Calibrated thresholds mapping variances to confidence tiers.
  - `computeFromGrayscaleMatrix()`: Pure Dart reference implementation for unit testing.
  - **Rule Enforcement:** Items are labeled "Very Blurry" or "Possibly Blurry", **never** "Safe to delete".

### 3. Data & Presentation Layer
- **`BlurryPhotosDataSource` (`lib/features/clean/data/blurry_photos_data_source.dart`):**
  - Queries images from Drift `AppDatabase`.
  - Excludes protected items per `REQ-ACT-05`.
  - Calls `computeBatchBlurScores` via platform channel.
  - Filters out sharp photos and populates confidence tiers with badges and group titles.
  - **Pre-selection Rule:** Only pre-selects `Very Blurry` items by default; `Possibly Blurry` items remain unselected.
  - Computes `totalPotentialSavings` from high-confidence blurry items.
- **`BlurryPhotosScreen` (`lib/features/clean/presentation/blurry_photos_screen.dart`):**
  - Dedicated category screen registered at `/clean/blurry-photos` (`AppRoutes.blurryPhotos`).
  - Filter chips: `All`, `Very Blurry`, `Possibly Blurry`.
  - Contextual banner highlighting savings and explaining bokeh protection.
  - Delete flow guarded by `ConfirmationSheet`.

---

## Verification & Tests

- **Blur Detection Test Suite (`test/features/clean/blur_detection_test.dart`):**
  - `Flat / zero-contrast matrix has zero variance and is veryBlurry`: Verified $\sigma^2 \approx 0$.
  - `High-contrast alternating pattern yields high variance and is sharp`: Verified $\sigma^2 > 250$.
  - `Calibrated evaluate() maps variances to two confidence tiers`: Verified `veryBlurry`, `possiblyBlurry`, `sharp`.
  - `REQ-BLR-01: Shallow Depth-of-Field (bokeh) is preserved as sharp`: Verified portrait/macro protection.
  - `Filters out sharp photos and populates confidence tiers`: Verified `Very Blurry` and `Possibly Blurry` grouping.
  - `REQ-ACT-05: Protected blurry items are strictly excluded`: Verified protected media is ignored.
  - `REQ-BLR-01 & UI: BlurryPhotosScreen`: Verified banner, filter chips, single pre-selection, and `ConfirmationSheet`.
- **Full Project Verification:**
  - `flutter analyze`: **0 issues found** (clean static analysis).
  - `flutter test`: **142 / 142 tests passed** (100% passing across all test suites).
