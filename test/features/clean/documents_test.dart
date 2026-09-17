// test/features/clean/documents_test.dart
//
// Verification for DocumentsDataSource and DocumentsScreen (REQ-CLN-01, P-01).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wapptidy/core/design/tokens.dart';
import 'package:wapptidy/core/di/providers.dart';
import 'package:wapptidy/core/services/media_access/fake_media_access_service.dart';
import 'package:wapptidy/features/clean/data/documents_data_source.dart';
import 'package:wapptidy/features/clean/data/media_action_coordinator.dart';
import 'package:wapptidy/features/clean/domain/category_models.dart';
import 'package:wapptidy/features/clean/presentation/documents_screen.dart';

void main() {
  final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;

  final sampleItems = [
    CategoryItem(
      id: '1',
      contentUri: 'content://media/docs/1',
      displayName: 'Invoice_2023.pdf',
      mimeType: 'application/pdf',
      sizeBytes: 2 * 1024 * 1024,
      dateAddedSec: nowSec - 100 * 86400,
      dateModifiedSec: nowSec - 100 * 86400,
      bucketName: 'WhatsApp Documents',
      sourceApp: 'com.whatsapp',
    ),
    CategoryItem(
      id: '2',
      contentUri: 'content://media/docs/2',
      displayName: 'Report_Q3.docx',
      mimeType: 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      sizeBytes: 4 * 1024 * 1024,
      dateAddedSec: nowSec - 50 * 86400,
      dateModifiedSec: nowSec - 50 * 86400,
      bucketName: 'WhatsApp Documents',
      sourceApp: 'com.whatsapp',
    ),
    CategoryItem(
      id: '3',
      contentUri: 'content://media/docs/3',
      displayName: 'Project_Assets.zip',
      mimeType: 'application/zip',
      sizeBytes: 15 * 1024 * 1024,
      dateAddedSec: nowSec - 10 * 86400,
      dateModifiedSec: nowSec - 10 * 86400,
      bucketName: 'WhatsApp Documents',
      sourceApp: 'com.whatsapp',
    ),
    CategoryItem(
      id: '4',
      contentUri: 'content://media/image/4',
      displayName: 'photo.jpg',
      mimeType: 'image/jpeg',
      sizeBytes: 1024 * 1024,
      dateAddedSec: nowSec,
      dateModifiedSec: nowSec,
      bucketName: 'WhatsApp Images',
      sourceApp: 'com.whatsapp', // Should be excluded because it's an image
    ),
  ];

  group('DocumentsDataSource Unit Tests', () {
    test('Filters documents and classifies PDF, Office, and Archives', () async {
      final ds = DocumentsDataSource(testItems: sampleItems);
      final items = await ds.getItems();

      // Image item 4 must be excluded
      expect(items.length, 3);

      final pdf = items.firstWhere((i) => i.id == '1');
      expect(pdf.badgeLabel, 'PDF');
      expect(pdf.groupTitle, 'PDF Documents');
      expect(DocumentsDataSource.isPdf(pdf), isTrue);

      final docx = items.firstWhere((i) => i.id == '2');
      expect(docx.badgeLabel, 'DOCX');
      expect(docx.groupTitle, 'Office Documents');
      expect(DocumentsDataSource.isOfficeDoc(docx), isTrue);

      final zip = items.firstWhere((i) => i.id == '3');
      expect(zip.badgeLabel, 'ZIP');
      expect(zip.groupTitle, 'Archives');
      expect(DocumentsDataSource.isArchive(zip), isTrue);
    });
  });

  group('DocumentsScreen UI Tests', () {
    late FakeMediaAccessService fakeMedia;

    setUp(() {
      fakeMedia = FakeMediaAccessService();
    });

    Widget buildTestScreen() {
      return ProviderScope(
        overrides: [
          mediaAccessServiceProvider.overrideWithValue(fakeMedia),
          mediaActionCoordinatorProvider.overrideWithValue(
            MediaActionCoordinator(mediaAccessService: fakeMedia),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: DocumentsScreen(
            dataSourceOverride: DocumentsDataSource(testItems: sampleItems),
          ),
        ),
      );
    }

    testWidgets('Renders header, total space, and document rows with badges', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestScreen());
      await tester.pumpAndSettle();

      expect(find.text('Documents'), findsOneWidget);
      expect(find.textContaining('Total Space:'), findsOneWidget);
      expect(find.text('Invoice_2023.pdf'), findsOneWidget);
      expect(find.text('Report_Q3.docx'), findsOneWidget);
      expect(find.text('Project_Assets.zip'), findsOneWidget);
      expect(find.text('PDF'), findsOneWidget);
      expect(find.text('DOCX'), findsOneWidget);
      expect(find.text('ZIP'), findsOneWidget);
    });

    testWidgets('Tapping document opens MediaPreviewSheet with Open in System Viewer button', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestScreen());
      await tester.pumpAndSettle();

      // Tap the PDF
      await tester.tap(find.text('Invoice_2023.pdf'));
      await tester.pumpAndSettle();

      // Verify Open button
      expect(find.text('Open in System Viewer'), findsOneWidget);
      expect(find.text('PDF Document'), findsWidgets);

      // Tap Open in System Viewer
      await tester.tap(find.text('Open in System Viewer'));
      await tester.pumpAndSettle();
    });
  });
}
