// lib/features/clean/data/old_media_data_source.dart
//
// Data source for old media (REQ-OLD-01).
// Queries media older than 3 months, sub-grouping by media type.

import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../domain/category_data_source.dart';
import '../domain/category_models.dart';

class OldMediaDataSource extends CategoryDataSource {
  OldMediaDataSource({
    this.db,
    this.testItems,
    this.minAgeDays = 90, // 3 months
  });

  final AppDatabase? db;
  final List<CategoryItem>? testItems;
  final int minAgeDays;

  @override
  Future<List<CategoryItem>> getItems() async {
    final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final cutoffSec = nowSec - (minAgeDays * 86400);

    final List<CategoryItem> candidateItems;

    if (testItems != null) {
      candidateItems = testItems!
          .where((item) =>
              !item.isProtected &&
              (item.dateModifiedSec <= cutoffSec || item.dateAddedSec <= cutoffSec))
          .toList();
    } else {
      final database = db!;
      final query = database.select(database.mediaItems)
        ..where((tbl) =>
            tbl.isProtected.equals(false) &
            tbl.dateModifiedSec.isSmallerOrEqualValue(cutoffSec));
      final rows = await query.get();
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

    // Sub-group by media type (REQ-OLD-01)
    return candidateItems.map((item) {
      final typeLabel = item.isImage
          ? 'Images'
          : item.isVideo
              ? 'Videos'
              : item.isAudio
                  ? 'Audio'
                  : 'Other Media';

      return CategoryItem(
        id: item.id,
        contentUri: item.contentUri,
        displayName: item.displayName,
        mimeType: item.mimeType,
        sizeBytes: item.sizeBytes,
        dateAddedSec: item.dateAddedSec,
        dateModifiedSec: item.dateModifiedSec,
        bucketName: item.bucketName,
        sourceApp: item.sourceApp,
        width: item.width,
        height: item.height,
        durationMs: item.durationMs,
        isProtected: item.isProtected,
        isOriginal: item.isOriginal,
        groupTitle: typeLabel,
      );
    }).toList();
  }
}
