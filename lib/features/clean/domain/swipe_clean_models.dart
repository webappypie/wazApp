// lib/features/clean/domain/swipe_clean_models.dart
//
// Pure domain models for Swipe Clean triage (REQ-ACT-08, REQ-SWP-01..05).
//
// RULES:
//   - REQ-ACT-08: Left delete, right keep, up archive, tap preview.
//   - REQ-SWP-02: Undo always available.
//   - REQ-SWP-04: Batch review confirmation before destructive commit.
//   - REQ-ADS-05: Zero ads inside swipe sequence.

import 'category_models.dart';

/// Available swipe directions and triage actions (REQ-ACT-08).
enum SwipeAction {
  delete,
  keep,
  archive;

  String get displayName {
    switch (this) {
      case SwipeAction.delete:
        return 'Delete';
      case SwipeAction.keep:
        return 'Keep';
      case SwipeAction.archive:
        return 'Archive';
    }
  }
}

/// Recorded decision for a single media item.
class SwipeDecision {
  const SwipeDecision({
    required this.item,
    required this.action,
    required this.timestamp,
  });

  final CategoryItem item;
  final SwipeAction action;
  final DateTime timestamp;
}

/// State of an active Swipe Clean session.
class SwipeSessionState {
  const SwipeSessionState({
    required this.candidates,
    this.history = const [],
    this.isTutorialDismissed = false,
  });

  final List<CategoryItem> candidates;
  final List<SwipeDecision> history;
  final bool isTutorialDismissed;

  /// Items remaining in the deck.
  List<CategoryItem> get remainingItems {
    if (history.length >= candidates.length) return const [];
    return candidates.sublist(history.length);
  }

  /// Top card currently facing the user.
  CategoryItem? get currentCard =>
      remainingItems.isNotEmpty ? remainingItems.first : null;

  /// Lookahead next card for smooth depth rendering.
  CategoryItem? get nextCard =>
      remainingItems.length > 1 ? remainingItems[1] : null;

  /// Lookahead third card.
  CategoryItem? get thirdCard =>
      remainingItems.length > 2 ? remainingItems[2] : null;

  bool get canUndo => history.isNotEmpty;
  bool get isCompleted => candidates.isNotEmpty && remainingItems.isEmpty;

  double get progressFraction =>
      candidates.isNotEmpty ? (history.length / candidates.length) : 0.0;

  List<CategoryItem> get itemsToDelete =>
      history.where((d) => d.action == SwipeAction.delete).map((d) => d.item).toList();

  List<CategoryItem> get itemsToKeep =>
      history.where((d) => d.action == SwipeAction.keep).map((d) => d.item).toList();

  List<CategoryItem> get itemsToArchive =>
      history.where((d) => d.action == SwipeAction.archive).map((d) => d.item).toList();

  int get totalDeleteBytes =>
      itemsToDelete.fold<int>(0, (sum, it) => sum + it.sizeBytes);

  String get formattedTotalDeleteBytes => formatBytes(totalDeleteBytes);

  SwipeSessionState copyWith({
    List<CategoryItem>? candidates,
    List<SwipeDecision>? history,
    bool? isTutorialDismissed,
  }) {
    return SwipeSessionState(
      candidates: candidates ?? this.candidates,
      history: history ?? this.history,
      isTutorialDismissed: isTutorialDismissed ?? this.isTutorialDismissed,
    );
  }
}
