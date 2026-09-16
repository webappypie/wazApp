// test/features/clean/v1_categories_test.dart
//
// Tests for Phase 6 — v1 categories (REQ-DUP-01..04, REQ-VID-01, REQ-SCR-01, REQ-OLD-01).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wapptidy/core/design/tokens.dart';
import 'package:wapptidy/core/widgets/action_widgets.dart';
import 'package:wapptidy/core/widgets/media_tiles.dart';
import 'package:wapptidy/features/clean/data/duplicates_data_source.dart';
import 'package:wapptidy/features/clean/data/large_videos_data_source.dart';
import 'package:wapptidy/features/clean/data/old_media_data_source.dart';
import 'package:wapptidy/features/clean/data/screenshots_data_source.dart';
import 'package:wapptidy/features/clean/domain/category_models.dart';
import 'package:wapptidy/features/clean/presentation/duplicates_screen.dart';
import 'package:wapptidy/features/clean/presentation/large_videos_screen.dart';
import 'package:wapptidy/features/clean/presentation/old_media_screen.dart';
import 'package:wapptidy/features/clean/presentation/screenshots_screen.dart';

Widget _wrapWithApp(Widget child) {
  return ProviderScope(
    child: MaterialApp(
      theme: AppTheme.light(),
      home: child,
    ),
  );
}

