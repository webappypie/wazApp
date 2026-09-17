// lib/features/clean/data/voice_notes_data_source.dart
//
// Category data source for Voice Notes and Audio files (REQ-CLN-01, P-01).
// Identifies voice notes (PTT recordings) vs. standard audio clips.

import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../domain/category_data_source.dart';
import '../domain/category_models.dart';

class VoiceNotesDataSource extends CategoryDataSource {
  VoiceNotesDataSource({
    this.db,
    this.testItems,
  });

  final AppDatabase? db;
  final List<CategoryItem>? testItems;

  @override
  Future<List<CategoryItem>> getItems() async {
    final List<CategoryItem> candidateItems;

    if (testItems != null) {
      candidateItems = testItems!.where((item) => !item.isProtected && item.isAudio).toList();
    } else {
      final database = db!;
      final rows = await (database.select(database.mediaItems)
            ..where((tbl) =>
                tbl.isProtected.equals(false) &
                tbl.mimeType.like('audio/%'))
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

    // Annotate with badgeLabel and groupTitle
    return candidateItems.map((item) {
      final isPtt = isVoiceNote(item);
      return item.copyWith(
        badgeLabel: isPtt ? 'Voice Note' : 'Audio Clip',
        groupTitle: isPtt ? 'Voice Notes' : 'Audio Clips',
      );
    }).toList();
  }

  /// Voice note heuristics: starts with PTT- or bucket contains "Voice".
  static bool isVoiceNote(CategoryItem item) {
    if (!item.isAudio) return false;
    final name = item.displayName.toUpperCase();
    final bucket = item.bucketName.toLowerCase();
    return name.startsWith('PTT-') || bucket.contains('voice');
  }

  /// Non-voice audio clip heuristics (songs, forwarded recordings, podcasts).
  static bool isAudioClip(CategoryItem item) {
    return item.isAudio && !isVoiceNote(item);
  }
}
