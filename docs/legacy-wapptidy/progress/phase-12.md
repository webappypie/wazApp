# Phase 12 — Swipe Clean (REQ-ACT-08, REQ-SWP-01..05)

**Status:** Done  
**Completed:** 2026-09-17  
**Requirements:** REQ-ACT-08, REQ-SWP-01 to REQ-SWP-05; REQ-ADS-05, P-06; PRD §5.4, §8.3  
**Goal:** Tinder-style gesture card deck for rapid media triage (Left = Delete, Right = Keep, Up = Archive, Tap = Fullscreen Preview), instant undo capability, zero ads during swiping, and mandatory batch review confirmation before any destructive deletion.

---

## What was built

### 1. Domain Layer (REQ-SWP-01, REQ-SWP-02, lib/features/clean/domain/swipe_clean_models.dart)
- **SwipeAction enum:**
  - delete: Mark item for batch deletion.
  - keep: Retain item untouched.
  - rchive: Keep item or preserve out of active cleanup stream.
- **SwipeDecision:**
  - Holds MediaItem item, SwipeAction action, and DateTime timestamp.
- **SwipeSessionState:**
  - Immutable state holding candidates list, history (decision stack for undo), isCompleted, and showTutorial.
  - Computes emainingItems, currentIndex, currentCard, 
extCard, 	hirdCard.
  - Calculates session statistics: itemsToDelete, itemsToKeep, itemsToArchive, and 	otalDeleteBytes.

### 2. Controller & Gesture State Machine (lib/features/clean/presentation/swipe_clean_controller.dart)
- Extends ChangeNotifier for clean Flutter widget tree reactivity.
- **Swipe Actions & Feedback:**
  - ecordSwipe(action): Pushes SwipeDecision to history, triggers distinct haptic feedback:
    - HapticFeedback.mediumImpact() on Delete / Archive.
    - HapticFeedback.lightImpact() on Keep.
  - undo(): Pops the last decision from history, restores top card to the deck, triggers HapticFeedback.selectionClick().
  - dismissTutorial(): Dismisses the first-run tutorial overlay (REQ-SWP-05).
  - eset(): Restores full candidate deck.
- **Batch Deletion Coordination (REQ-SWP-04, REQ-ACT-05):**
  - commitBatch(MediaActionCoordinator coordinator): Safely batches all items flagged with SwipeAction.delete through MediaActionCoordinator.trashItems().
  - Automatically filters out any protected items (isProtected == true), strictly honoring REQ-ACT-05.

### 3. Gesture Deck & Animations (lib/features/clean/presentation/widgets/swipe_card.dart)
- **Interactive Physics:**
  - Horizontal drag determines rotation angle (x / 1000 radians) and horizontal translation.
  - Vertical drag upwards triggers Archive action.
  - Spring-back animation on release if drag does not exceed 100px velocity threshold.
- **Visual Feedback Badges:**
  - Dynamic alpha badge overlay matching gesture direction:
    - **KEEP** (Green, right swipe)
    - **DELETE** (Red, left swipe)
    - **ARCHIVE** (Blue, upward swipe)
- **Tap to Preview:**
  - Tap on card invokes MediaPreviewSheet for fullscreen inspection with metadata without swiping.

### 4. Interactive Presentation (lib/features/clean/presentation/swipe_clean_screen.dart)
- Route: /clean/swipe (AppRoutes.swipeClean).
- **Stacked Lookahead:**
  - Renders top 3 cards with progressive depth scaling (0.95, 0.90) and vertical offsets (12px, 24px) for natural physical card deck feel.
- **Controls & Progress:**
  - Top progress indicator bar showing session completion ratio.
  - Header undo button with remaining undo count badge.
  - Bottom circular action buttons for accessibility and direct tapping (Delete, Archive, Undo, Keep).
- **First-Use Tutorial Overlay (REQ-SWP-05):**
  - Explains gestures before the first card is manipulated:
    - Swiping left -> Delete (queued for review)
    - Swiping right -> Keep
    - Swiping up -> Archive
    - Tap -> Fullscreen Preview
- **Batch Review Confirmation (REQ-SWP-04):**
  - Upon exhausting the card deck, presents a review screen displaying:
    - Total items reviewed.
    - Items marked for deletion and total reclaimable storage.
    - Items kept/archived.
  - Tapping Clean Up Now triggers explicit ConfirmationSheet before committing trashing via MediaActionCoordinator.
- **Zero Ads Compliance (REQ-ADS-05, P-06):**
  - Strict ad-free zone during swipe sequence. No interstitial or banner ads during swiping or review screen.

---

## Verification & Tests

- **Swipe Clean Test Suite (	est/features/clean/swipe_clean_test.dart):**
  - REQ-SWP-01 & REQ-SWP-02: Recording swipes advances card deck, populates history, and undo restores previous card.
  - REQ-SWP-04: Left swipe queues item for batch deletion without immediate trashing.
  - REQ-SWP-04 & REQ-ACT-05: commitBatch() deletes only non-protected delete-flagged items.
  - REQ-ADS-05 & P-06: Ad policy audit verifies zero ad units injected into swipe sequence.
  - REQ-SWP-05 & UI: SwipeCleanScreen displays first-use tutorial overlay and dismisses upon interaction.
  - REQ-SWP-01 & UI: Action buttons (Keep, Delete, Archive, Undo) update card deck properly.
  - REQ-SWP-04 & UI: Completing all cards reveals completion review screen with batch stats.
- **Full Project Verification:**
  - lutter analyze: **0 issues found** (clean static analysis).
  - lutter test: **156 / 156 tests passed** (100% passing across all 156 unit and widget tests).
