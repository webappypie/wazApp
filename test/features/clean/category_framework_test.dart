// test/features/clean/category_framework_test.dart
//
// Tests for the generic Category framework (REQ-CLN-01).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wapptidy/core/design/tokens.dart';
import 'package:wapptidy/core/widgets/action_widgets.dart';
import 'package:wapptidy/core/widgets/buttons.dart';
import 'package:wapptidy/core/widgets/filter_chip.dart';
import 'package:wapptidy/core/widgets/media_tiles.dart';
import 'package:wapptidy/core/widgets/state_widgets.dart';
import 'package:wapptidy/features/clean/data/fake_category_data_source.dart';
import 'package:wapptidy/features/clean/domain/category_models.dart';
import 'package:wapptidy/features/clean/presentation/category_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wapptidy/features/clean/presentation/media_preview_sheet.dart';

Widget _buildTestApp({
  required FakeCategoryDataSource dataSource,
  void Function(List<CategoryItem>)? onMove,
  void Function(List<CategoryItem>)? onCopy,
  void Function(List<CategoryItem>)? onProtect,
  void Function(List<CategoryItem>)? onDelete,
  CategoryViewMode initialViewMode = CategoryViewMode.grid,
}) {
  return ProviderScope(
    child: MaterialApp(
      theme: AppTheme.light(),
      home: CategoryScreen(
        title: 'Test Category',
        dataSource: dataSource,
        initialViewMode: initialViewMode,
        onMove: onMove,
        onCopy: onCopy,
        onProtect: onProtect,
        onDelete: onDelete,
      ),
    ),
  );
}

