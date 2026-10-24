# ADR-004 — One renderer for preview and export; pure-Dart/dart:ui pipeline

- **Status:** accepted (Phase 2). Device visual verification pending (see RELEASE_EVIDENCE).
- **Context:** The photo editor and status maker must show exactly what is exported, work on Android and iOS, keep originals untouched, and stay local/offline. Native image libraries (Android Bitmap/CoreImage) would need two implementations and would be unverifiable on iOS from this Windows host.
- **Decision:**
  - An immutable `EditState` (orientation, crop, colour adjust, preset filter, overlays) is the only source of truth. `paintEdit()` draws it onto a `dart:ui` Canvas for both the on-screen preview (≤1600 px decode) and the export (full frame, decode bounded to 4096 px, never upscaled). Colour work is a composed 4×5 `ColorFilter.matrix` (saturation → contrast → brightness → preset).
  - Text and emoji are laid out by the engine's text shaper (HarfBuzz) so Devanagari conjuncts/matras shape correctly. Every text style names a Devanagari fallback (bundled Hind) so Hindi never falls back to missing-glyph boxes. Emoji use the platform colour-emoji font.
  - Export: render → raw RGBA → JPEG q92 encoded by the `image` package in a background isolate (`compute`) → written to a temp file → decoded back and size-checked inside `LibraryService.addCreatedFile` → copied atomically into the library. Failure/cancel removes every partial artefact. Output has no EXIF (location is not carried over).
  - Status maker: procedural backgrounds/patterns/frames (no image assets), text auto-shrinks to the safe area (max 300 characters), exported as a 1080×1920 PNG (lossless text edges).
  - Undo/redo are snapshots of the immutable state; a slider drag or gesture is one step; reset is itself undoable.
- **Deliberately not offered:** *sharpness* (no convolution in Canvas without a shader/native code; a control that does nothing would be fake), free-angle straighten, JPEG quality picker, HEIC output.
- **Fonts:** six OFL families bundled (≈2.7 MB; licences in `assets/licenses`, shown on the licence page). Source: github.com/google/fonts, fetched 2026-10-24.
- **Alternatives rejected:** `image` package for all pixel work (too slow on 12 MP at interaction rates), native Kotlin/Swift processors (double implementation, iOS unverifiable), `google_fonts` runtime download (breaks offline).
- **Trade-offs:** pure-Dart JPEG encode of a 4096 px image takes seconds on low-end phones (progress dialog with stage + cancel between stages; cancellation cannot interrupt the isolate mid-encode).
- **Tests:** `photo_renderer_test` (pixel checks for rotate/flip/crop/colour/filters/overlays), `crop_math_test`, `photo_export_test` (real codecs), `photo_editor_screen_test`, `status_renderer_test` (templates distinct, no clipping, Devanagari shaping/fallback), `status_maker_screen_test`.
