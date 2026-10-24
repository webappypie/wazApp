// lib/core/database/app_database.dart
//
// Drift database — Phase 3: schema v2, media_items + scan_state tables.
// Migration: v1→v2 creates both tables.

import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'tables/media_items_table.dart';
import 'tables/scan_state_table.dart';

export 'tables/media_items_table.dart';
export 'tables/scan_state_table.dart';

part 'app_database.g.dart';

/// Schema version — bump every time tables are added or altered.
/// v1 (Phase 0): empty schema
/// v2 (Phase 3): media_items + scan_state tables
const int _kSchemaVersion = 2;

@DriftDatabase(tables: [MediaItems, ScanStateTable])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
      : super(executor ?? _openConnection());

  @override
  int get schemaVersion => _kSchemaVersion;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          // Seed the singleton scan_state row.
          await _seedScanState(m);
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.createTable(mediaItems);
            await m.createTable(scanStateTable);
            await _seedScanState(m);
          }
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA journal_mode=WAL');
          await customStatement('PRAGMA foreign_keys=ON');
          await customStatement('''
            CREATE TABLE IF NOT EXISTS storage_snapshots (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              date_epoch_day INTEGER NOT NULL UNIQUE,
              total_bytes INTEGER NOT NULL,
              image_bytes INTEGER NOT NULL DEFAULT 0,
              video_bytes INTEGER NOT NULL DEFAULT 0,
              audio_bytes INTEGER NOT NULL DEFAULT 0,
              document_bytes INTEGER NOT NULL DEFAULT 0,
              duplicate_bytes INTEGER NOT NULL DEFAULT 0,
              potential_cleanup_bytes INTEGER NOT NULL DEFAULT 0,
              space_recovered_bytes INTEGER NOT NULL DEFAULT 0,
              created_at INTEGER NOT NULL
            )
          ''');
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_storage_snapshots_date ON storage_snapshots(date_epoch_day)',
          );
          try {
            await customStatement('ALTER TABLE storage_snapshots ADD COLUMN whatsapp_bytes INTEGER NOT NULL DEFAULT 0');
          } catch (_) {}
          try {
            await customStatement('ALTER TABLE storage_snapshots ADD COLUMN whatsapp_business_bytes INTEGER NOT NULL DEFAULT 0');
          } catch (_) {}
          try {
            await customStatement("UPDATE media_items SET source_app = 'com.whatsapp' WHERE source_app IS NULL OR source_app = ''");
          } catch (_) {}
          try {
            await customStatement('CREATE INDEX IF NOT EXISTS idx_media_items_source_app ON media_items(source_app)');
          } catch (_) {}
        },
      );

  Future<void> _seedScanState(Migrator m) async {
    await into(scanStateTable).insertOnConflictUpdate(
      ScanStateTableCompanion.insert(
        id: const Value(1),
        status: const Value('idle'),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Scan state helpers (used by IndexingRepository)
  // ---------------------------------------------------------------------------

  /// Read the singleton scan state row.
  Future<ScanStateTableData> readScanState() {
    return (select(scanStateTable)..where((t) => t.id.equals(1))).getSingle();
  }

  /// Update scan state fields atomically.
  Future<void> updateScanState(ScanStateTableCompanion companion) {
    return (update(scanStateTable)..where((t) => t.id.equals(1))).write(companion);
  }

  // ---------------------------------------------------------------------------
  // MediaItems batch helpers (used by IndexingRepository)
  // ---------------------------------------------------------------------------

  /// Upsert a batch of items. On conflict (same contentUri) update all fields.
  Future<void> upsertMediaItems(List<MediaItemsCompanion> items) async {
    await batch((b) {
      b.insertAllOnConflictUpdate(mediaItems, items);
    });
  }

  /// Delete items whose scanVersion < [currentVersion].
  /// If [forSources] is provided, only deletes stale items belonging to those sources.
  Future<int> deleteStaleItems(int currentVersion, {List<String>? forSources}) {
    final query = delete(mediaItems)
      ..where((t) => t.scanVersion.isSmallerThanValue(currentVersion));
    if (forSources != null && forSources.isNotEmpty) {
      query.where((t) => t.sourceApp.isIn(forSources));
    }
    return query.go();
  }

  /// Count of indexed items, optionally filtered by sourceApp.
  Future<int> countAllItems({String? sourceApp}) async {
    final count = mediaItems.id.count();
    final query = selectOnly(mediaItems)..addColumns([count]);
    if (sourceApp != null) {
      if (sourceApp == 'com.whatsapp') {
        query.where(mediaItems.sourceApp.equals('com.whatsapp') | mediaItems.sourceApp.equals('legacy'));
      } else {
        query.where(mediaItems.sourceApp.equals(sourceApp));
      }
    }
    final result = await query.getSingle();
    return result.read(count) ?? 0;
  }

  /// Sum of sizeBytes across indexed items, optionally filtered by sourceApp.
  Future<int> sumAllBytes({String? sourceApp}) async {
    final sum = mediaItems.sizeBytes.sum();
    final query = selectOnly(mediaItems)..addColumns([sum]);
    if (sourceApp != null) {
      if (sourceApp == 'com.whatsapp') {
        query.where(mediaItems.sourceApp.equals('com.whatsapp') | mediaItems.sourceApp.equals('legacy'));
      } else {
        query.where(mediaItems.sourceApp.equals(sourceApp));
      }
    }
    final result = await query.getSingle();
    return result.read(sum) ?? 0;
  }

  /// Delete items belonging to a specific source app (e.g. when disabled and cleared).
  Future<int> deleteItemsBySource(String sourceApp) {
    if (sourceApp == 'com.whatsapp') {
      return (delete(mediaItems)
            ..where((t) => t.sourceApp.equals('com.whatsapp') | t.sourceApp.equals('legacy')))
          .go();
    }
    return (delete(mediaItems)..where((t) => t.sourceApp.equals(sourceApp))).go();
  }

  /// Clear all indexed media and reset scan state (REQ-SET-06).
  Future<void> clearAnalysisData() async {
    await delete(mediaItems).go();
    try {
      await customStatement('DELETE FROM storage_snapshots');
    } catch (_) {}
    await updateScanState(
      const ScanStateTableCompanion(
        status: Value('idle'),
        itemsProcessed: Value(0),
        bytesProcessed: Value(0),
        lastSeenGeneration: Value(0),
        lastModifiedCursor: Value(0),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Storage Snapshot helpers (REQ-ANL-01, REQ-ANL-02)
  // ---------------------------------------------------------------------------

  Future<void> upsertStorageSnapshot({
    required int dateEpochDay,
    required int totalBytes,
    int imageBytes = 0,
    int videoBytes = 0,
    int audioBytes = 0,
    int documentBytes = 0,
    int duplicateBytes = 0,
    int potentialCleanupBytes = 0,
    int spaceRecoveredBytes = 0,
    int? createdAtSec,
  }) async {
    final nowSec = createdAtSec ?? DateTime.now().millisecondsSinceEpoch ~/ 1000;
    await customStatement('''
      INSERT INTO storage_snapshots (
        date_epoch_day, total_bytes, image_bytes, video_bytes, audio_bytes,
        document_bytes, duplicate_bytes, potential_cleanup_bytes, space_recovered_bytes,
        created_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(date_epoch_day) DO UPDATE SET
        total_bytes = excluded.total_bytes,
        image_bytes = excluded.image_bytes,
        video_bytes = excluded.video_bytes,
        audio_bytes = excluded.audio_bytes,
        document_bytes = excluded.document_bytes,
        duplicate_bytes = excluded.duplicate_bytes,
        potential_cleanup_bytes = excluded.potential_cleanup_bytes,
        space_recovered_bytes = excluded.space_recovered_bytes,
        created_at = excluded.created_at
    ''', [
      dateEpochDay,
      totalBytes,
      imageBytes,
      videoBytes,
      audioBytes,
      documentBytes,
      duplicateBytes,
      potentialCleanupBytes,
      spaceRecoveredBytes,
      nowSec,
    ]);
  }

  Future<List<QueryRow>> queryStorageSnapshots({
    int? fromEpochDay,
    int? toEpochDay,
  }) async {
    String query = 'SELECT * FROM storage_snapshots';
    final List<Object?> params = [];

    if (fromEpochDay != null && toEpochDay != null) {
      query += ' WHERE date_epoch_day >= ? AND date_epoch_day <= ?';
      params.addAll([fromEpochDay, toEpochDay]);
    } else if (fromEpochDay != null) {
      query += ' WHERE date_epoch_day >= ?';
      params.add(fromEpochDay);
    } else if (toEpochDay != null) {
      query += ' WHERE date_epoch_day <= ?';
      params.add(toEpochDay);
    }

    query += ' ORDER BY date_epoch_day ASC';
    return customSelect(query, variables: params.map((p) => Variable(p)).toList()).get();
  }

  Future<bool> hasStorageSnapshots() async {
    final rows = await customSelect('SELECT 1 FROM storage_snapshots LIMIT 1').get();
    return rows.isNotEmpty;
  }
}

/// Opens the SQLite file in the app's documents directory.
LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'wapptidy.db'));
    return NativeDatabase.createInBackground(file);
  });
}
