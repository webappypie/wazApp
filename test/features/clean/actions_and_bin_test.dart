// test/features/clean/actions_and_bin_test.dart
//
// Tests for Phase 7 — Actions and Bin
// (REQ-ACT-01 to REQ-ACT-07, REQ-BIN-01 to REQ-BIN-05).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wapptidy/core/design/tokens.dart';
import 'package:wapptidy/core/di/providers.dart';
import 'package:wapptidy/core/services/ads/fake_ads_service.dart';
import 'package:wapptidy/core/services/media_access/fake_media_access_service.dart';
import 'package:wapptidy/core/services/media_access/media_item.dart';
import 'package:wapptidy/core/services/purchases/fake_purchase_service.dart';
import 'package:wapptidy/core/widgets/action_widgets.dart';
import 'package:wapptidy/core/widgets/buttons.dart';
import 'package:wapptidy/features/bin/presentation/bin_screen.dart';
import 'package:wapptidy/features/clean/data/fake_category_data_source.dart';
import 'package:wapptidy/features/clean/data/media_action_coordinator.dart';
import 'package:wapptidy/features/clean/domain/action_models.dart';
import 'package:wapptidy/features/clean/domain/category_models.dart';
import 'package:wapptidy/features/clean/presentation/category_screen.dart';
import 'package:wapptidy/features/clean/presentation/cleanup_success_screen.dart';

