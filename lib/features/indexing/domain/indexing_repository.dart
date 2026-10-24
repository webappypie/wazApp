// lib/features/indexing/domain/indexing_repository.dart
//
// Indexing repository interface — the seam between the domain layer and the
// platform channel + Drift database. Everything above this layer is testable
// with a fake implementation.

import 'indexing_models.dart';

abstract interface class IndexingRepository {
  /// Start a full index scan.
  ///
  /// [sinceModifiedSec] > 0 → incremental scan from that timestamp (REQ-IDX-03).
  /// Returns a stream of [ScanProgress] updates (REQ-IDX-05).
  Stream<ScanProgress> startFullIndex({
    int sinceModifiedSec = 0,
    int generationSince = 0,
    List<String>? allowedSources,
  });

  /// Pause the currently running scan (REQ-IDX-04).
  Future<void> pause();

  /// Resume a paused scan (REQ-IDX-04).
  Future<void> resume();

  /// Cancel the scan and reset progress (REQ-IDX-04).
  Future<void> cancel();

  /// Read the current MediaStore generation counter.
  /// Used to cheaply detect whether any file has changed since the last scan.
  Future<int> currentGeneration();

  /// Read the generation saved at the end of the last complete scan.
  Future<int> lastSavedGeneration();

  /// Restore scan state from the database on app restart.
  /// Returns [ScanProgress] reflecting the last known state.
  Future<ScanProgress> restoreScanState();

  /// Total number of items currently in the index.
  Future<int> indexedItemCount();

  /// Total bytes across all indexed items.
  Future<int> indexedTotalBytes();
}
