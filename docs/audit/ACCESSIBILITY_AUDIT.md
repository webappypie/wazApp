# Accessibility audit (Phase 6)

Date: 2026-10-25. Scope: every screen reachable in the app (Home, Saved, Create, Private, Settings, Storage Manager, Status maker, Photo editor with all its tools, Video editor with all its tools, Viewer, Onboarding). Phone-sized layout (360 x 780 dp).

## What was checked automatically

`test/accessibility/accessibility_test.dart` and `accessibility_editors_test.dart` (60 tests) run the real app/screens with semantics enabled and apply Flutter's guidelines in **light and dark** themes:

| Check | Guideline | Result |
|---|---|---|
| Touch targets | `androidTapTargetGuideline` (>= 48 x 48 dp) | pass on all screens |
| Labelled targets | `labeledTapTargetGuideline` (every tappable thing has a spoken label) | pass |
| Text contrast | `textContrastGuideline` (WCAG AA 4.5:1, 3:1 for large text) | pass |
| Large system text | 2.0x text scale: no overflow / layout exception on any screen | pass |

## Defects found by this audit and fixed

| # | Where | Problem | Fix |
|---|---|---|---|
| A1 | Home grid, "Save" button on each tile | 40 x 40 dp (compact density) | standard 48 dp button |
| A2 | Saved screen filter chips | row had a fixed height, chips below 48 dp and clipped by large text | intrinsic-height scrolling row |
| A3 | Status maker font chips | same fixed-height row | intrinsic-height scrolling row |
| A4 | All chips (theme) | `chipTheme.labelStyle` had no colour, so chip text was painted with the engine default (white): invisible on the light chip background in the light theme | label colour set to `onSurface` in the theme |
| A5 | Locked Private screen at large text | Column overflowed (28 px) | scrollable |
| A6 | Settings > status folders at large text | actions in `ListTile.trailing` consumed the whole tile ("Trailing widget consumes the entire tile width"), tile failed to lay out | actions moved under the text in a `Wrap` |
| A7 | Onboarding at large text | pages overflowed by 592 px | pages scroll |
| A8 | Photo / video editor | five-action app bar left about 16 dp for the title, so "Edit photo" collapsed on a 360 dp phone | smaller title style, `titleSpacing: 0` |
| A9 | Photo / video editor tool bar | fixed 60 dp height overflowed at large text | min-height, shrinking label |
| A10 | Video editor transport and trim read-outs | rows overflowed (37 px and 422 px) at large text | ellipsis / `Wrap` |
| A11 | Home status thumbnail, status preview | `Image.memory` had no error fallback: a corrupt thumbnail raised an unhandled image-codec exception | broken-image fallback |
| A12 | Private session unlock | state written after the provider was disposed (`UnmountedRefException`) if the screen closed during authentication | `ref.mounted` guards |

## What is NOT verified (needs a person with a screen reader)

- TalkBack reading order and announcements (e.g. progress of an export, "saved" confirmations): no TalkBack run was done.
- Custom-painted surfaces (photo/video canvas, status preview): they expose a text label but sticker/text-layer dragging has no non-gesture alternative yet.
- Switch Access, Voice Access, keyboard navigation, colour-blindness simulation, reduced-motion preference.
- 1.0x - 2.0x is covered; the Android maximum font scale on some devices (up to 3.0x) was not.
- Hindi text with TalkBack (language of speech for the Devanagari strings).
- iOS VoiceOver (no iOS build available).

## How to re-run

```bash
flutter test test/accessibility
```