Widget _wrapWithScope(
  Widget child, {
  FakeMediaAccessService? fakeMediaAccess,
  FakeAdsService? fakeAds,
  FakePurchaseService? fakePurchases,
}) {
  return ProviderScope(
    overrides: [
      if (fakeMediaAccess != null)
        mediaAccessServiceProvider.overrideWithValue(fakeMediaAccess),
      if (fakeAds != null)
        adsServiceProvider.overrideWithValue(fakeAds),
      if (fakePurchases != null)
        purchaseServiceProvider.overrideWithValue(fakePurchases),
    ],
    child: MaterialApp(
      theme: AppTheme.light(),
      home: child,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ---------------------------------------------------------------------------
  // 1. REQ-ACT-03 & REQ-ACT-04: Safe Move / Copy with Byte Verification
  // ---------------------------------------------------------------------------
  group('REQ-ACT-03 & 04: Move/Copy Byte Verification & Failure Handling', () {
    test('Move writes to destination first; verified byte match removes source', () async {
      final fakeMedia = FakeMediaAccessService();
      const sampleItem = MediaItem(
        mediaId: 101,
        contentUri: 'content://media/101',
        mimeType: 'image/jpeg',
        sizeBytes: 2048,
        dateAddedEpochSec: 1000,
        dateModifiedEpochSec: 1000,
        folderBucket: 'WhatsApp Images',
        source: MediaSource.whatsApp,
      );
      fakeMedia.items = [sampleItem];

      final coordinator = MediaActionCoordinator(mediaAccessService: fakeMedia);
      const catItem = CategoryItem(
        id: '101',
        contentUri: 'content://media/101',
        displayName: 'photo.jpg',
        mimeType: 'image/jpeg',
        sizeBytes: 2048,
        dateAddedSec: 1000,
        dateModifiedSec: 1000,
        bucketName: 'WhatsApp Images',
        sourceApp: 'com.whatsapp',
      );

      final result = await coordinator.moveOrCopySelected(
        items: [catItem],
        isMove: true,
      );

      expect(result.isSuccess, isTrue);
      expect(result.succeededIds, contains('101'));
      expect(result.totalBytesProcessed, 2048);
      // Verified write succeeded -> source removed from items
      expect(fakeMedia.items.any((it) => it.mediaId == 101), isFalse);
      expect(fakeMedia.movedItems.any((it) => it.mediaId == 101), isTrue);
    });

    test('REQ-ACT-03: Destination write failure (byte mismatch) leaves source UNTOUCHED', () async {
      final fakeMedia = FakeMediaAccessService()..simulateWriteFailure = true;
      const sampleItem = MediaItem(
        mediaId: 102,
        contentUri: 'content://media/102',
        mimeType: 'video/mp4',
        sizeBytes: 50000000,
        dateAddedEpochSec: 2000,
        dateModifiedEpochSec: 2000,
        folderBucket: 'WhatsApp Video',
        source: MediaSource.whatsApp,
      );
      fakeMedia.items = [sampleItem];

      final coordinator = MediaActionCoordinator(mediaAccessService: fakeMedia);
      const catItem = CategoryItem(
        id: '102',
        contentUri: 'content://media/102',
        displayName: 'video.mp4',
        mimeType: 'video/mp4',
        sizeBytes: 50000000,
        dateAddedSec: 2000,
        dateModifiedSec: 2000,
        bucketName: 'WhatsApp Video',
        sourceApp: 'com.whatsapp',
      );

      final result = await coordinator.moveOrCopySelected(
        items: [catItem],
        isMove: true,
      );

      expect(result.isSuccess, isFalse);
      expect(result.failedIds, contains('102'));
      // SOURCE UNTOUCHED!
      expect(fakeMedia.items.length, 1);
      expect(fakeMedia.items.first.mediaId, 102);
      expect(fakeMedia.movedItems, isEmpty);
    });

    test('REQ-ACT-04: Partial batch failure provides per-file failure summary', () async {
      final fakeMedia = FakeMediaAccessService()..simulatePartialFailure = true;
      final coordinator = MediaActionCoordinator(mediaAccessService: fakeMedia);

      final items = [
        const CategoryItem(
          id: '1',
          contentUri: 'content://media/1',
          displayName: 'img1.jpg',
          mimeType: 'image/jpeg',
          sizeBytes: 1000,
          dateAddedSec: 100,
          dateModifiedSec: 100,
          bucketName: 'b',
          sourceApp: 'com.whatsapp',
        ),
        const CategoryItem(
          id: '2',
          contentUri: 'content://media/2',
          displayName: 'img2.jpg',
          mimeType: 'image/jpeg',
          sizeBytes: 2000,
          dateAddedSec: 100,
          dateModifiedSec: 100,
          bucketName: 'b',
          sourceApp: 'com.whatsapp',
        ),
      ];

      final result = await coordinator.moveOrCopySelected(items: items, isMove: false);

      expect(result.succeededCount, 1);
      expect(result.failedCount, 1);
      expect(result.succeededIds, contains('1'));
      expect(result.failedIds, contains('2'));
      expect(result.failureReasons['2'], contains('Storage full'));
    });
  });

  // ---------------------------------------------------------------------------
  // 2. REQ-ACT-05: Protect / Keep-forever Guard
  // ---------------------------------------------------------------------------
  group('REQ-ACT-05: Protect / Keep-Forever Rules', () {
    test('Deleting a protected file throws ProtectedFileException', () async {
      final fakeMedia = FakeMediaAccessService();
      final coordinator = MediaActionCoordinator(mediaAccessService: fakeMedia);

      const protectedItem = CategoryItem(
        id: 'p1',
        contentUri: 'content://media/p1',
        displayName: 'precious_photo.jpg',
        mimeType: 'image/jpeg',
        sizeBytes: 1024,
        dateAddedSec: 100,
        dateModifiedSec: 100,
        bucketName: 'b',
        sourceApp: 'com.whatsapp',
        isProtected: true,
      );

      expect(
        () => coordinator.trashSelected([protectedItem]),
        throwsA(isA<ProtectedFileException>()),
      );
      expect(
        () => coordinator.deletePermanentlySelected([protectedItem]),
        throwsA(isA<ProtectedFileException>()),
      );
    });

    testWidgets('CategoryScreen blocks delete when protected item is selected', (tester) async {
      final fakeMedia = FakeMediaAccessService();
      const item = CategoryItem(
        id: 'p1',
        contentUri: 'content://media/p1',
        displayName: 'precious_photo.jpg',
        mimeType: 'image/jpeg',
        sizeBytes: 1024,
        dateAddedSec: 100,
        dateModifiedSec: 100,
        bucketName: 'b',
        sourceApp: 'com.whatsapp',
        isProtected: true,
      );

      final ds = FakeCategoryDataSource(items: [item]);

      await tester.pumpWidget(
        _wrapWithScope(
          CategoryScreen(
            title: 'Protected Test',
            dataSource: ds,
            initialSelectedIdsBuilder: (_) => {'p1'},
          ),
          fakeMediaAccess: fakeMedia,
        ),
      );
      await tester.pumpAndSettle();

      // Tap Delete in BottomActionBar
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      // ConfirmationSheet NOT shown; snackbar warning displayed
      expect(find.byType(ConfirmationSheet), findsNothing);
      expect(find.textContaining('Protected items cannot be deleted'), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // 3. REQ-ACT-01 & REQ-BIN-04: ConfirmationSheet & OS Destination Warning
  // ---------------------------------------------------------------------------
  group('REQ-ACT-01, 02 & REQ-BIN-04: Confirmation Sheet & OS Awareness', () {
    testWidgets('Android 11+ shows Recycle Bin destination in ConfirmationSheet', (tester) async {
      final fakeMedia = FakeMediaAccessService()..simulatedApiLevel = 33;
      const item = CategoryItem(
        id: 'u1',
        contentUri: 'content://media/u1',
        displayName: 'temp.jpg',
        mimeType: 'image/jpeg',
        sizeBytes: 1024 * 1024,
        dateAddedSec: 100,
        dateModifiedSec: 100,
        bucketName: 'b',
        sourceApp: 'com.whatsapp',
        isProtected: false,
      );

      final ds = FakeCategoryDataSource(items: [item]);

      await tester.pumpWidget(
        _wrapWithScope(
          CategoryScreen(
            title: 'Trash Test',
            dataSource: ds,
            initialSelectedIdsBuilder: (_) => {'u1'},
          ),
          fakeMediaAccess: fakeMedia,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(find.byType(ConfirmationSheet), findsOneWidget);
      expect(find.textContaining('Move 1 items to Recycle Bin?'), findsOneWidget);
      expect(find.textContaining('after ~30 days'), findsOneWidget);
    });

    testWidgets('Android <= 10 shows Permanent Deletion warning in ConfirmationSheet', (tester) async {
      final fakeMedia = FakeMediaAccessService()..simulatedApiLevel = 29;
      const item = CategoryItem(
        id: 'u2',
        contentUri: 'content://media/u2',
        displayName: 'temp_legacy.jpg',
        mimeType: 'image/jpeg',
        sizeBytes: 1024 * 1024,
        dateAddedSec: 100,
        dateModifiedSec: 100,
        bucketName: 'b',
        sourceApp: 'com.whatsapp',
        isProtected: false,
      );

      final ds = FakeCategoryDataSource(items: [item]);

      await tester.pumpWidget(
        _wrapWithScope(
          CategoryScreen(
            title: 'Legacy Delete Test',
            dataSource: ds,
            initialSelectedIdsBuilder: (_) => {'u2'},
          ),
          fakeMediaAccess: fakeMedia,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(find.byType(ConfirmationSheet), findsOneWidget);
      expect(find.textContaining('Permanently delete 1 items?'), findsOneWidget);
      expect(find.textContaining('This deletion is permanent! Your device version does not support a Recycle Bin'), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // 4. REQ-ACT-07: Cleanup Success Screen
  // ---------------------------------------------------------------------------
  group('REQ-ACT-07: CleanupSuccessScreen', () {
    testWidgets('Displays recovered space, breakdown, and Done/Bin CTAs', (tester) async {
      const summary = CleanupSessionSummary(
        recoveredBytes: 1500 * 1024 * 1024, // 1.5 GB
        reviewedCount: 45,
        removedCount: 30,
        movedCount: 15,
        protectedCount: 2,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const CleanupSuccessScreen(summary: summary),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Storage Cleaned!'), findsOneWidget);
      expect(find.text('1.5 GB recovered'), findsOneWidget);
      expect(find.text('45'), findsOneWidget);
      expect(find.text('30'), findsOneWidget);
      expect(find.text('15'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);

      expect(find.text('View Recycle Bin'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // 5. REQ-BIN-01 to REQ-BIN-05: Recycle Bin Screen
  // ---------------------------------------------------------------------------
  group('REQ-BIN: Recycle Bin Screen', () {
    testWidgets('Groups items by Today, Yesterday, This Week, Older and shows retention notice', (tester) async {
      final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final fakeMedia = FakeMediaAccessService()..simulatedApiLevel = 33;
      fakeMedia.trashedItems = [
        MediaItem(
          mediaId: 1,
          contentUri: 'content://media/t1',
          mimeType: 'image/jpeg',
          sizeBytes: 1024 * 1024,
          dateAddedEpochSec: nowSec - 600,
          dateModifiedEpochSec: nowSec - 600, // Today
          folderBucket: 'WhatsApp Images',
          source: MediaSource.whatsApp,
        ),
        MediaItem(
          mediaId: 2,
          contentUri: 'content://media/t2',
          mimeType: 'image/jpeg',
          sizeBytes: 2 * 1024 * 1024,
          dateAddedEpochSec: nowSec - 90000,
          dateModifiedEpochSec: nowSec - 90000, // Yesterday
          folderBucket: 'WhatsApp Images',
          source: MediaSource.whatsApp,
        ),
      ];

      await tester.pumpWidget(
        _wrapWithScope(
          const BinScreen(apiLevelOverride: 33),
          fakeMediaAccess: fakeMedia,
        ),
      );
      await tester.pumpAndSettle();

      // REQ-BIN-05: Honest retention notice
      expect(
        find.textContaining('Items in the Recycle Bin are permanently deleted by Android after approximately 30 days.'),
        findsOneWidget,
      );

      // REQ-BIN-01: Group titles
      expect(find.text('Today'), findsOneWidget);
      expect(find.text('Yesterday'), findsOneWidget);
    });

    testWidgets('REQ-BIN-03: Restore works EVEN WHEN ads and purchases are in blocking state (P-05)', (tester) async {
      final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final fakeMedia = FakeMediaAccessService()..simulatedApiLevel = 33;
      fakeMedia.trashedItems = [
        MediaItem(
          mediaId: 99,
          contentUri: 'content://media/t99',
          mimeType: 'image/jpeg',
          sizeBytes: 1024 * 1024,
          dateAddedEpochSec: nowSec,
          dateModifiedEpochSec: nowSec,
          folderBucket: 'WhatsApp Images',
          source: MediaSource.whatsApp,
        ),
      ];

      // Force ads and purchase services into error/blocking states
      final fakeAds = FakeAdsService();
      final fakePurchases = FakePurchaseService();

      await tester.pumpWidget(
        _wrapWithScope(
          const BinScreen(apiLevelOverride: 33),
          fakeMediaAccess: fakeMedia,
          fakeAds: fakeAds,
          fakePurchases: fakePurchases,
        ),
      );
      await tester.pumpAndSettle();

      // Select the item
      await tester.tap(find.text('t99'));
      await tester.pumpAndSettle();

      // Restore button is visible and active
      final restoreBtn = find.widgetWithText(SecondaryButton, 'Restore');
      expect(restoreBtn, findsOneWidget);

      // Tap restore
      await tester.tap(restoreBtn);
      await tester.pumpAndSettle();

      // REQ-BIN-03: Item restored safely to library without prompt or barrier
      expect(fakeMedia.trashedItems, isEmpty);
      expect(fakeMedia.items.any((it) => it.mediaId == 99), isTrue);
      expect(find.textContaining('Restored 1 items'), findsOneWidget);
    });

    testWidgets('REQ-BIN-04: Android <= 10 displays permanent deletion notice in Bin', (tester) async {
      final fakeMedia = FakeMediaAccessService()..simulatedApiLevel = 28;

      await tester.pumpWidget(
        _wrapWithScope(
          const BinScreen(apiLevelOverride: 28),
          fakeMediaAccess: fakeMedia,
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Your device (Android 10 or earlier) does not support a Recycle Bin. Deletions on this device are permanent.'),
        findsOneWidget,
      );
      expect(find.text('No Recycle Bin'), findsOneWidget);
    });
  });
}
