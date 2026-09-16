// lib/features/clean/data/large_videos_data_source.dart
//
// Data source for large videos (REQ-VID-01).
// Queries Drift DB for video files >= 50 MB.

import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../domain/category_data_source.dart';
import '../domain/category_models.dart';

class LargeVideosDataSource extends CategoryDataSource {
  LargeVideosDataSource({
    this.db,
    this.testItems,
    this.minSizeBytes = 50 * 1024 * 1024, // 50 MB
  });

  final AppDatabase? db;
  final List<CategoryItem>? testItems;
  final int minSizeBytes;

  @override
  Future<List<CategoryItem>> getItems() async {
    if (testItems != null) {
      return testItems!
          .where((item) => item.isVideo && item.sizeBytes >= minSizeBytes)
          .toList();
    }

    final database = db!;
    final query = database.select(database.mediaItems)
      ..where((tbl) =>
          tbl.mimeType.like('video/%') &
          tbl.sizeBytes.isBiggerOrEqualValue(minSizeBytes));

    final rows = await query.get();
    return rows.map((r) => CategoryItem(
      id: r.id.toString(),
      contentUri: r.contentUri,
      displayName: r.displayName,
      mimeType: r.mimeType,
      sizeBytes: r.sizeBytes,
      dateAddedSec: r.dateAddedSec,
      dateModifiedSec: r.dateModifiedSec,
      bucketName: r.bucketName,
      sourceApp: r.sourceApp,
      width: r.width,
      height: r.height,
      durationMs: r.durationMs,
      isProtected: r.isProtected,
    )).toList();
  }
}
