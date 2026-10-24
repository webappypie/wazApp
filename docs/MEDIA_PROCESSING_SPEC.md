# Media Processing Specification

## General
Never overwrite original by default. Use temporary output then finalize atomically where possible. Validate output before library registration. Cancellation cleans partial files. Report low storage, unsupported/corrupt input, encode failure and cancellation distinctly. Avoid loading full-resolution assets unnecessarily.

## Photo pipeline
Validate source/metadata → create bounded preview → keep non-destructive parameters → normalize orientation → transform/crop → adjustments/filters → text/stickers → background full-resolution render → temporary output → validate readability/dimensions → finalize → update metadata/share. Test crop bounds, rotation/flip combinations, slider extremes, undo/redo, text overflow, transparency, orientation and large files.

## Video pipeline
Probe source → validate codec and trim range → apply supported trim/crop/mute/overlays → encode off UI thread → report real progress where available → cancel and clean partial output → validate duration/dimensions/playability/audio → finalize. Do not offer unsupported quality settings or pretend unsupported effects work.

## Status maker
Render a real image with background and text. Test Hindi shaping, font fallback, line breaks, emoji and export dimensions.
