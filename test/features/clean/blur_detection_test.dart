// test/features/clean/blur_detection_test.dart
//
// Verification suite for Phase 10: Blur Detection (REQ-BLR-01).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wapptidy/core/widgets/action_widgets.dart';
import 'package:wapptidy/features/clean/data/blurry_photos_data_source.dart';
import 'package:wapptidy/features/clean/domain/blur_detector.dart';
import 'package:wapptidy/features/clean/domain/category_models.dart';
import 'package:wapptidy/features/clean/presentation/blurry_photos_screen.dart';

Widget _buildTestApp({required BlurryPhotosDataSource dataSource}) {
  return ProviderScope(
    child: MaterialApp(
      home: BlurryPhotosScreen(customDataSource: dataSource),
    ),
  );
}

void main() {
  group('REQ-BLR-01: Multi-scale Laplacian Variance & Confidence Tiers', () {
    test('Flat / zero-contrast matrix has zero variance and is veryBlurry', () {
      // 9x9 uniform matrix
      final flatMatrix = List.generate(9, (_) => List.filled(9, 128));
      final result = BlurDetector.computeFromGrayscaleMatrix(flatMatrix);

      expect(result.globalVariance, closeTo(0.0, 0.001));
      expect(result.confidence, BlurConfidence.veryBlurry);
      expect(result.isShallowDoF, isFalse);
    });

    test('High-contrast alternating pattern yields high variance and is sharp', () {
      // 9x9 checkerboard pattern
      final sharpMatrix = List.generate(
        9,
        (y) => List.generate(9, (x) => (x + y) % 2 == 0 ? 0 : 255),
      );
      final result = BlurDetector.computeFromGrayscaleMatrix(sharpMatrix);

      expect(result.globalVariance, greaterThan(250.0));
      expect(result.confidence, BlurConfidence.sharp);
    });

    test('Calibrated evaluate() maps variances to two confidence tiers', () {
      // High confidence blur: variance < 100
      final veryBlurry = BlurDetector.evaluate(
        globalVariance: 45.0,
        maxBlockVariance: 60.0,
      );
      expect(veryBlurry.confidence, BlurConfidence.veryBlurry);
      expect(veryBlurry.confidence.displayName, 'Very Blurry');

      // Moderate confidence blur: 100 <= variance < 250
      final possiblyBlurry = BlurDetector.evaluate(
        globalVariance: 180.0,
        maxBlockVariance: 220.0,
      );
      expect(possiblyBlurry.confidence, BlurConfidence.possiblyBlurry);
      expect(possiblyBlurry.confidence.displayName, 'Possibly Blurry');

      // Sharp image: variance >= 250
      final sharp = BlurDetector.evaluate(
        globalVariance: 450.0,
        maxBlockVariance: 600.0,
      );
      expect(sharp.confidence, BlurConfidence.sharp);
    });

    test('REQ-BLR-01: Shallow Depth-of-Field (bokeh) is preserved as sharp', () {
      // Shallow DoF has low overall variance (blurred background)
      // but a sharp focal subject with high regional variance (> 500)
      final bokehShot = BlurDetector.evaluate(
        globalVariance: 120.0,      // would otherwise look possibly blurry
        maxBlockVariance: 850.0,    // sharp focal point (portrait/macro)
      );

      expect(bokehShot.isShallowDoF, isTrue);
      expect(bokehShot.confidence, BlurConfidence.sharp);
    });
  });

  group('BlurryPhotosDataSource & Pre-selection Rules', () {
    const item1 = CategoryItem(
      id: 'blur_1',
      contentUri: 'content://media/1',
      displayName: 'photo_shake.jpg',
      mimeType: 'image/jpeg',
      sizeBytes: 2 * 1024 * 1024,
      dateAddedSec: 1000,
      dateModifiedSec: 1000,
      bucketName: 'WhatsApp Images',
      sourceApp: 'com.whatsapp',
    );

    const item2 = CategoryItem(
      id: 'blur_2',
      contentUri: 'content://media/2',
      displayName: 'photo_soft.jpg',
      mimeType: 'image/jpeg',
      sizeBytes: 3 * 1024 * 1024,
      dateAddedSec: 1000,
      dateModifiedSec: 1000,
      bucketName: 'WhatsApp Images',
      sourceApp: 'com.whatsapp',
    );

    const item3 = CategoryItem(
      id: 'sharp_3',
      contentUri: 'content://media/3',
      displayName: 'photo_crisp.jpg',
      mimeType: 'image/jpeg',
      sizeBytes: 4 * 1024 * 1024,
      dateAddedSec: 1000,
      dateModifiedSec: 1000,
      bucketName: 'WhatsApp Images',
      sourceApp: 'com.whatsapp',
    );

    const protectedItem = CategoryItem(
      id: 'blur_protected',
      contentUri: 'content://media/4',
      displayName: 'photo_fav_blurry.jpg',
      mimeType: 'image/jpeg',
      sizeBytes: 5 * 1024 * 1024,
      dateAddedSec: 1000,
      dateModifiedSec: 1000,
      bucketName: 'WhatsApp Images',
      sourceApp: 'com.whatsapp',
      isProtected: true,
    );

    test('Filters out sharp photos and populates confidence tiers', () async {
      final ds = BlurryPhotosDataSource(
        mockItems: [item1, item2, item3],
        mockScores: {
          item1.contentUri: const BlurEvaluation(
            globalVariance: 30.0,
            maxBlockVariance: 40.0,
            confidence: BlurConfidence.veryBlurry,
          ),
          item2.contentUri: const BlurEvaluation(
            globalVariance: 150.0,
            maxBlockVariance: 180.0,
            confidence: BlurConfidence.possiblyBlurry,
          ),
          item3.contentUri: const BlurEvaluation(
            globalVariance: 600.0,
            maxBlockVariance: 800.0,
            confidence: BlurConfidence.sharp,
          ),
        },
      );

      final items = await ds.getItems();

      // Sharp item3 should be excluded
      expect(items.length, 2);
      expect(items[0].id, 'blur_1');
      expect(items[0].badgeLabel, 'Very Blurry');
      expect(items[0].groupTitle, 'Very Blurry Photos');

      expect(items[1].id, 'blur_2');
      expect(items[1].badgeLabel, 'Possibly Blurry');
      expect(items[1].groupTitle, 'Possibly Blurry Photos');

      // Only Very Blurry item1 is pre-selected by default!
      expect(ds.defaultPreselectedIds, {'blur_1'});
      expect(ds.totalPotentialSavings, 2 * 1024 * 1024);
    });

    test('REQ-ACT-05: Protected blurry items are strictly excluded', () async {
      final ds = BlurryPhotosDataSource(
        mockItems: [item1, protectedItem],
        mockScores: {
          item1.contentUri: const BlurEvaluation(
            globalVariance: 10.0,
            maxBlockVariance: 10.0,
            confidence: BlurConfidence.veryBlurry,
          ),
          protectedItem.contentUri: const BlurEvaluation(
            globalVariance: 5.0,
            maxBlockVariance: 5.0,
            confidence: BlurConfidence.veryBlurry,
          ),
        },
      );

      final items = await ds.getItems();
      expect(items.any((it) => it.id == 'blur_protected'), isFalse);
    });
  });

  group('REQ-BLR-01 & UI: BlurryPhotosScreen', () {
    testWidgets('Renders header banner, confidence badges, and confirms delete', (tester) async {
      const item1 = CategoryItem(
        id: 'b1',
        contentUri: 'content://b1',
        displayName: 'shake.jpg',
        mimeType: 'image/jpeg',
        sizeBytes: 2 * 1024 * 1024,
        dateAddedSec: 1000,
        dateModifiedSec: 1000,
        bucketName: 'WhatsApp Images',
        sourceApp: 'com.whatsapp',
      );

      const item2 = CategoryItem(
        id: 'b2',
        contentUri: 'content://b2',
        displayName: 'soft.jpg',
        mimeType: 'image/jpeg',
        sizeBytes: 3 * 1024 * 1024,
        dateAddedSec: 1000,
        dateModifiedSec: 1000,
        bucketName: 'WhatsApp Images',
        sourceApp: 'com.whatsapp',
      );

      final ds = BlurryPhotosDataSource(
        mockItems: [item1, item2],
        mockScores: {
          item1.contentUri: const BlurEvaluation(
            globalVariance: 20.0,
            maxBlockVariance: 20.0,
            confidence: BlurConfidence.veryBlurry,
          ),
          item2.contentUri: const BlurEvaluation(
            globalVariance: 150.0,
            maxBlockVariance: 180.0,
            confidence: BlurConfidence.possiblyBlurry,
          ),
        },
      );

      await tester.pumpWidget(_buildTestApp(dataSource: ds));
      await tester.pumpAndSettle();

      // Header banner explains blur detection and bokeh protection
      expect(find.text('Blur Detection'), findsOneWidget);
      expect(find.textContaining('High-confidence savings: 2.0 MB'), findsOneWidget);

      // Confidence tier filter chips
      expect(find.text('All'), findsOneWidget);
      expect(find.text('Very Blurry'), findsWidgets);
      expect(find.text('Possibly Blurry'), findsWidgets);

      // Bottom bar shows 1 item preselected (the Very Blurry one)
      expect(find.textContaining('1 items • 2.0 MB'), findsOneWidget);

      // Tap Delete -> ConfirmationSheet appears
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(find.byType(ConfirmationSheet), findsOneWidget);
    });
  });
}
