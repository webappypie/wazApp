// lib/features/indexing/presentation/indexing_service.dart
//
// IndexingService — orchestrates full vs incremental scans.
//
// Incremental-diff logic (REQ-IDX-03):
//   1. Read the last saved MediaStore generation from the DB.
//   2. Read the current generation from Kotlin.
//   3. If generation is unchanged AND we have an existing index → skip scan.
//   4. If generation changed → run incremental scan (sinceModifiedSec = cursor).
//   5. If no existing index → run full scan (sinceModifiedSec = 0).
//
// This is the logic that unit tests specifically target (DEV_PROMPT §6 Phase 3,
// "this is where bugs hide").
//
// Thread safety: all public methods are called from Flutter's main isolate.
// The underlying Kotlin work runs in a coroutine on Dispatchers.IO.

import 'dart:async';

import '../domain/indexing_models.dart';
import '../domain/indexing_repository.dart';

/// Decision produced by the incremental-diff check.
enum ScanDecision {
  /// No files have changed — skip the scan.
  skip,

  /// Some files may have changed — run an incremental scan (fast path).
  incremental,

  /// No index exists yet — run a full scan.
  full,
}

class IndexingService {
  IndexingService(this._repo);

  final IndexingRepository _repo;

  final _controller = StreamController<ScanProgress>.broadcast();

  /// Stream of ScanProgress events from the current or most recent scan.
  Stream<ScanProgress> get progressStream => _controller.stream;

  ScanProgress _lastProgress = const ScanProgress(
    status: ScanStatus.idle,
    itemsProcessed: 0,
    itemsTotal: 0,
    bytesProcessed: 0,
  );

  ScanProgress get lastProgress => _lastProgress;

  StreamSubscription<ScanProgress>? _sub;

  // ---------------------------------------------------------------------------
  // Incremental-diff decision (testable, pure logic)
  // ---------------------------------------------------------------------------

  /// Determine what kind of scan is needed.
  ///
  /// [currentGeneration]   — generation reported by MediaStore right now.
  /// [lastGeneration]      — generation saved at the end of the last scan.
  /// [existingItemCount]   — number of rows currently in the index.
  /// [lastModifiedCursor]  — dateModifiedSec of the last item indexed.
  ///
  /// Returns a [ScanDecision] and the [sinceModifiedSec] to pass to the repo
  /// (0 for full scan, cursor value for incremental).
  static ({ScanDecision decision, int sinceModifiedSec}) diffDecision({
    required int currentGeneration,
    required int lastGeneration,
    required int existingItemCount,
    required int lastModifiedCursor,
  }) {
    if (existingItemCount == 0) {
      // No index yet — always run a full scan.
      return (decision: ScanDecision.full, sinceModifiedSec: 0);
    }

    if (currentGeneration == lastGeneration && lastGeneration > 0) {
      // Generation unchanged — no MediaStore writes since last scan.
      return (decision: ScanDecision.skip, sinceModifiedSec: 0);
    }

    // Generation changed or unknown — run incremental from the cursor.
    // sinceModifiedSec = 0 on the very first scan (cursor is 0).
    return (
      decision: ScanDecision.incremental,
      sinceModifiedSec: lastModifiedCursor,
    );
  }

  // ---------------------------------------------------------------------------
  // Public control API
  // ---------------------------------------------------------------------------

  /// Run a scan. Decides full vs incremental automatically.
  Future<void> startScan() async {
    if (_lastProgress.status == ScanStatus.running) return; // already running

    // Read current state for diff decision.
    final currentGen  = await _repo.currentGeneration();
    final lastGen     = await _repo.lastSavedGeneration();
    final itemCount   = await _repo.indexedItemCount();
    final restored    = await _repo.restoreScanState();

    final result = diffDecision(
      currentGeneration:  currentGen,
      lastGeneration:     lastGen,
      existingItemCount:  itemCount,
      lastModifiedCursor: 0, // Phase 3: cursor tracked in ScanStateTable; 0 = full-range
    );

    if (result.decision == ScanDecision.skip) {
      // Nothing to do — emit a synthetic done event.
      final skipProgress = ScanProgress(
        status:         ScanStatus.done,
        itemsProcessed: itemCount,
        itemsTotal:     itemCount,
        bytesProcessed: await _repo.indexedTotalBytes(),
        scanVersion:    restored.scanVersion,
        generation:     currentGen,
      );
      _emit(skipProgress);
      return;
    }

    _sub?.cancel();
    _sub = _repo
        .startFullIndex(
          sinceModifiedSec: result.sinceModifiedSec,
          generationSince:  result.decision == ScanDecision.incremental ? lastGen : 0,
        )
        .listen(
          _emit,
          onError: (Object e) => _emit(ScanProgress(
            status:         ScanStatus.error,
            itemsProcessed: _lastProgress.itemsProcessed,
            itemsTotal:     _lastProgress.itemsTotal,
            bytesProcessed: _lastProgress.bytesProcessed,
            error:          e.toString(),
          )),
        );
  }

  Future<void> pause()  => _repo.pause();
  Future<void> resume() => _repo.resume();

  Future<void> cancel() async {
    await _repo.cancel();
    _sub?.cancel();
  }

  void _emit(ScanProgress p) {
    _lastProgress = p;
    if (!_controller.isClosed) _controller.add(p);
  }

  void dispose() {
    _sub?.cancel();
    _controller.close();
  }
}
