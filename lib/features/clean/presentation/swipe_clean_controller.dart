// lib/features/clean/presentation/swipe_clean_controller.dart
//
// Controller managing card deck gestures, undo stack, and batch commit (REQ-ACT-08, REQ-SWP-01..05).
//
// RULES:
//   - REQ-ACT-08: Left delete, right keep, up archive.
//   - REQ-SWP-02: Instant undo support.
//   - REQ-SWP-04: Batch commit via MediaActionCoordinator.
//   - REQ-ACT-05: Protected items excluded from deletion.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/media_action_coordinator.dart';
import '../domain/action_models.dart';
import '../domain/category_models.dart';
import '../domain/swipe_clean_models.dart';

class SwipeCleanController extends ChangeNotifier {
  SwipeCleanController({
    required List<CategoryItem> initialCandidates,
    bool isTutorialDismissed = false,
  }) : _state = SwipeSessionState(
          candidates: List.unmodifiable(initialCandidates),
          isTutorialDismissed: isTutorialDismissed,
        );

  SwipeSessionState _state;
  SwipeSessionState get state => _state;

  /// Record a gesture decision for the active top card (REQ-ACT-08, REQ-SWP-01).
  void recordSwipe(SwipeAction action) {
    final current = _state.currentCard;
    if (current == null) return;

    // Trigger responsive haptic feedback
    switch (action) {
      case SwipeAction.delete:
        HapticFeedback.mediumImpact();
        break;
      case SwipeAction.keep:
        HapticFeedback.lightImpact();
        break;
      case SwipeAction.archive:
        HapticFeedback.selectionClick();
        break;
    }

    final decision = SwipeDecision(
      item: current,
      action: action,
      timestamp: DateTime.now(),
    );

    _state = _state.copyWith(
      history: [..._state.history, decision],
    );
    notifyListeners();
  }

  /// Reverts the most recent swipe decision (REQ-SWP-02).
  void undo() {
    if (!_state.canUndo) return;
    HapticFeedback.selectionClick();

    final newHistory = List<SwipeDecision>.from(_state.history)..removeLast();
    _state = _state.copyWith(history: newHistory);
    notifyListeners();
  }

  /// Mark the first-use tutorial as dismissed (REQ-SWP-05).
  void dismissTutorial() {
    _state = _state.copyWith(isTutorialDismissed: true);
    notifyListeners();
  }

  /// Reset the session with fresh items.
  void reset(List<CategoryItem> newCandidates) {
    _state = SwipeSessionState(
      candidates: List.unmodifiable(newCandidates),
      isTutorialDismissed: _state.isTutorialDismissed,
    );
    notifyListeners();
  }

  /// Commit the session decisions in a safe batch (REQ-SWP-04, REQ-ACT-01..05).
  ///
  /// CRITICAL SAFETY RULES:
  ///   - Only [itemsToDelete] are trashed.
  ///   - Any protected items are blocked per REQ-ACT-05.
  Future<CleanupSessionSummary> commitBatch(
    MediaActionCoordinator coordinator,
  ) async {
    final toDelete = _state.itemsToDelete;
    if (toDelete.isEmpty) {
      return coordinator.sessionSummary;
    }

    // Trashes all swiped-left items with Scoped Storage delete dialog
    final summary = await coordinator.trashSelected(toDelete);
    return summary;
  }
}
