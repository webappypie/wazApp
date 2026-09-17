// test/features/clean/similar_photos_test.dart
//
// Tests for Similar Photos feature (REQ-SIM-01, REQ-SIM-02, REQ-DUP-04).

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wapptidy/core/design/tokens.dart';
import 'package:wapptidy/core/widgets/action_widgets.dart';
import 'package:wapptidy/features/clean/data/similar_photos_data_source.dart';
import 'package:wapptidy/features/clean/domain/best_shot_evaluator.dart';
import 'package:wapptidy/features/clean/domain/category_models.dart';
import 'package:wapptidy/features/clean/domain/perceptual_hash.dart';
import 'package:wapptidy/features/clean/presentation/similar_photos_screen.dart';

Widget _buildTestApp({required SimilarPhotosDataSource dataSource}) {
  return ProviderScope(
    child: MaterialApp(
      theme: AppTheme.light(),
      home: SimilarPhotosScreen(customDataSource: dataSource),
    ),
  );
}

void main() {
  group('REQ-SIM-01: Perceptual Hash (dHash) & Hamming Distance', () {
    test('computeFromGrayscale9x8 returns 64-bit integer', () {
      final buffer = Uint8List(72);
      // Row 0 has descending gradient: 255 down to 0
      for (int i = 0; i < 9; i++) {
        buffer[i] = 255 - (i * 20);
      }

      final hash = PerceptualHash.computeFromGrayscale9x8(buffer);
      expect(hash, isNonZero);
    });

    test('hammingDistance calculates differing bits correctly', () {
      // Identical hashes -> distance 0
      expect(PerceptualHash.hammingDistance(0x12345678, 0x12345678), 0);

      // 1 bit flipped -> distance 1
      expect(PerceptualHash.hammingDistance(0x0, 0x1), 1);

      // 4 bits flipped -> distance 4
      expect(PerceptualHash.hammingDistance(0x0F, 0x0), 4);
    });

    test('clusterSimilar groups items with Hamming distance <= threshold', () {
      final items = [
        'photo_1_original',
        'photo_1_burst',
        'photo_2_unrelated',
      ];

      // Hashes: item 0 and 1 differ by only 2 bits; item 2 differs by 20 bits
      final hashes = {
        'photo_1_original': 0x0000000000000000,
        'photo_1_burst': 0x0000000000000003, // 2 bits diff
        'photo_2_unrelated': 0x00000000000FFFFF, // 20 bits diff
      };

      final clusters = PerceptualHash.clusterSimilar<String>(
        items: items,
        hashSelector: (item) => hashes[item]!,
        threshold: 10,
      );

      expect(clusters.length, 1);
      expect(clusters.first, contains('photo_1_original'));
      expect(clusters.first, contains('photo_1_burst'));
      expect(clusters.first, isNot(contains('photo_2_unrelated')));
    });
  });

  group('REQ-SIM-02: Suggested Best Shot Scoring Heuristic', () {
    test('BestShotEvaluator selects highest resolution photo as Suggested', () {
      const lowRes = CategoryItem(
        id: '1',
        contentUri: 'content://1',
        displayName: 'burst_1.jpg',
        mimeType: 'image/jpeg',
        sizeBytes: 1000,
        dateAddedSec: 100,
        dateModifiedSec: 100,
        bucketName: 'b',
        sourceApp: 'app',
        width: 1080,
        height: 1920, // 2.07 MP
      );

      const highRes = CategoryItem(
        id: '2',
        contentUri: 'content://2',
        displayName: 'burst_2.jpg',
        mimeType: 'image/jpeg',
        sizeBytes: 2000,
        dateAddedSec: 101,
        dateModifiedSec: 101,
        bucketName: 'b',
        sourceApp: 'app',
        width: 2160,
        height: 3840, // 8.29 MP
      );

      final decorated = BestShotEvaluator.decorateCluster(
        [lowRes, highRes],
        groupTitle: 'Test Cluster',
      );

      final suggested = decorated.firstWhere((e) => e.badgeLabel == 'Suggested');
      expect(suggested.id, '2'); // highRes should win
      expect(suggested.badgeLabel, 'Suggested');
      // NEVER "Safe to delete" (REQ-SIM-02)
      for (final item in decorated) {
        expect(item.badgeLabel, isNot('Safe to delete'));
      }
    });
  });

  group('SimilarPhotosDataSource & Pre-selection', () {
    test('Pre-selects non-suggested copies and leaves Suggested unselected', () async {
      const best = CategoryItem(
        id: 'best_1',
        contentUri: 'content://best',
        displayName: 'best.jpg',
        mimeType: 'image/jpeg',
        sizeBytes: 5000,
        dateAddedSec: 100,
        dateModifiedSec: 100,
        bucketName: 'b',
        sourceApp: 'app',
        width: 3000,
        height: 4000,
      );

      const alternative = CategoryItem(
        id: 'alt_1',
        contentUri: 'content://alt',
        displayName: 'alt.jpg',
        mimeType: 'image/jpeg',
        sizeBytes: 2000,
        dateAddedSec: 102,
        dateModifiedSec: 102,
        bucketName: 'b',
        sourceApp: 'app',
        width: 1080,
        height: 1920,
      );

      final ds = SimilarPhotosDataSource(
        mockItems: [best, alternative],
        mockHashes: {
          'content://best': 0x0,
          'content://alt': 0x1, // 1 bit distance -> similar
        },
      );

      final items = await ds.getItems();
      expect(items.length, 2);

      expect(ds.defaultPreselectedIds, contains('alt_1'));
      expect(ds.defaultPreselectedIds, isNot(contains('best_1')));
      expect(ds.totalPotentialSavings, 2000);
    });

    test('Protected items are excluded per REQ-ACT-05', () async {
      const protectedPhoto = CategoryItem(
        id: 'p1',
        contentUri: 'content://p1',
        displayName: 'protected.jpg',
        mimeType: 'image/jpeg',
        sizeBytes: 3000,
        dateAddedSec: 100,
        dateModifiedSec: 100,
        bucketName: 'b',
        sourceApp: 'app',
        isProtected: true,
      );

      final ds = SimilarPhotosDataSource(
        mockItems: [protectedPhoto],
      );

      final items = await ds.getItems();
      expect(items, isEmpty);
    });
  });

  group('REQ-DUP-04 & UI: SimilarPhotosScreen', () {
    testWidgets('Renders contextual banner and displays Suggested badge', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const item1 = CategoryItem(
        id: 'sim_1',
        contentUri: 'content://sim_1',
        displayName: 'shot_a.jpg',
        mimeType: 'image/jpeg',
        sizeBytes: 4 * 1024 * 1024,
        dateAddedSec: 100,
        dateModifiedSec: 100,
        bucketName: 'WhatsApp Images',
        sourceApp: 'com.whatsapp',
        width: 4000,
        height: 3000,
      );

      const item2 = CategoryItem(
        id: 'sim_2',
        contentUri: 'content://sim_2',
        displayName: 'shot_b.jpg',
        mimeType: 'image/jpeg',
        sizeBytes: 2 * 1024 * 1024,
        dateAddedSec: 101,
        dateModifiedSec: 101,
        bucketName: 'WhatsApp Images',
        sourceApp: 'com.whatsapp',
        width: 1920,
        height: 1080,
      );

      final ds = SimilarPhotosDataSource(
        mockItems: [item1, item2],
        mockHashes: {
          'content://sim_1': 0x0,
          'content://sim_2': 0x2, // 1 bit diff
        },
      );

      await tester.pumpWidget(_buildTestApp(dataSource: ds));
      await tester.pumpAndSettle();

      // REQ-DUP-04: Header banner clearly separates visual similarity
      expect(find.text('Visually Similar Photos'), findsOneWidget);
      expect(find.textContaining('best shot is marked "Suggested"'), findsOneWidget);

      // Best shot marked as "Suggested"
      expect(find.text('Suggested'), findsOneWidget);

      // Bottom bar shows 1 item selected (the alternative copy, saving 2.0 MB)
      expect(find.textContaining('1 items • 2.0 MB'), findsOneWidget);

      // Tap Delete -> ConfirmationSheet appears
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(find.byType(ConfirmationSheet), findsOneWidget);
    });
  });
}
