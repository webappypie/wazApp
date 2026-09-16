// lib/features/clean/data/all_indexed_media_data_source.dart
//
// Concrete CategoryDataSource that queries all indexed media from the Drift DB (REQ-CLN-01).
// Serves as the dummy/reference category for Phase 5 verification.

import '../../../core/database/app_database.dart';
import '../domain/category_data_source.dart';
import '../domain/category_models.dart';

class AllIndexedMediaDataSource extends CategoryDataSource {
  AllIndexedMediaDataSource(this._db);

  final AppDatabase _db;

  @override
  Future<List<CategoryItem>> getItems() async {
    final rows = await _db.select(_db.mediaItems).get();
    return rows.map(_mapToCategoryItem).toList();
  }

  CategoryItem _mapToCategoryItem(MediaItem row) {
    return CategoryItem(
      id: row.id.toString(),
      contentUri: row.contentUri,
      displayName: row.displayName,
      mimeType: row.mimeType,
      sizeBytes: row.sizeBytes,
      dateAddedSec: row.dateAddedSec,
      dateModifiedSec: row.dateModifiedSec,
      bucketName: row.bucketName,
      sourceApp: row.sourceApp,
      width: row.width,
      height: row.height,
      durationMs: row.durationMs,
      isProtected: row.isProtected,
    );
  }
}
