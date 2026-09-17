import '../../../core/database/app_database.dart';
import '../domain/analytics_models.dart';

class AnalyticsRepository {
  AnalyticsRepository({required AppDatabase database}) : _db = database;

  final AppDatabase _db;

  /// Backfill history at first launch by bucketing every indexed file by its date_added (REQ-ANL-02).
  /// Solves the cold-start problem so the growth chart is immediately populated and authentic.
  Future<void> backfillFromIndex() async {
    final allItems = await _db.select(_db.mediaItems).get();
    if (allItems.isEmpty) return;

    // Bucket delta additions by epoch day
    final Map<int, int> deltaTotal = {};
    final Map<int, int> deltaImages = {};
    final Map<int, int> deltaVideos = {};
    final Map<int, int> deltaAudio = {};
    final Map<int, int> deltaDocs = {};

    var minDay = 0x7FFFFFFF;
    final now = DateTime.now();
    final todayEpochDay = now.millisecondsSinceEpoch ~/ (86400 * 1000);

    for (final item in allItems) {
      final day = item.dateAddedSec ~/ 86400;
      if (day < minDay) minDay = day;

      deltaTotal[day] = (deltaTotal[day] ?? 0) + item.sizeBytes;

      final mime = item.mimeType.toLowerCase();
      if (mime.startsWith('image/')) {
        deltaImages[day] = (deltaImages[day] ?? 0) + item.sizeBytes;
      } else if (mime.startsWith('video/')) {
        deltaVideos[day] = (deltaVideos[day] ?? 0) + item.sizeBytes;
      } else if (mime.startsWith('audio/')) {
        deltaAudio[day] = (deltaAudio[day] ?? 0) + item.sizeBytes;
      } else {
        deltaDocs[day] = (deltaDocs[day] ?? 0) + item.sizeBytes;
      }
    }

    if (minDay > todayEpochDay) minDay = todayEpochDay;

    // If minDay is more than 365 days ago, limit backfill span to 365 days to prevent bloated rows
    final earliestAllowedDay = todayEpochDay - 365;
    if (minDay < earliestAllowedDay) {
      minDay = earliestAllowedDay;
    }

    var runningTotal = 0;
    var runningImages = 0;
    var runningVideos = 0;
    var runningAudio = 0;
    var runningDocs = 0;

    // Pre-seed baseline for any items older than minDay
    for (final item in allItems) {
      final day = item.dateAddedSec ~/ 86400;
      if (day < minDay) {
        runningTotal += item.sizeBytes;
        final mime = item.mimeType.toLowerCase();
        if (mime.startsWith('image/')) {
          runningImages += item.sizeBytes;
        } else if (mime.startsWith('video/')) {
          runningVideos += item.sizeBytes;
        } else if (mime.startsWith('audio/')) {
          runningAudio += item.sizeBytes;
        } else {
          runningDocs += item.sizeBytes;
        }
      }
    }

    // Sequentially accumulate daily storage curves
    for (var d = minDay; d <= todayEpochDay; d++) {
      runningTotal += deltaTotal[d] ?? 0;
      runningImages += deltaImages[d] ?? 0;
      runningVideos += deltaVideos[d] ?? 0;
      runningAudio += deltaAudio[d] ?? 0;
      runningDocs += deltaDocs[d] ?? 0;

      await _db.upsertStorageSnapshot(
        dateEpochDay: d,
        totalBytes: runningTotal,
        imageBytes: runningImages,
        videoBytes: runningVideos,
        audioBytes: runningAudio,
        documentBytes: runningDocs,
      );
    }
  }

  /// Take or update today's live snapshot based on currently indexed items.
  Future<void> takeCurrentSnapshot() async {
    final now = DateTime.now();
    final todayEpochDay = now.millisecondsSinceEpoch ~/ (86400 * 1000);

    final allItems = await _db.select(_db.mediaItems).get();

    var total = 0;
    var images = 0;
    var videos = 0;
    var audio = 0;
    var docs = 0;

    for (final item in allItems) {
      total += item.sizeBytes;
      final mime = item.mimeType.toLowerCase();
      if (mime.startsWith('image/')) {
        images += item.sizeBytes;
      } else if (mime.startsWith('video/')) {
        videos += item.sizeBytes;
      } else if (mime.startsWith('audio/')) {
        audio += item.sizeBytes;
      } else {
        docs += item.sizeBytes;
      }
    }

    await _db.upsertStorageSnapshot(
      dateEpochDay: todayEpochDay,
      totalBytes: total,
      imageBytes: images,
      videoBytes: videos,
      audioBytes: audio,
      documentBytes: docs,
    );
  }

  /// Load trend analysis for a requested TimeRange (REQ-ANL-03).
  Future<AnalyticsTrends> getTrends({
    required TimeRange range,
    bool forceBackfillIfNeeded = true,
  }) async {
    final hasSnapshots = await _db.hasStorageSnapshots();
    if (!hasSnapshots && forceBackfillIfNeeded) {
      await backfillFromIndex();
    }

    final todayEpochDay = DateTime.now().millisecondsSinceEpoch ~/ (86400 * 1000);
    int? fromDay;

    if (range.days != null) {
      fromDay = todayEpochDay - range.days!;
    }

    final rows = await _db.queryStorageSnapshots(
      fromEpochDay: fromDay,
      toEpochDay: todayEpochDay,
    );

    final points = rows.map((r) {
      return StorageSnapshotPoint.fromRow({
        'date_epoch_day': r.read<int>('date_epoch_day'),
        'total_bytes': r.read<int>('total_bytes'),
        'image_bytes': r.read<int>('image_bytes'),
        'video_bytes': r.read<int>('video_bytes'),
        'audio_bytes': r.read<int>('audio_bytes'),
        'document_bytes': r.read<int>('document_bytes'),
        'duplicate_bytes': r.read<int>('duplicate_bytes'),
        'potential_cleanup_bytes': r.read<int>('potential_cleanup_bytes'),
        'space_recovered_bytes': r.read<int>('space_recovered_bytes'),
      });
    }).toList();

    return AnalyticsTrends.compute(
      range: range,
      snapshots: points,
      isBackfilled: true,
    );
  }
}