void main() {
  // =========================================================================
  // 1. Exact Duplicates (REQ-DUP-01 to REQ-DUP-04)
  // =========================================================================
  group('REQ-DUP: Exact Duplicates', () {
    final sampleItems = [
      const CategoryItem(
        id: 'dup_1a',
        contentUri: 'content://media/dup1a',
        displayName: 'IMG_ORIGINAL.jpg',
        mimeType: 'image/jpeg',
        sizeBytes: 1024 * 1024, // 1 MB
        dateAddedSec: 1000, // Oldest
        dateModifiedSec: 1000,
        bucketName: 'WhatsApp Images',
        sourceApp: 'com.whatsapp',
      ),
      const CategoryItem(
        id: 'dup_1b',
        contentUri: 'content://media/dup1b',
        displayName: 'IMG_COPY.jpg',
        mimeType: 'image/jpeg',
        sizeBytes: 1024 * 1024, // 1 MB (same size)
        dateAddedSec: 2000, // Newer copy
        dateModifiedSec: 2000,
        bucketName: 'WhatsApp Images',
        sourceApp: 'com.whatsapp',
      ),
      const CategoryItem(
        id: 'unique_1',
        contentUri: 'content://media/unique1',
        displayName: 'UNIQUE.jpg',
        mimeType: 'image/jpeg',
        sizeBytes: 5 * 1024 * 1024, // Unique size 5 MB
        dateAddedSec: 1500,
        dateModifiedSec: 1500,
        bucketName: 'WhatsApp Images',
        sourceApp: 'com.whatsapp',
      ),
    ];

    test('Two-stage grouping marks oldest as Original and calculates potential saving', () async {
      final ds = DuplicatesDataSource(
        testItems: sampleItems,
      );

      final items = await ds.getItems();

      // Unique file discarded; 2 duplicates retained
      expect(items.length, 2);

      final original = items.firstWhere((it) => it.id == 'dup_1a');
      final copy = items.firstWhere((it) => it.id == 'dup_1b');

      expect(original.isOriginal, isTrue);
      expect(original.badgeLabel, 'Original');
      expect(copy.isOriginal, isFalse);
      expect(copy.badgeLabel, 'Duplicate');

      expect(ds.totalPotentialSavings, 1024 * 1024);
      expect(original.groupTitle, contains('Save 1.0 MB'));
    });

    testWidgets('DuplicatesScreen pre-selects non-original copies per REQ-DUP-03', (tester) async {
      final ds = DuplicatesDataSource(
        testItems: sampleItems,
      );

      await tester.pumpWidget(_wrapWithApp(DuplicatesScreen(dataSourceOverride: ds)));
      await tester.pumpAndSettle();

      // Non-original copy (1 MB) is pre-selected, original is NOT
      expect(find.text('1 items • 1.0 MB'), findsOneWidget);

      // Potential saving banner is shown
      expect(find.textContaining('Potential Saving: 1.0 MB'), findsOneWidget);

      // Verify Delete button in BottomActionBar is enabled with 1 item
      final deleteBtn = find.widgetWithText(BottomActionBar, 'Delete');
      expect(deleteBtn, findsOneWidget);
    });
  });

  // =========================================================================
  // 2. Large Videos (REQ-VID-01)
  // =========================================================================
  group('REQ-VID: Large Videos', () {
    final videoItems = [
      const CategoryItem(
        id: 'vid_1',
        contentUri: 'content://media/vid1',
        displayName: 'small_video.mp4',
        mimeType: 'video/mp4',
        sizeBytes: 20 * 1024 * 1024, // 20 MB (under 50 MB threshold)
        dateAddedSec: 1000,
        dateModifiedSec: 1000,
        bucketName: 'WhatsApp Video',
        sourceApp: 'com.whatsapp',
        durationMs: 30000,
      ),
      const CategoryItem(
        id: 'vid_2',
        contentUri: 'content://media/vid2',
        displayName: 'large_video_100m.mp4',
        mimeType: 'video/mp4',
        sizeBytes: 120 * 1024 * 1024, // 120 MB
        dateAddedSec: 2000,
        dateModifiedSec: 2000,
        bucketName: 'WhatsApp Video',
        sourceApp: 'com.whatsapp',
        durationMs: 180000, // 3m 0s
      ),
      const CategoryItem(
        id: 'vid_3',
        contentUri: 'content://media/vid3',
        displayName: 'huge_video_500m.mp4',
        mimeType: 'video/mp4',
        sizeBytes: 600 * 1024 * 1024, // 600 MB
        dateAddedSec: 3000,
        dateModifiedSec: 3000,
        bucketName: 'WhatsApp Video',
        sourceApp: 'com.whatsapp',
        durationMs: 600000, // 10m 0s
      ),
    ];

    test('LargeVideosDataSource filters out videos under 50 MB', () async {
      final ds = LargeVideosDataSource(
        testItems: videoItems,
      );

      final items = await ds.getItems();
      expect(items.length, 2);
      expect(items.any((v) => v.displayName == 'small_video.mp4'), isFalse);
    });

    testWidgets('LargeVideosScreen displays size filters and formatted duration', (tester) async {
      final ds = LargeVideosDataSource(
        testItems: videoItems,
      );

      await tester.pumpWidget(_wrapWithApp(LargeVideosScreen(dataSourceOverride: ds)));
      await tester.pumpAndSettle();

      expect(find.text('Large Videos'), findsOneWidget);
      expect(find.text('50 MB+'), findsOneWidget);
      expect(find.text('100 MB+'), findsOneWidget);
      expect(find.text('500 MB+'), findsOneWidget);
      expect(find.text('1 GB+'), findsOneWidget);

      // Verify row items
      expect(find.text('large_video_100m.mp4'), findsOneWidget);
      expect(find.text('huge_video_500m.mp4'), findsOneWidget);
    });
  });

  // =========================================================================
  // 3. Screenshots (REQ-SCR-01)
  // =========================================================================
  group('REQ-SCR: Screenshots', () {
    test('isScreenshot heuristic identifies bucket and aspect ratio', () {
      const screenshotByBucket = CategoryItem(
        id: 's1',
        contentUri: 'content://media/s1',
        displayName: 'received_img.png',
        mimeType: 'image/png',
        sizeBytes: 1000,
        dateAddedSec: 1000,
        dateModifiedSec: 1000,
        bucketName: 'Screenshots',
        sourceApp: 'com.whatsapp',
      );
      expect(ScreenshotsDataSource.isScreenshot(screenshotByBucket), isTrue);

      const screenshotByRatio = CategoryItem(
        id: 's2',
        contentUri: 'content://media/s2',
        displayName: 'IMG_20240101.png',
        mimeType: 'image/png',
        sizeBytes: 1000,
        dateAddedSec: 1000,
        dateModifiedSec: 1000,
        bucketName: 'WhatsApp Images',
        sourceApp: 'com.whatsapp',
        width: 1080,
        height: 2400, // Ratio: 2.22 (tall screen)
      );
      expect(ScreenshotsDataSource.isScreenshot(screenshotByRatio), isTrue);

      const normalPhoto = CategoryItem(
        id: 's3',
        contentUri: 'content://media/s3',
        displayName: 'IMG_photo.jpg',
        mimeType: 'image/jpeg',
        sizeBytes: 1000,
        dateAddedSec: 1000,
        dateModifiedSec: 1000,
        bucketName: 'WhatsApp Images',
        sourceApp: 'com.whatsapp',
        width: 4000,
        height: 3000, // 4:3 standard photo
      );
      expect(ScreenshotsDataSource.isScreenshot(normalPhoto), isFalse);
    });

    testWidgets('ScreenshotsScreen displays date filters', (tester) async {
      final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final ds = ScreenshotsDataSource(
        testItems: [
          CategoryItem(
            id: 'scr_today',
            contentUri: 'content://media/scr_today',
            displayName: 'Screenshot_Today.png',
            mimeType: 'image/png',
            sizeBytes: 500 * 1024,
            dateAddedSec: nowSec - 3600, // 1 hour ago
            dateModifiedSec: nowSec - 3600,
            bucketName: 'Screenshots',
            sourceApp: 'com.whatsapp',
          ),
        ],
      );

      await tester.pumpWidget(_wrapWithApp(ScreenshotsScreen(dataSourceOverride: ds)));
      await tester.pumpAndSettle();

      expect(find.text('Screenshots'), findsOneWidget);
      expect(find.text('Today'), findsOneWidget);
      expect(find.text('7 days'), findsOneWidget);
      expect(find.text('30 days'), findsOneWidget);
      expect(find.text('1 year+'), findsOneWidget);
      expect(find.byType(MediaTile), findsOneWidget);
    });
  });

  // =========================================================================
  // 4. Old Media (REQ-OLD-01)
  // =========================================================================
  group('REQ-OLD: Old Media', () {
    testWidgets('OldMediaScreen sub-groups by media type and displays recoverable size banner', (tester) async {
      final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final ds = OldMediaDataSource(
        testItems: [
          CategoryItem(
            id: 'old_img',
            contentUri: 'content://media/old1',
            displayName: 'old_photo.jpg',
            mimeType: 'image/jpeg',
            sizeBytes: 3 * 1024 * 1024, // 3 MB
            dateAddedSec: nowSec - 400 * 86400, // > 1 year
            dateModifiedSec: nowSec - 400 * 86400,
            bucketName: 'WhatsApp Images',
            sourceApp: 'com.whatsapp',
          ),
          CategoryItem(
            id: 'old_vid',
            contentUri: 'content://media/old2',
            displayName: 'old_clip.mp4',
            mimeType: 'video/mp4',
            sizeBytes: 50 * 1024 * 1024, // 50 MB
            dateAddedSec: nowSec - 500 * 86400, // > 1 year
            dateModifiedSec: nowSec - 500 * 86400,
            bucketName: 'WhatsApp Video',
            sourceApp: 'com.whatsapp',
            durationMs: 60000,
          ),
        ],
      );

      await tester.pumpWidget(_wrapWithApp(OldMediaScreen(dataSourceOverride: ds)));
      await tester.pumpAndSettle();

      expect(find.text('Old Media'), findsOneWidget);
      // Banner shows total recoverable size: 53.0 MB
      expect(find.textContaining('Total Space: 53.0 MB'), findsOneWidget);

      // Sub-groups by type
      expect(find.text('Images'), findsOneWidget);
      expect(find.text('Videos'), findsOneWidget);

      // Age filters
      expect(find.text('3m+'), findsOneWidget);
      expect(find.text('1y+'), findsOneWidget);
    });
  });
}
