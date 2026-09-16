// test/features/indexing/indexing_diff_test.dart
//
// Unit tests for IndexingService.diffDecision() — the incremental-diff logic.
// DEV_PROMPT §6 Phase 3: "Write unit tests for the incremental-diff logic
// specifically — this is where bugs hide."
//
// These tests ONLY call the static diffDecision() method — pure logic, no IO,
// no platform channel, no Drift, no Flutter.

import 'package:flutter_test/flutter_test.dart';
import 'package:wapptidy/features/indexing/data/fake_indexing_repository.dart';
import 'package:wapptidy/features/indexing/domain/indexing_models.dart';
import 'package:wapptidy/features/indexing/presentation/indexing_service.dart';

void main() {
  group('IndexingService.diffDecision — incremental diff logic', () {
    // -------------------------------------------------------------------------
    // Empty index (first launch)
    // -------------------------------------------------------------------------

    test('empty index → full scan regardless of generation', () {
      final r = IndexingService.diffDecision(
        currentGeneration:  99,
        lastGeneration:     0,
        existingItemCount:  0,
        lastModifiedCursor: 0,
      );
      expect(r.decision, ScanDecision.full);
      expect(r.sinceModifiedSec, 0);
    });

    test('empty index with matching generations → still full scan', () {
      // Even if generations match, with no index we must do a full scan.
      final r = IndexingService.diffDecision(
        currentGeneration:  5,
        lastGeneration:     5,
        existingItemCount:  0,
        lastModifiedCursor: 0,
      );
      expect(r.decision, ScanDecision.full);
    });

    // -------------------------------------------------------------------------
    // Populated index, generation unchanged → skip
    // -------------------------------------------------------------------------

    test('same generation, non-zero, populated index → skip', () {
      final r = IndexingService.diffDecision(
        currentGeneration:  42,
        lastGeneration:     42,
        existingItemCount:  500,
        lastModifiedCursor: 1_700_000_000,
      );
      expect(r.decision, ScanDecision.skip);
      expect(r.sinceModifiedSec, 0);
    });

    test('generation both zero (pre-API29 device), populated index → incremental', () {
      // When the platform cannot provide a generation (pre-API29),
      // both values are 0. We must NOT skip — must run incremental
      // to catch any changes.
      final r = IndexingService.diffDecision(
        currentGeneration:  0,
        lastGeneration:     0,
        existingItemCount:  200,
        lastModifiedCursor: 1_700_000_000,
      );
      // generation == lastGeneration but lastGeneration == 0 → treat as unknown
      // The implementation skips only when lastGeneration > 0 AND they match.
      expect(r.decision, ScanDecision.incremental);
    });

    // -------------------------------------------------------------------------
    // Populated index, generation changed → incremental
    // -------------------------------------------------------------------------

    test('generation changed, populated index → incremental from cursor', () {
      const cursor = 1_700_000_000;
      final r = IndexingService.diffDecision(
        currentGeneration:  43,
        lastGeneration:     42,
        existingItemCount:  500,
        lastModifiedCursor: cursor,
      );
      expect(r.decision, ScanDecision.incremental);
      expect(r.sinceModifiedSec, cursor);
    });

    test('generation went from 0 to non-zero (first API29 scan) → incremental', () {
      final r = IndexingService.diffDecision(
        currentGeneration:  1,
        lastGeneration:     0,
        existingItemCount:  300,
        lastModifiedCursor: 1_690_000_000,
      );
      expect(r.decision, ScanDecision.incremental);
    });

    test('cursor is zero despite populated index → incremental with zero cursor (full-range)', () {
      // This handles the edge case where the cursor was never saved (e.g.
      // the DB was migrated from an older version). We still run incremental
      // but with sinceModifiedSec=0, which effectively covers all time.
      final r = IndexingService.diffDecision(
        currentGeneration:  10,
        lastGeneration:     5,
        existingItemCount:  100,
        lastModifiedCursor: 0,
      );
      expect(r.decision, ScanDecision.incremental);
      expect(r.sinceModifiedSec, 0);
    });

    // -------------------------------------------------------------------------
    // Monotonically non-decreasing property of ScanProgress (REQ-IDX-05)
    // -------------------------------------------------------------------------

    test('ScanProgress.fraction is clamped to 0.0–1.0', () {
      // Over-count should never exceed 1.0.
      const p = ScanProgress(
        status: ScanStatus.running,
        itemsProcessed: 210,
        itemsTotal: 200,
        bytesProcessed: 0,
      );
      expect(p.fraction, 1.0);
    });

    test('ScanProgress.fraction is 0 when total is unknown', () {
      const p = ScanProgress(
        status: ScanStatus.running,
        itemsProcessed: 50,
        itemsTotal: 0, // total not yet known
        bytesProcessed: 0,
      );
      expect(p.fraction, 0.0);
    });

    test('ScanProgress.isTerminal true for done/cancelled/error', () {
      for (final s in [ScanStatus.done, ScanStatus.cancelled, ScanStatus.error]) {
        final p = ScanProgress(
          status: s,
          itemsProcessed: 0,
          itemsTotal: 0,
          bytesProcessed: 0,
        );
        expect(p.isTerminal, isTrue, reason: '${p.status} should be terminal');
      }
    });

    test('ScanProgress.isTerminal false for idle/running/paused', () {
      for (final s in [ScanStatus.idle, ScanStatus.running, ScanStatus.paused]) {
        final p = ScanProgress(
          status: s,
          itemsProcessed: 0,
          itemsTotal: 0,
          bytesProcessed: 0,
        );
        expect(p.isTerminal, isFalse, reason: '${p.status} should not be terminal');
      }
    });

    // -------------------------------------------------------------------------
    // FakeIndexingRepository stream behaviour
    // -------------------------------------------------------------------------

    test('FakeIndexingRepository emits configured events in order', () async {
      // Import inside test to avoid top-level import clutter.
      final repo = _makeFakeRepo();
      final events = await repo.startFullIndex().toList();
      expect(events.length, 3);
      expect(events[0].status, ScanStatus.running);
      expect(events[1].status, ScanStatus.running);
      expect(events[2].status, ScanStatus.done);
    });

    test('FakeIndexingRepository stops after first terminal event', () async {
      final repo = _makeFakeRepo();
      // The fake already has a done event at index 2 — no more events after.
      final events = await repo.startFullIndex().toList();
      expect(events.last.isTerminal, isTrue);
    });

    test('FakeIndexingRepository pause/resume/cancel record calls', () async {
      final repo = _makeFakeRepo();
      await repo.pause();
      await repo.resume();
      await repo.cancel();
      expect(repo.pauseCalled,  isTrue);
      expect(repo.resumeCalled, isTrue);
      expect(repo.cancelCalled, isTrue);
    });

    test('FakeIndexingRepository.indexedItemCount returns configured value', () async {
      final repo = _makeFakeRepo()..configure(count: 999);
      expect(await repo.indexedItemCount(), 999);
    });

    test('FakeIndexingRepository.indexedTotalBytes returns configured value', () async {
      final repo = _makeFakeRepo()..configure(bytes: 1024 * 1024 * 512);
      expect(await repo.indexedTotalBytes(), 1024 * 1024 * 512);
    });
  });
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

FakeIndexingRepository _makeFakeRepo() => FakeIndexingRepository();

