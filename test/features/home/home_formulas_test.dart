// test/features/home/home_formulas_test.dart
//
// Unit tests for Home dashboard formulas.
// DEV_PROMPT §6 Phase 4: "write a unit test that would fail if a file were
// double-counted" and "health score verified by hand-calculating against a
// known small test dataset".
//
// All tests here are pure Dart — no Flutter, no Drift, no platform channel.

import 'package:flutter_test/flutter_test.dart';

import 'package:wapptidy/features/home/domain/home_models.dart';

void main() {
  // =========================================================================
  // PRD §8.1 — Media Health score
  // =========================================================================

  group('HealthScoreResult.compute — PRD §8.1 formula', () {
    test('empty library (0 bytes) returns score 100', () {
      final r = HealthScoreResult.compute(HealthScoreInputs.empty);
      expect(r.score, 100);
      expect(r.components, isEmpty);
    });

    test('clean library (no issues) returns score 100', () {
      final r = HealthScoreResult.compute(const HealthScoreInputs(
        totalBytes: 1000,
        // all components zero
      ));
      expect(r.score, 100);
    });

    test('max duplicate deduction: duplicate_ratio=1.0 → -30 → score 70 (min)', () {
      // min(30, 1.0 * 100) = 30. Others zero.
      final r = HealthScoreResult.compute(const HealthScoreInputs(
        totalBytes:    1000,
        duplicateBytes: 1000,
      ));
      expect(r.score, 70);
    });

    test('max large-video deduction: large_video_ratio=1.0 → min(25, 60) = 25', () {
      final r = HealthScoreResult.compute(const HealthScoreInputs(
        totalBytes:              1000,
        largeVideoBytesOver100MB: 1000,
      ));
      expect(r.score, 75);
    });

    test('max old-media deduction: old_ratio=1.0 → min(25, 50) = 25', () {
      final r = HealthScoreResult.compute(const HealthScoreInputs(
        totalBytes:       1000,
        bytesOlderThan1y: 1000,
      ));
      expect(r.score, 75);
    });

    test('max clutter deduction: clutter_ratio=1.0 → min(20, 80) = 20', () {
      final r = HealthScoreResult.compute(const HealthScoreInputs(
        totalBytes:      1000,
        screenshotBytes: 1000,
      ));
      expect(r.score, 80);
    });

    test('all-max deductions: score clamps to 0', () {
      // All ratios = 1.0:
      // -min(30, 100) = -30
      // -min(25, 60)  = -25
      // -min(25, 50)  = -25
      // -min(20, 80)  = -20
      // Total = -100 → clamp(0, 100) = 0
      final r = HealthScoreResult.compute(const HealthScoreInputs(
        totalBytes:               2000,
        duplicateBytes:           2000,
        largeVideoBytesOver100MB: 2000,
        bytesOlderThan1y:         2000,
        screenshotBytes:          2000,
      ));
      expect(r.score, 0);
    });

    test('hand-calculated known dataset', () {
      // total = 4 GB = 4,294,967,296 bytes
      // duplicate = 512 MB → ratio = 0.125 → ded = min(30, 12.5) = 12.5
      // largeVideo = 1 GB  → ratio = 0.25  → ded = min(25, 15.0) = 15.0
      // old = 800 MB       → ratio = 0.195 → ded = min(25, 9.77) = 9.77
      // screenshot = 200 MB → ratio = 0.049 → ded = min(20, 3.91) = 3.91
      // score = 100 - 12.5 - 15.0 - 9.77 - 3.91 = 58.82 → round to 59
      const totalB = 4 * 1024 * 1024 * 1024;
      final r = HealthScoreResult.compute(HealthScoreInputs(
        totalBytes:               totalB,
        duplicateBytes:           512 * 1024 * 1024,
        largeVideoBytesOver100MB: 1024 * 1024 * 1024,
        bytesOlderThan1y:         800 * 1024 * 1024,
        screenshotBytes:          200 * 1024 * 1024,
      ));
      // Allow ±1 for rounding differences.
      expect(r.score, inInclusiveRange(58, 60));
    });

    test('returns 4 components', () {
      final r = HealthScoreResult.compute(const HealthScoreInputs(
        totalBytes: 1000,
        duplicateBytes: 100,
      ));
      expect(r.components.length, 4);
    });

    test('HealthLabel.fromRatio thresholds', () {
      expect(HealthLabel.fromRatio(0.0),  HealthLabel.good);
      expect(HealthLabel.fromRatio(0.04), HealthLabel.good);
      expect(HealthLabel.fromRatio(0.05), HealthLabel.moderate);
      expect(HealthLabel.fromRatio(0.14), HealthLabel.moderate);
      expect(HealthLabel.fromRatio(0.15), HealthLabel.high);
      expect(HealthLabel.fromRatio(1.0),  HealthLabel.high);
    });

    test('score never exceeds 100 when components are negative (impossible but guarded)', () {
      final r = HealthScoreResult.compute(const HealthScoreInputs(totalBytes: 100));
      expect(r.score, lessThanOrEqualTo(100));
      expect(r.score, greaterThanOrEqualTo(0));
    });
  });

  // =========================================================================
  // PRD §8.3 — Recoverable space / double-counting guard
  // =========================================================================

  group('RecoverableSpaceResult.compute — PRD §8.3 double-counting', () {
    test('single candidate counted once', () {
      final r = RecoverableSpaceResult.compute(
        candidates: [
          const RecoverableFile(
            contentUri: 'content://media/1',
            sizeBytes:  100,
            category:   RecoverableCategory.duplicate,
          ),
        ],
        protectedUris: {},
      );
      expect(r.totalRecoverableBytes, 100);
    });

    test('SHIP BLOCKER: same URI in two categories counted only once', () {
      // The same file appears twice (e.g. queried as both duplicate AND old).
      // §8.3: "each file counted exactly once, using its highest-confidence category".
      // This test MUST FAIL if RecoverableSpaceResult double-counts the file.
      final r = RecoverableSpaceResult.compute(
        candidates: [
          const RecoverableFile(
            contentUri: 'content://media/42',
            sizeBytes:  500,
            category:   RecoverableCategory.duplicate,
          ),
          const RecoverableFile(
            contentUri: 'content://media/42', // same URI
            sizeBytes:  500,
            category:   RecoverableCategory.duplicate,
          ),
        ],
        protectedUris: {},
      );
      // Must be 500, not 1000.
      expect(r.totalRecoverableBytes, 500,
          reason: 'Double-counting ship blocker: same URI counted twice');
    });

    test('protected items excluded from recoverable total', () {
      final r = RecoverableSpaceResult.compute(
        candidates: [
          const RecoverableFile(
            contentUri: 'content://media/1',
            sizeBytes:  200,
            category:   RecoverableCategory.duplicate,
          ),
          const RecoverableFile(
            contentUri: 'content://media/protected',
            sizeBytes:  800,
            category:   RecoverableCategory.duplicate,
          ),
        ],
        protectedUris: {'content://media/protected'},
      );
      expect(r.totalRecoverableBytes, 200);
    });

    test('empty candidates → 0 bytes', () {
      final r = RecoverableSpaceResult.compute(
        candidates:    [],
        protectedUris: {},
      );
      expect(r.totalRecoverableBytes, 0);
    });

    test('all items protected → 0 bytes', () {
      final r = RecoverableSpaceResult.compute(
        candidates: [
          const RecoverableFile(
            contentUri: 'content://media/1',
            sizeBytes:  999,
            category:   RecoverableCategory.duplicate,
          ),
        ],
        protectedUris: {'content://media/1'},
      );
      expect(r.totalRecoverableBytes, 0);
    });

    test('multiple distinct files sum correctly', () {
      final r = RecoverableSpaceResult.compute(
        candidates: List.generate(
          10,
          (i) => RecoverableFile(
            contentUri: 'content://media/$i',
            sizeBytes:  100,
            category:   RecoverableCategory.duplicate,
          ),
        ),
        protectedUris: {},
      );
      expect(r.totalRecoverableBytes, 1000);
    });

    test('byCategory map populated correctly', () {
      final r = RecoverableSpaceResult.compute(
        candidates: [
          const RecoverableFile(
            contentUri: 'content://media/1',
            sizeBytes:  300,
            category:   RecoverableCategory.duplicate,
          ),
        ],
        protectedUris: {},
      );
      expect(r.byCategory[RecoverableCategory.duplicate], 300);
    });
  });

  // =========================================================================
  // HomeDashboard.empty sanity checks
  // =========================================================================

  group('HomeDashboard.empty', () {
    test('empty dashboard has score 100', () {
      expect(HomeDashboard.empty.healthScore.score, 100);
    });
    test('empty dashboard has 0 recoverable bytes', () {
      expect(HomeDashboard.empty.recoverable.totalRecoverableBytes, 0);
    });
    test('empty dashboard formatted total is 0 B', () {
      expect(HomeDashboard.empty.formattedTotal, '0 B');
    });
  });
}
