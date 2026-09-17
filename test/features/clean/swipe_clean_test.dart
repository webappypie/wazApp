// test/features/clean/swipe_clean_test.dart
//
// Verification suite for Phase 12: Swipe Clean (REQ-ACT-08, REQ-SWP-01..05, REQ-ADS-05).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wapptidy/core/di/providers.dart';
import 'package:wapptidy/core/services/media_access/fake_media_access_service.dart';
import 'package:wapptidy/core/services/media_access/media_item.dart';
import 'package:wapptidy/core/widgets/action_widgets.dart';
import 'package:wapptidy/core/widgets/monetisation_widgets.dart';
import 'package:wapptidy/features/clean/data/media_action_coordinator.dart';
import 'package:wapptidy/features/clean/domain/category_models.dart';
import 'package:wapptidy/features/clean/domain/swipe_clean_models.dart';
import 'package:wapptidy/features/clean/presentation/swipe_clean_controller.dart';
import 'package:wapptidy/features/clean/presentation/swipe_clean_screen.dart';

Widget _buildTestApp({
  required List<CategoryItem> items,
  required FakeMediaAccessService fakeMediaAccess,
  bool startWithTutorial = false,
}) {
  return ProviderScope(
    overrides: [
      mediaAccessServiceProvider.overrideWithValue(fakeMediaAccess),
    ],
    child: MaterialApp(
      home: SwipeCleanScreen(
        customCandidates: items,
        startWithTutorial: startWithTutorial,
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const item1 = CategoryItem(
    id: 'item_1',
    contentUri: 'content://media/1',
    displayName: 'meme_1.jpg',
    mimeType: 'image/jpeg',
    sizeBytes: 2 * 1024 * 1024,
    dateAddedSec: 1000,
    dateModifiedSec: 1000,
    bucketName: 'WhatsApp Images',
    sourceApp: 'com.whatsapp',
  );

  const item2 = CategoryItem(
    id: 'item_2',
    contentUri: 'content://media/2',
    displayName: 'meme_2.jpg',
    mimeType: 'image/jpeg',
    sizeBytes: 3 * 1024 * 1024,
    dateAddedSec: 1000,
    dateModifiedSec: 1000,
    bucketName: 'WhatsApp Images',
    sourceApp: 'com.whatsapp',
  );

  const item3 = CategoryItem(
    id: 'item_3',
    contentUri: 'content://media/3',
    displayName: 'meme_3.jpg',
    mimeType: 'image/jpeg',
    sizeBytes: 5 * 1024 * 1024,
    dateAddedSec: 1000,
    dateModifiedSec: 1000,
    bucketName: 'WhatsApp Images',
    sourceApp: 'com.whatsapp',
  );

  group('REQ-ACT-08 & REQ-SWP-01: Swipe Actions & Controller State', () {
    test('Swiping left queues item for delete, right for keep, up for archive', () {
      final controller = SwipeCleanController(
        initialCandidates: [item1, item2, item3],
        isTutorialDismissed: true,
      );

      expect(controller.state.remainingItems.length, 3);
      expect(controller.state.currentCard?.id, 'item_1');

      // Swipe left -> delete
      controller.recordSwipe(SwipeAction.delete);
      expect(controller.state.remainingItems.length, 2);
      expect(controller.state.currentCard?.id, 'item_2');
      expect(controller.state.itemsToDelete, [item1]);
      expect(controller.state.totalDeleteBytes, 2 * 1024 * 1024);

      // Swipe right -> keep
      controller.recordSwipe(SwipeAction.keep);
      expect(controller.state.remainingItems.length, 1);
      expect(controller.state.currentCard?.id, 'item_3');
      expect(controller.state.itemsToKeep, [item2]);

      // Swipe up -> archive
      controller.recordSwipe(SwipeAction.archive);
      expect(controller.state.remainingItems, isEmpty);
      expect(controller.state.isCompleted, isTrue);
      expect(controller.state.itemsToArchive, [item3]);
    });
  });

  group('REQ-SWP-02: Undo Stack Functionality', () {
    test('Undo reverts previous decision and restores top card to deck', () {
      final controller = SwipeCleanController(
        initialCandidates: [item1, item2],
        isTutorialDismissed: true,
      );

      expect(controller.state.canUndo, isFalse);

      controller.recordSwipe(SwipeAction.delete);
      expect(controller.state.canUndo, isTrue);
      expect(controller.state.remainingItems.length, 1);
      expect(controller.state.currentCard?.id, 'item_2');

      // Undo
      controller.undo();
      expect(controller.state.canUndo, isFalse);
      expect(controller.state.remainingItems.length, 2);
      expect(controller.state.currentCard?.id, 'item_1');
      expect(controller.state.itemsToDelete, isEmpty);
    });

    test('Undo on empty history is a safe no-op', () {
      final controller = SwipeCleanController(
        initialCandidates: [item1],
        isTutorialDismissed: true,
      );

      controller.undo();
      expect(controller.state.remainingItems.length, 1);
      expect(controller.state.canUndo, isFalse);
    });
  });

  group('REQ-SWP-04: Batch Commit & Safety Invariants', () {
    test('Batch commit trashes ONLY swiped-left items via MediaActionCoordinator', () async {
      final fakeMediaAccess = FakeMediaAccessService()
        ..items.addAll([
          MediaItem(
            mediaId: 1,
            contentUri: item1.contentUri,
            mimeType: item1.mimeType,
            sizeBytes: item1.sizeBytes,
            dateAddedEpochSec: item1.dateAddedSec,
            dateModifiedEpochSec: item1.dateModifiedSec,
            folderBucket: item1.bucketName,
            source: MediaSource.whatsApp,
          ),
          MediaItem(
            mediaId: 2,
            contentUri: item2.contentUri,
            mimeType: item2.mimeType,
            sizeBytes: item2.sizeBytes,
            dateAddedEpochSec: item2.dateAddedSec,
            dateModifiedEpochSec: item2.dateModifiedSec,
            folderBucket: item2.bucketName,
            source: MediaSource.whatsApp,
          ),
        ]);

      final coordinator = MediaActionCoordinator(mediaAccessService: fakeMediaAccess);
      final controller = SwipeCleanController(
        initialCandidates: [item1, item2],
        isTutorialDismissed: true,
      );

      // item1 -> delete, item2 -> keep
      controller.recordSwipe(SwipeAction.delete);
      controller.recordSwipe(SwipeAction.keep);

      // Files are NOT deleted yet
      expect(fakeMediaAccess.trashedItems, isEmpty);

      // Commit batch
      final summary = await controller.commitBatch(coordinator);

      expect(summary.removedCount, 1);
      expect(summary.recoveredBytes, item1.sizeBytes);
      // Only item1 was trashed
      expect(fakeMediaAccess.trashedItems.map((e) => e.contentUri), [item1.contentUri]);
    });
  });

  group('REQ-ADS-05 & P-06: Ad-Free Policy Audit', () {
    testWidgets('SwipeCleanScreen has ZERO ads in the swipe sequence', (tester) async {
      final fakeMedia = FakeMediaAccessService();
      await tester.pumpWidget(_buildTestApp(
        items: [item1, item2],
        fakeMediaAccess: fakeMedia,
        startWithTutorial: false,
      ));
      await tester.pumpAndSettle();

      // Zero native ads or banners inside swipe flow (P-06)
      expect(find.byType(NativeAdContainer), findsNothing);
    });
  });

  group('UI: SwipeCleanScreen Interactions', () {
    testWidgets('Renders deck, advances on action button, undos, and shows completion', (tester) async {
      final fakeMedia = FakeMediaAccessService();

      await tester.pumpWidget(_buildTestApp(
        items: [item1, item2],
        fakeMediaAccess: fakeMedia,
        startWithTutorial: false,
      ));
      await tester.pumpAndSettle();

      // Top bar reflects remaining cards
      expect(find.text('2 items left'), findsOneWidget);
      expect(find.text('meme_1.jpg'), findsOneWidget);

      // Tap Delete (Swipe Left button)
      await tester.tap(find.byTooltip('Delete (Swipe Left)'));
      await tester.pumpAndSettle();

      // Advanced to next card
      expect(find.text('1 items left'), findsOneWidget);
      expect(find.text('meme_2.jpg'), findsOneWidget);

      // Tap Undo
      await tester.tap(find.byTooltip('Undo last swipe'));
      await tester.pumpAndSettle();

      // Reverted back to card 1
      expect(find.text('2 items left'), findsOneWidget);
      expect(find.text('meme_1.jpg'), findsOneWidget);

      // Swipe through all cards
      await tester.tap(find.byTooltip('Delete (Swipe Left)'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Keep (Swipe Right)'));
      await tester.pumpAndSettle();

      // Review complete view appears
      expect(find.text('Review Complete'), findsOneWidget);
      expect(find.text('Deck Review Complete!'), findsOneWidget);
      expect(find.textContaining('1 files (2.0 MB)'), findsOneWidget);
      expect(find.textContaining('1 files'), findsWidgets);

      // Tap Commit & Delete -> ConfirmationSheet appears
      await tester.tap(find.textContaining('Commit & Delete'));
      await tester.pumpAndSettle();

      expect(find.byType(ConfirmationSheet), findsOneWidget);
    });

    testWidgets('REQ-SWP-05: First-use tutorial overlay can be dismissed', (tester) async {
      final fakeMedia = FakeMediaAccessService();

      await tester.pumpWidget(_buildTestApp(
        items: [item1],
        fakeMediaAccess: fakeMedia,
        startWithTutorial: true,
      ));
      await tester.pumpAndSettle();

      // Tutorial overlay visible
      expect(find.text('Swipe Clean Gestures'), findsOneWidget);
      expect(find.text('Swipe Left'), findsOneWidget);
      expect(find.text('Swipe Right'), findsOneWidget);
      expect(find.text('Swipe Up'), findsOneWidget);

      // Tap Got it
      await tester.tap(find.text('Got it! Start Cleaning'));
      await tester.pumpAndSettle();

      // Tutorial dismissed, card deck visible
      expect(find.text('Swipe Clean Gestures'), findsNothing);
      expect(find.text('meme_1.jpg'), findsOneWidget);
    });
  });
}
