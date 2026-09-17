// lib/features/backup/data/backup_repository.dart
//
// Repository for fetching and filtering candidate media items for Google Drive backup.

import 'package:drift/drift.dart';
import '../../../core/database/app_database.dart';
import '../../../core/services/backup/cloud_backup_service.dart';

enum BackupCategoryFilter {
  all('All WhatsApp Media'),
  largeVideos('Large Videos (>50 MB)'),
  oldMedia('Old Media (>6 Months)'),
  documents('Documents'),
  voiceNotes('Voice Notes & Audio'),
  photos('Photos');

  final String label;
  const BackupCategoryFilter(this.label);
}

class BackupRepository {
  final AppDatabase db;
  final CloudBackupService backupService;

  BackupRepository({
    required this.db,
    required this.backupService,
  });

  CloudBackupService get service => backupService;

  /// Loads candidate media items from the database according to the selected filter.
  Future<List<BackupMediaItem>> getCandidateItems({
    BackupCategoryFilter filter = BackupCategoryFilter.all,
  }) async {
    final query = db.select(db.mediaItems);

    final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    const sixMonthsSec = 180 * 86400;
    final sixMonthsCutoff = nowSec - sixMonthsSec;

    switch (filter) {
      case BackupCategoryFilter.all:
        // No filter clause, select all non-protected media
        break;
      case BackupCategoryFilter.largeVideos:
        query.where((tbl) =>
            tbl.mimeType.like('video/%') &
            tbl.sizeBytes.isBiggerOrEqualValue(50 * 1024 * 1024));
        break;
      case BackupCategoryFilter.oldMedia:
        query.where((tbl) =>
            tbl.dateAddedSec.isSmallerOrEqualValue(sixMonthsCutoff));
        break;
      case BackupCategoryFilter.documents:
        query.where((tbl) =>
            tbl.mimeType.like('application/%') | tbl.mimeType.like('text/%'));
        break;
      case BackupCategoryFilter.voiceNotes:
        query.where((tbl) => tbl.mimeType.like('audio/%'));
        break;
      case BackupCategoryFilter.photos:
        query.where((tbl) => tbl.mimeType.like('image/%'));
        break;
    }

    final rows = await query.get();

    return rows.map((row) {
      String cat = 'Media';
      if (row.mimeType.startsWith('image/')) {
        cat = 'Photo';
      } else if (row.mimeType.startsWith('video/')) {
        cat = 'Video';
      } else if (row.mimeType.startsWith('audio/')) {
        cat = 'Audio';
      } else if (row.mimeType.startsWith('application/') ||
          row.mimeType.startsWith('text/')) {
        cat = 'Document';
      }

      return BackupMediaItem(
        id: row.id,
        contentUri: row.contentUri,
        displayName: row.displayName,
        sizeBytes: row.sizeBytes,
        mimeType: row.mimeType,
        category: cat,
      );
    }).toList();
  }
}
