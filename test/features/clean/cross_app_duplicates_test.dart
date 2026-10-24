// test/features/clean/cross_app_duplicates_test.dart
//
// Verification for Cross-App Duplicate Detection & Safety Rules:
// 1. Intra-app duplicates pre-select non-original copies.
// 2. Cross-app duplicates NEVER auto-preselect any copy so users choose explicitly.
// 3. Header banner displays safety disclaimer when cross-app duplicates exist.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wapptidy/core/design/tokens.dart';
import 'package:wapptidy/core/di/providers.dart';
import 'package:wapptidy/core/services/media_access/fake_media_access_service.dart';
import 'package:wapptidy/features/clean/data/duplicates_data_source.dart';
import 'package:wapptidy/features/clean/data/media_action_coordinator.dart';
import 'package:wapptidy/features/clean/domain/category_models.dart';
import 'package:wapptidy/features/clean/presentation/duplicates_screen.dart';

void main() {
  Widget wrapWithApp(Widget screen) {
    final fakeMedia = FakeMediaAccessService();
    return ProviderScope(
      overrides: [
        mediaAccessServiceProvider.overrideWithValue(fakeMedia),
        mediaActionCoordinatorProvider.overrideWithValue(
          MediaActionCoordinator(mediaAccessService: fakeMedia),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: screen,
      ),
    );
  }

  group('Cross-App Duplicates Safety Rule', () {
    test('Intra-app duplicate group marks isCrossApp=false, cross-app group marks isCrossApp=true', () async {
      final items = [
        // Group 1: Intra-app (both WhatsApp)
        const CategoryItem(
          id: 'wa_orig',
          contentUri: 'content://media/1',
          displayName: 'img1.jpg',
          mimeType: 'image/jpeg',
          sizeBytes: 1024 * 1024,
          dateAddedSec: 100,
          dateModifiedSec: 100,
          bucketName: 'WhatsApp Images',
          sourceApp: 'com.whatsapp',
        ),
        const CategoryItem(
          id: 'wa_copy',
          contentUri: 'content://media/2',
          displayName: 'img1_copy.jpg',
          mimeType: 'image/jpeg',
          sizeBytes: 1024 * 1024,
          dateAddedSec: 200,
          dateModifiedSec: 200,
          bucketName: 'WhatsApp Images',
          sourceApp: 'com.whatsapp',
        ),
        // Group 2: Cross-app (WhatsApp + WhatsApp Business)
        const CategoryItem(
          id: 'cross_wa',
          contentUri: 'content://media/3',
          displayName: 'catalog.pdf',
          mimeType: 'application/pdf',
          sizeBytes: 2 * 1024 * 1024,
          dateAddedSec: 300,
          dateModifiedSec: 300,
          bucketName: 'WhatsApp Documents',
          sourceApp: 'com.whatsapp',
        ),
        const CategoryItem(
          id: 'cross_w4b',
          contentUri: 'content://media/4',
          displayName: 'catalog_biz.pdf',
          mimeType: 'application/pdf',
          sizeBytes: 2 * 1024 * 1024,
          dateAddedSec: 400,
          dateModifiedSec: 400,
          bucketName: 'WhatsApp Business Documents',
          sourceApp: 'com.whatsapp.w4b',
        ),
      ];

      final ds = DuplicatesDataSource(testItems: items);
      final result = await ds.getItems();

      expect(result.length, 4);

      final intraOrig = result.firstWhere((i) => i.id == 'wa_orig');
      final intraCopy = result.firstWhere((i) => i.id == 'wa_copy');
      expect(intraOrig.isCrossApp, isFalse);
      expect(intraCopy.isCrossApp, isFalse);
      expect(intraOrig.isOriginal, isTrue);
      expect(intraCopy.isOriginal, isFalse);

      final crossOrig = result.firstWhere((i) => i.id == 'cross_wa');
      final crossCopy = result.firstWhere((i) => i.id == 'cross_w4b');
      expect(crossOrig.isCrossApp, isTrue);
      expect(crossCopy.isCrossApp, isTrue);
      expect(crossOrig.groupTitle, contains('Cross-App'));
    });

    testWidgets('DuplicatesScreen pre-selects intra-app duplicate but NEVER cross-app duplicate', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final items = [
        // Group 1: Intra-app (WhatsApp only) -> copy should be pre-selected (1 MB)
        const CategoryItem(
          id: 'wa_orig',
          contentUri: 'content://media/1',
          displayName: 'photo1.jpg',
          mimeType: 'image/jpeg',
          sizeBytes: 1024 * 1024,
          dateAddedSec: 100,
          dateModifiedSec: 100,
          bucketName: 'WhatsApp Images',
          sourceApp: 'com.whatsapp',
        ),
        const CategoryItem(
          id: 'wa_copy',
          contentUri: 'content://media/2',
          displayName: 'photo1_copy.jpg',
          mimeType: 'image/jpeg',
          sizeBytes: 1024 * 1024,
          dateAddedSec: 200,
          dateModifiedSec: 200,
          bucketName: 'WhatsApp Images',
          sourceApp: 'com.whatsapp',
        ),
        // Group 2: Cross-app (WhatsApp + Business) -> neither should be pre-selected!
        const CategoryItem(
          id: 'cross_wa',
          contentUri: 'content://media/3',
          displayName: 'contract.pdf',
          mimeType: 'application/pdf',
          sizeBytes: 5 * 1024 * 1024,
          dateAddedSec: 300,
          dateModifiedSec: 300,
          bucketName: 'WhatsApp Documents',
          sourceApp: 'com.whatsapp',
        ),
        const CategoryItem(
          id: 'cross_w4b',
          contentUri: 'content://media/4',
          displayName: 'contract_biz.pdf',
          mimeType: 'application/pdf',
          sizeBytes: 5 * 1024 * 1024,
          dateAddedSec: 400,
          dateModifiedSec: 400,
          bucketName: 'WhatsApp Business Documents',
          sourceApp: 'com.whatsapp.w4b',
        ),
      ];

      final ds = DuplicatesDataSource(testItems: items);

      await tester.pumpWidget(wrapWithApp(DuplicatesScreen(dataSourceOverride: ds)));
      await tester.pumpAndSettle();

      // Exactly 1 item selected: wa_copy (1 MB). The 5 MB cross-app copy is NOT preselected!
      expect(find.text('1 items • 1.0 MB'), findsOneWidget);

      // Potential savings is 1 MB + 5 MB = 6 MB
      expect(find.textContaining('Potential Saving: 6.0 MB'), findsOneWidget);

      // Cross-app safety warning banner is displayed
      expect(find.textContaining('Cross-app copies require manual selection to protect work/personal files'), findsOneWidget);
    });
  });
}
