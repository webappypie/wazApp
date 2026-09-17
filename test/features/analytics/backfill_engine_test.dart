// test/features/analytics/backfill_engine_test.dart
//
// Verification for the historical backfill engine (REQ-ANL-01, REQ-ANL-02, P-03).

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wapptidy/core/database/app_database.dart';
import 'package:wapptidy/features/analytics/data/analytics_repository.dart';
import 'package:wapptidy/features/analytics/domain/analytics_models.dart';

void main() {
  late AppDatabase db;
  late AnalyticsRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = AnalyticsRepository(database: db);
  });

  tearDown(() async {
    await db.close();
  });

  group('REQ-ANL-02: Cold-Start Historical Backfill Engine', () {
    test('Backfill reconstructs cumulative storage progression from media timestamps', () async {
      final now = DateTime.now();
      final todayEpochDay = now.millisecondsSinceEpoch ~/ (86400 * 1000);

      // Seed media items spread across 3 distinct days:
      // Day 1: 5 days ago -> 100MB video + 50MB image = 150MB
      final day1Sec = (todayEpochDay - 5) * 86400 + 3600;
      await db.into(db.mediaItems).insert(
        MediaItemsCompanion.insert(
          contentUri: 'content://media/1',
          mediaStoreId: '1',
          mimeType: 'video/mp4',
          sourceApp: 'com.whatsapp',
          bucketName: 'WhatsApp Video',
          displayName: 'video_1.mp4',
          sizeBytes: 100 * 1024 * 1024,
          dateAddedSec: day1Sec,
          dateModifiedSec: day1Sec,
          scanVersion: 1,
        ),
      );
      await db.into(db.mediaItems).insert(
        MediaItemsCompanion.insert(
          contentUri: 'content://media/2',
          mediaStoreId: '2',
          mimeType: 'image/jpeg',
          sourceApp: 'com.whatsapp',
          bucketName: 'WhatsApp Images',
          displayName: 'image_1.jpg',
          sizeBytes: 50 * 1024 * 1024,
          dateAddedSec: day1Sec,
          dateModifiedSec: day1Sec,
          scanVersion: 1,
        ),
      );

      // Day 2: 3 days ago -> 200MB video = +200MB (cumulative 350MB)
      final day2Sec = (todayEpochDay - 3) * 86400 + 7200;
      await db.into(db.mediaItems).insert(
        MediaItemsCompanion.insert(
          contentUri: 'content://media/3',
          mediaStoreId: '3',
          mimeType: 'video/mp4',
          sourceApp: 'com.whatsapp',
          bucketName: 'WhatsApp Video',
          displayName: 'video_2.mp4',
          sizeBytes: 200 * 1024 * 1024,
          dateAddedSec: day2Sec,
          dateModifiedSec: day2Sec,
          scanVersion: 1,
        ),
      );

      // Day 3: Today -> 50MB audio = +50MB (cumulative 400MB)
      final day3Sec = todayEpochDay * 86400 + 100;
      await db.into(db.mediaItems).insert(
        MediaItemsCompanion.insert(
          contentUri: 'content://media/4',
          mediaStoreId: '4',
          mimeType: 'audio/ogg',
          sourceApp: 'com.whatsapp',
          bucketName: 'WhatsApp Audio',
          displayName: 'audio_1.ogg',
          sizeBytes: 50 * 1024 * 1024,
          dateAddedSec: day3Sec,
          dateModifiedSec: day3Sec,
          scanVersion: 1,
        ),
      );

      // Verify no snapshots exist prior to backfill
      expect(await db.hasStorageSnapshots(), isFalse);

      // Execute cold-start backfill (REQ-ANL-02)
      await repo.backfillFromIndex();

      expect(await db.hasStorageSnapshots(), isTrue);

      final trends = await repo.getTrends(range: TimeRange.sevenDays);

      // Must cover the range from day 1 to today
      expect(trends.snapshots.isNotEmpty, isTrue);

      final firstSnap = trends.snapshots.firstWhere((s) => s.dateEpochDay == todayEpochDay - 5);
      expect(firstSnap.totalBytes, 150 * 1024 * 1024);
      expect(firstSnap.videoBytes, 100 * 1024 * 1024);
      expect(firstSnap.imageBytes, 50 * 1024 * 1024);

      // Intermediate day without additions should preserve cumulative total
      final intermediateSnap = trends.snapshots.firstWhere((s) => s.dateEpochDay == todayEpochDay - 4);
      expect(intermediateSnap.totalBytes, 150 * 1024 * 1024);

      // Final day (today) must reach full 400MB
      final todaySnap = trends.snapshots.firstWhere((s) => s.dateEpochDay == todayEpochDay);
      expect(todaySnap.totalBytes, 400 * 1024 * 1024);
      expect(todaySnap.videoBytes, 300 * 1024 * 1024);
      expect(todaySnap.imageBytes, 50 * 1024 * 1024);
      expect(todaySnap.audioBytes, 50 * 1024 * 1024);

      // P-03 Truthful verification: currentTotalBytes exactly matches sum of files
      expect(trends.currentTotalBytes, 400 * 1024 * 1024);
    });

    test('takeCurrentSnapshot creates or refreshes today snapshot', () async {
      final now = DateTime.now();
      final todayEpochDay = now.millisecondsSinceEpoch ~/ (86400 * 1000);

      await db.into(db.mediaItems).insert(
        MediaItemsCompanion.insert(
          contentUri: 'content://media/99',
          mediaStoreId: '99',
          mimeType: 'image/jpeg',
          sourceApp: 'com.whatsapp',
          bucketName: 'WhatsApp Images',
          displayName: 'pic.jpg',
          sizeBytes: 80 * 1024 * 1024,
          dateAddedSec: todayEpochDay * 86400,
          dateModifiedSec: todayEpochDay * 86400,
          scanVersion: 1,
        ),
      );

      await repo.takeCurrentSnapshot();

      final snapshots = await db.queryStorageSnapshots(
        fromEpochDay: todayEpochDay,
        toEpochDay: todayEpochDay,
      );
      expect(snapshots.length, 1);
      expect(snapshots.first.read<int>('total_bytes'), 80 * 1024 * 1024);
      expect(snapshots.first.read<int>('image_bytes'), 80 * 1024 * 1024);
    });
  });
}
