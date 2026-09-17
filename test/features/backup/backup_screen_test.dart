// test/features/backup/backup_screen_test.dart
//
// Widget tests for BackupScreen (REQ-BAK-01..03, P-01..03).

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wapptidy/core/database/app_database.dart';
import 'package:wapptidy/core/design/tokens.dart';
import 'package:wapptidy/core/di/providers.dart';
import 'package:wapptidy/core/services/backup/fake_cloud_backup_service.dart';
import 'package:wapptidy/features/backup/presentation/backup_screen.dart';

void main() {
  late AppDatabase db;
  late FakeCloudBackupService fakeBackupService;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    fakeBackupService = FakeCloudBackupService();

    // Populate some sample media
    await db.into(db.mediaItems).insert(
          MediaItemsCompanion.insert(
            contentUri: 'content://media/1',
            mediaStoreId: '1',
            displayName: 'video_large.mp4',
            mimeType: 'video/mp4',
            sizeBytes: 60 * 1024 * 1024,
            dateAddedSec: 1700000000,
            dateModifiedSec: 1700000000,
            bucketName: 'WhatsApp Video',
            sourceApp: 'com.whatsapp',
            scanVersion: 1,
          ),
        );
    await db.into(db.mediaItems).insert(
          MediaItemsCompanion.insert(
            contentUri: 'content://media/2',
            mediaStoreId: '2',
            displayName: 'photo.jpg',
            mimeType: 'image/jpeg',
            sizeBytes: 2 * 1024 * 1024,
            dateAddedSec: 1700000000,
            dateModifiedSec: 1700000000,
            bucketName: 'WhatsApp Images',
            sourceApp: 'com.whatsapp',
            scanVersion: 1,
          ),
        );
  });

  tearDown(() async {
    fakeBackupService.dispose();
    await db.close();
  });

  Widget buildTestWidget({FakeCloudBackupService? customService}) {
    final serviceToUse = customService ?? fakeBackupService;
    return ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        cloudBackupServiceProvider.overrideWithValue(serviceToUse),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: const BackupScreen(),
      ),
    );
  }

  testWidgets('BackupScreen displays Google Drive privacy notice (REQ-BAK-01)',
      (tester) async {
    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    expect(find.text('Google Drive Backup'), findsOneWidget);
    expect(find.text('Google Drive Disconnected'), findsOneWidget);
    expect(find.text('Connect'), findsOneWidget);

    // Verifies REQ-BAK-01 drive.file scope privacy text
    expect(
      find.textContaining('drive.file scope only', findRichText: true),
      findsOneWidget,
    );
  });

  testWidgets('Connecting to Google Drive updates account tile', (tester) async {
    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Connect'));
    await tester.pumpAndSettle();

    expect(find.text('Google Drive Connected'), findsOneWidget);
    expect(find.text('user@gmail.com'), findsOneWidget);
    expect(find.text('Disconnect'), findsOneWidget);
  });

  testWidgets('Candidate items are summarized and Start Backup triggers upload',
      (tester) async {
    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    // Connect first
    await tester.tap(find.text('Connect'));
    await tester.pumpAndSettle();

    // Verify candidate summary
    expect(find.text('Select Media to Back Up'), findsOneWidget);
    expect(find.textContaining('2 items'), findsOneWidget);
    expect(find.text('Start Backup'), findsOneWidget);

    // Tap Start Backup
    await tester.tap(find.text('Start Backup'));
    await tester.pumpAndSettle();

    // Verify completion
    expect(find.text('Backup Complete!'), findsOneWidget);
  });

  testWidgets(
      'REQ-BAK-03: Post-backup CTA reads "Review originals" and never "Delete originals"',
      (tester) async {
    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    // Connect & start
    await tester.tap(find.text('Connect'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start Backup'));
    await tester.pumpAndSettle();

    // STRICT REQ-BAK-03 verification
    expect(find.text('Review originals'), findsOneWidget);
    expect(find.byKey(const Key('review_originals_button')), findsOneWidget);
    expect(find.text('Delete originals'), findsNothing);
    expect(find.textContaining('Delete'), findsNothing);

    // Local files preserved statement
    expect(
      find.textContaining('never auto-deletes media after backup'),
      findsOneWidget,
    );

    // Tap Review originals
    await tester.tap(find.byKey(const Key('review_originals_button')));
    await tester.pumpAndSettle();
  });

  testWidgets('REQ-BAK-02: Failed items display retry button', (tester) async {
    fakeBackupService.shouldFailItem = (item) => item.id == 1;

    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    // Connect & start
    await tester.tap(find.text('Connect'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start Backup'));
    await tester.pumpAndSettle();

    // Verify failed section and retry button (REQ-BAK-02)
    expect(find.text('1 items failed to upload'), findsOneWidget);
    expect(find.text('Retry Failed'), findsOneWidget);

    // Clear failure condition and tap retry
    fakeBackupService.shouldFailItem = null;
    await tester.tap(find.text('Retry Failed'));
    await tester.pumpAndSettle();

    // Complete successfully
    expect(find.text('Backup Complete!'), findsOneWidget);
    expect(find.text('Review originals'), findsOneWidget);
  });
}
