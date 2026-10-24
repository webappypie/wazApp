# Phase 3 — Real Video Editing and Export

Inspect codec dependencies/platform limits first. Implement trim with validated bounds, and crop/mute/text overlays only where reliable. Offer only encoder-supported settings. Encode off UI thread with real progress/cancel/retry/error states. Preserve source, clean partial outputs, and validate output existence/playability/duration/dimensions/audio. Test short/long/corrupt/unsupported clips, low storage, cancellation and memory pressure. Document platform limitations honestly.
