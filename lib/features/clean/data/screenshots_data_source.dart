// lib/features/clean/data/screenshots_data_source.dart
//
// Data source for screenshots (REQ-SCR-01).
// Identifies screenshots by folder bucket and dimension heuristics without ML.

import '../../../core/database/app_database.dart';
import '../domain/category_data_source.dart';
import '../domain/category_models.dart';

class ScreenshotsDataSource extends CategoryDataSource {
  ScreenshotsDataSource({
    this.db,
    this.testItems,
  });

  final AppDatabase? db;
  final List<CategoryItem>? testItems;

  @override
  Future<List<CategoryItem>> getItems() async {
    final List<CategoryItem> candidateItems;

    if (testItems != null) {
      candidateItems = testItems!;
    } else {
      final rows = await db!.select(db!.mediaItems).get();
      candidateItems = rows.map((r) => CategoryItem(
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

    return candidateItems.where(isScreenshot).toList();
  }

  /// REQ-SCR-01 heuristic: folder bucket or dimension ratio (>= 1.77).
  static bool isScreenshot(CategoryItem item) {
    if (item.isVideo) return false;

    // 1. Bucket or filename heuristic
    final name = item.displayName.toLowerCase();
    final bucket = item.bucketName.toLowerCase();
    if (bucket.contains('screenshot') || name.contains('screenshot') || name.startsWith('screen_')) {
      return true;
    }

    // 2. Dimension heuristic (common phone aspect ratios 16:9, 18:9, 19.5:9, 20:9)
    if (item.width > 0 && item.height > 0) {
      final longer = item.height > item.width ? item.height : item.width;
      final shorter = item.height > item.width ? item.width : item.height;
      final ratio = longer.toDouble() / shorter.toDouble();

      // Common phone portrait screen aspect ratio >= 16:9 (1.777)
      if (ratio >= 1.75) {
        // Must match common phone screen resolution widths or standard screenshot dimensions
        if (shorter == 720 || shorter == 1080 || shorter == 1440 || shorter == 1084 || shorter == 800) {
          return true;
        }
      }
    }

    return false;
  }
}
