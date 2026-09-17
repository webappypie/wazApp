// lib/features/clean/data/documents_data_source.dart
//
// Category data source for Documents (PDF, Office, Archives) (REQ-CLN-01, P-01).
// Identifies and groups non-media WhatsApp shared documents.

import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../domain/category_data_source.dart';
import '../domain/category_models.dart';

class DocumentsDataSource extends CategoryDataSource {
  DocumentsDataSource({
    this.db,
    this.testItems,
  });

  final AppDatabase? db;
  final List<CategoryItem>? testItems;

  @override
  Future<List<CategoryItem>> getItems() async {
    final List<CategoryItem> candidateItems;

    if (testItems != null) {
      candidateItems = testItems!.where((item) => !item.isProtected && isDocument(item)).toList();
    } else {
      final database = db!;
      final rows = await (database.select(database.mediaItems)
            ..where((tbl) =>
                tbl.isProtected.equals(false) &
                (tbl.mimeType.like('application/%') |
                    tbl.mimeType.like('text/%') |
                    (tbl.mimeType.like('image/%').not() &
                        tbl.mimeType.like('video/%').not() &
                        tbl.mimeType.like('audio/%').not())))
            ..orderBy([
              (tbl) => OrderingTerm.desc(tbl.dateModifiedSec),
            ]))
          .get();

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

    return candidateItems.map((item) {
      final ext = item.fileExtension.replaceFirst('.', '').toUpperCase();
      final badge = ext.isNotEmpty ? ext : 'DOC';

      final String group;
      if (isPdf(item)) {
        group = 'PDF Documents';
      } else if (isOfficeDoc(item)) {
        group = 'Office Documents';
      } else if (isArchive(item)) {
        group = 'Archives';
      } else {
        group = 'Other Documents';
      }

      return item.copyWith(
        badgeLabel: badge,
        groupTitle: group,
      );
    }).toList();
  }

  static bool isDocument(CategoryItem item) {
    if (item.isImage || item.isVideo || item.isAudio) return false;
    return true;
  }

  static bool isPdf(CategoryItem item) {
    return item.fileExtension == '.pdf' || item.mimeType == 'application/pdf';
  }

  static bool isOfficeDoc(CategoryItem item) {
    const exts = ['.doc', '.docx', '.xls', '.xlsx', '.ppt', '.pptx', '.csv', '.rtf'];
    return exts.contains(item.fileExtension) ||
        item.mimeType.contains('word') ||
        item.mimeType.contains('excel') ||
        item.mimeType.contains('sheet') ||
        item.mimeType.contains('presentation');
  }

  static bool isArchive(CategoryItem item) {
    const exts = ['.zip', '.rar', '.7z', '.tar', '.gz'];
    return exts.contains(item.fileExtension) || item.mimeType.contains('zip') || item.mimeType.contains('compressed');
  }
}
