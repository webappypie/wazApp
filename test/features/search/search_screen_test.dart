// test/features/search/search_screen_test.dart
//
// Verification for Global Search Screen across dual media sources (REQ-11):
// - Cross-app querying across WhatsApp and WhatsApp Business.
// - Filter by Source (All / WhatsApp / Business).
// - Filter by Media Type (All / Images / Videos / Audio / Documents).

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wapptidy/core/database/app_database.dart';
import 'package:wapptidy/core/design/tokens.dart';
import 'package:wapptidy/core/di/providers.dart';
import 'package:wapptidy/core/services/installed_apps/installed_apps_service.dart';
import 'package:wapptidy/core/services/media_access/fake_media_access_service.dart';
import 'package:wapptidy/core/widgets/search_field.dart';
import 'package:wapptidy/features/clean/data/media_action_coordinator.dart';
import 'package:wapptidy/features/search/presentation/search_screen.dart';

void main() {
  late AppDatabase db;
  late FakeMediaAccessService fakeMedia;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    fakeMedia = FakeMediaAccessService();

    // Insert sample items across both WhatsApp and WhatsApp Business
    await db.into(db.mediaItems).insert(
          MediaItemsCompanion.insert(
            contentUri: 'content://media/1',
            mediaStoreId: '1',
            displayName: 'client_invoice_wa.pdf',
            mimeType: 'application/pdf',
            sizeBytes: 1024 * 1024,
            dateAddedSec: 1000,
            dateModifiedSec: 1000,
            bucketName: 'WhatsApp Documents',
            sourceApp: 'com.whatsapp',
            scanVersion: 1,
          ),
        );

    await db.into(db.mediaItems).insert(
          MediaItemsCompanion.insert(
            contentUri: 'content://media/2',
            mediaStoreId: '2',
            displayName: 'client_invoice_biz.pdf',
            mimeType: 'application/pdf',
            sizeBytes: 2 * 1024 * 1024,
            dateAddedSec: 2000,
            dateModifiedSec: 2000,
            bucketName: 'WhatsApp Business Documents',
            sourceApp: 'com.whatsapp.w4b',
            scanVersion: 1,
          ),
        );

    await db.into(db.mediaItems).insert(
          MediaItemsCompanion.insert(
            contentUri: 'content://media/3',
            mediaStoreId: '3',
            displayName: 'product_catalog.jpg',
            mimeType: 'image/jpeg',
            sizeBytes: 512 * 1024,
            dateAddedSec: 3000,
            dateModifiedSec: 3000,
            bucketName: 'WhatsApp Business Images',
            sourceApp: 'com.whatsapp.w4b',
            scanVersion: 1,
          ),
        );
  });

  tearDown(() async {
    await db.close();
  });

  Widget buildSearchScreen() {
    return ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        mediaAccessServiceProvider.overrideWithValue(fakeMedia),
        mediaActionCoordinatorProvider.overrideWithValue(
          MediaActionCoordinator(mediaAccessService: fakeMedia, db: db),
        ),
        installedAppsServiceProvider.overrideWithValue(
          FakeInstalledAppsService(installedSources: InstalledSources.both),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: const SearchScreen(),
      ),
    );
  }

  group('Global Search across Dual Media Sources (REQ-11)', () {
    testWidgets('Search query returns matching items across both WhatsApp and Business', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildSearchScreen());
      await tester.pumpAndSettle();

      // Enter search query 'invoice'
      final searchInput = find.byType(SearchField);
      expect(searchInput, findsOneWidget);

      await tester.enterText(searchInput, 'invoice');
      await tester.pumpAndSettle();

      // Both WhatsApp and WhatsApp Business invoices should be displayed
      expect(find.text('client_invoice_wa.pdf'), findsOneWidget);
      expect(find.text('client_invoice_biz.pdf'), findsOneWidget);
      expect(find.text('product_catalog.jpg'), findsNothing);
    });

    testWidgets('Filtering by WhatsApp source limits results to WhatsApp only', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildSearchScreen());
      await tester.pumpAndSettle();

      // Enter search query 'invoice'
      final searchInput = find.byType(SearchField);
      await tester.enterText(searchInput, 'invoice');
      await tester.pumpAndSettle();

      expect(find.text('client_invoice_wa.pdf'), findsOneWidget);
      expect(find.text('client_invoice_biz.pdf'), findsOneWidget);

      // Tap 'WhatsApp' in SourceFilterBar
      final waSegment = find.text('WhatsApp');
      expect(waSegment, findsOneWidget);
      await tester.tap(waSegment);
      await tester.pumpAndSettle();

      // Only WhatsApp item should be visible now
      expect(find.text('client_invoice_wa.pdf'), findsOneWidget);
      expect(find.text('client_invoice_biz.pdf'), findsNothing);

      // Tap 'Business' in SourceFilterBar
      final bizSegment = find.text('Business');
      expect(bizSegment, findsOneWidget);
      await tester.tap(bizSegment);
      await tester.pumpAndSettle();

      // Only Business item should be visible now
      expect(find.text('client_invoice_wa.pdf'), findsNothing);
      expect(find.text('client_invoice_biz.pdf'), findsOneWidget);
    });

    testWidgets('Filtering by media type limits results to chosen type', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildSearchScreen());
      await tester.pumpAndSettle();

      // Enter search query 'catalog'
      final searchInput = find.byType(SearchField);
      await tester.enterText(searchInput, 'catalog');
      await tester.pumpAndSettle();

      expect(find.text('product_catalog.jpg'), findsOneWidget);

      // Filter by Documents -> should find 0
      final docsFilter = find.widgetWithText(FilterChip, 'Documents');
      expect(docsFilter, findsOneWidget);
      await tester.tap(docsFilter);
      await tester.pumpAndSettle();

      expect(find.text('product_catalog.jpg'), findsNothing);

      // Filter by Images -> should find 1
      final imagesFilter = find.widgetWithText(FilterChip, 'Images');
      expect(imagesFilter, findsOneWidget);
      await tester.tap(imagesFilter);
      await tester.pumpAndSettle();

      expect(find.text('product_catalog.jpg'), findsOneWidget);
    });
  });
}
