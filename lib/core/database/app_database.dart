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
  /// This removes rows for files that no longer exist on disk (REQ-IDX-07).
  Future<int> deleteStaleItems(int currentVersion) {
    return (delete(mediaItems)
          ..where((t) => t.scanVersion.isSmallerThanValue(currentVersion)))
        .go();
  }

  /// Count of all indexed items.
  Future<int> countAllItems() async {
    final count = mediaItems.id.count();
    final result = await (selectOnly(mediaItems)..addColumns([count])).getSingle();
    return result.read(count) ?? 0;
  }

  /// Sum of sizeBytes across all indexed items.
  Future<int> sumAllBytes() async {
    final sum = mediaItems.sizeBytes.sum();
    final result = await (selectOnly(mediaItems)..addColumns([sum])).getSingle();
    return result.read(sum) ?? 0;
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