void main() {
  group('Category framework — Domain models', () {
    test('formatBytes helper returns formatted string', () {
      expect(formatBytes(0), '0 B');
      expect(formatBytes(512), '512 B');
      expect(formatBytes(1024), '1.0 KB');
      expect(formatBytes(1024 * 1024), '1.0 MB');
      expect(formatBytes(150 * 1024 * 1024), '150.0 MB');
      expect(formatBytes(2 * 1024 * 1024 * 1024), '2.0 GB');
    });

    test('CategoryItem duration and size formatting', () {
      const item = CategoryItem(
        id: 'test_1',
        contentUri: 'content://media/1',
        displayName: 'test.mp4',
        mimeType: 'video/mp4',
        sizeBytes: 100 * 1024 * 1024,
        dateAddedSec: 1000,
        dateModifiedSec: 2000,
        bucketName: 'WhatsApp Video',
        sourceApp: 'com.whatsapp',
        durationMs: 125000, // 2m 5s
      );

      expect(item.formattedSize, '100.0 MB');
      expect(item.formattedDuration, '02:05');
      expect(item.isVideo, isTrue);
      expect(item.isImage, isFalse);
    });
  });

  group('Category framework — CategoryScreen UI', () {
    testWidgets('renders items in grid view with MediaTile', (tester) async {
      final ds = FakeCategoryDataSource();
      await tester.pumpWidget(_buildTestApp(dataSource: ds));
      await tester.pumpAndSettle();

      expect(find.text('Test Category'), findsOneWidget);
      expect(find.byType(MediaTile), findsNWidgets(5));
      expect(find.byType(BottomActionBar), findsOneWidget);
    });

    testWidgets('toggles view mode between grid and list', (tester) async {
      final ds = FakeCategoryDataSource();
      await tester.pumpWidget(_buildTestApp(dataSource: ds));
      await tester.pumpAndSettle();

      expect(find.byType(MediaTile), findsNWidgets(5));
      expect(find.byType(MediaListRow), findsNothing);

      // Tap view mode toggle
      await tester.tap(find.byTooltip('List view'));
      await tester.pumpAndSettle();

      expect(find.byType(MediaListRow), findsNWidgets(5));
      expect(find.byType(MediaTile), findsNothing);

      // Tap view mode toggle back to grid
      await tester.tap(find.byTooltip('Grid view'));
      await tester.pumpAndSettle();

      expect(find.byType(MediaTile), findsNWidgets(5));
    });

    testWidgets('tapping an unselected item opens preview sheet (REQ-CLN-01 Task 3)',
        (tester) async {
      final ds = FakeCategoryDataSource();
      await tester.pumpWidget(_buildTestApp(
        dataSource: ds,
        initialViewMode: CategoryViewMode.list,
      ));
      await tester.pumpAndSettle();

      // Tap unselected item row
      await tester.tap(find.text('IMG-20240915-WA0001.jpg'));
      await tester.pumpAndSettle();

      // Preview sheet is displayed
      expect(find.byType(MediaPreviewSheet), findsOneWidget);
      expect(find.text('Resolution'), findsOneWidget);
      expect(find.text('1920 × 1080'), findsOneWidget);

      // Close preview sheet
      await tester.tap(find.byTooltip('Close preview'));
      await tester.pumpAndSettle();

      expect(find.byType(MediaPreviewSheet), findsNothing);
    });

    testWidgets('long-pressing an item toggles selection and updates live total',
        (tester) async {
      final ds = FakeCategoryDataSource();
      await tester.pumpWidget(_buildTestApp(
        dataSource: ds,
        initialViewMode: CategoryViewMode.list,
      ));
      await tester.pumpAndSettle();

      // Initially no selection
      expect(find.textContaining('items •'), findsNothing);

      // Long press item 1 (2 MB)
      await tester.longPress(find.text('IMG-20240915-WA0001.jpg'));
      await tester.pumpAndSettle();

      // Selection total updates
      expect(find.text('1 items • 2.0 MB'), findsOneWidget);

      // Long press item 2 (150 MB)
      await tester.longPress(find.text('VID-20240916-WA0002.mp4'));
      await tester.pumpAndSettle();

      // Selection total: 152 MB
      expect(find.text('2 items • 152.0 MB'), findsOneWidget);

      // Tapping an already selected item deselects it
      await tester.tap(find.text('IMG-20240915-WA0001.jpg'));
      await tester.pumpAndSettle();

      expect(find.text('1 items • 150.0 MB'), findsOneWidget);
    });

    testWidgets('Select All toggles all visible items', (tester) async {
      final ds = FakeCategoryDataSource();
      await tester.pumpWidget(_buildTestApp(dataSource: ds));
      await tester.pumpAndSettle();

      // Tap Select All
      await tester.tap(find.byTooltip('Select all'));
      await tester.pumpAndSettle();

      expect(find.text('5 items • 157.5 MB'), findsOneWidget);

      // Tap Deselect all
      await tester.tap(find.byTooltip('Deselect all'));
      await tester.pumpAndSettle();

      expect(find.textContaining('items •'), findsNothing);
    });

    testWidgets('filtering by type updates visible items and selection totals',
        (tester) async {
      final ds = FakeCategoryDataSource();
      await tester.pumpWidget(_buildTestApp(dataSource: ds));
      await tester.pumpAndSettle();

      // Tap "Videos" filter
      await tester.tap(find.widgetWithText(AppFilterChip, 'Videos'));
      await tester.pumpAndSettle();

      // Only 1 video in default fake data
      expect(find.byType(MediaTile), findsOneWidget);

      // Select All selects only visible items (the 1 video)
      await tester.tap(find.byTooltip('Select all'));
      await tester.pumpAndSettle();

      expect(find.text('1 items • 150.0 MB'), findsOneWidget);
    });

    testWidgets('sorting opens sort sheet and allows selecting sort order',
        (tester) async {
      final ds = FakeCategoryDataSource();
      await tester.pumpWidget(_buildTestApp(
        dataSource: ds,
        initialViewMode: CategoryViewMode.list,
      ));
      await tester.pumpAndSettle();

      // Tap Sort button
      await tester.tap(find.byTooltip('Sort items'));
      await tester.pumpAndSettle();

      expect(find.text('Sort by'), findsOneWidget);
      expect(find.text('Largest first'), findsOneWidget);

      // Select Largest first
      await tester.tap(find.text('Largest first'));
      await tester.pumpAndSettle();

      // List is now sorted by size descending (largest: VID-20240916-WA0002.mp4, 150 MB)
      final firstRow = find.byType(MediaListRow).first;
      expect(
        find.descendant(of: firstRow, matching: find.text('VID-20240916-WA0002.mp4')),
        findsOneWidget,
      );
    });

    testWidgets('action bar: delete triggers confirmation sheet and calls onDelete',
        (tester) async {
      final ds = FakeCategoryDataSource();
      var deleteCalled = false;
      List<CategoryItem>? deletedItems;

      await tester.pumpWidget(_buildTestApp(
        dataSource: ds,
        onDelete: (items) {
          deleteCalled = true;
          deletedItems = items;
        },
      ));
      await tester.pumpAndSettle();

      // Select all items
      await tester.tap(find.byTooltip('Select all'));
      await tester.pumpAndSettle();

      // Tap Delete in BottomActionBar
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      // Confirmation sheet appears (P-02)
      expect(find.byType(ConfirmationSheet), findsOneWidget);
      expect(find.text('Delete 5 items?'), findsOneWidget);

      // Confirm delete using SecondaryButton
      await tester.tap(find.widgetWithText(SecondaryButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(deleteCalled, isTrue);
      expect(deletedItems?.length, 5);
      // Screen reflects deletion with empty state
      expect(find.byType(EmptyState), findsOneWidget);
    });

    testWidgets('empty data source renders EmptyState', (tester) async {
      final ds = FakeCategoryDataSource(items: []);
      await tester.pumpWidget(_buildTestApp(dataSource: ds));
      await tester.pumpAndSettle();

      expect(find.byType(EmptyState), findsOneWidget);
      expect(find.text('No media found'), findsOneWidget);
    });
  });
}
