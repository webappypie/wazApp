// lib/core/database/app_database.dart
//
// Drift database for WazApp.
//   v1: saved_media (the local library)
//   v2: saved_media.content_hash + visual_hash (Storage Manager duplicate detection)
// Bump [_kSchemaVersion] and add an onUpgrade step for every schema change.

import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'tables/saved_media_table.dart';

export 'tables/saved_media_table.dart';

part 'app_database.g.dart';

const int _kSchemaVersion = 2;

@DriftDatabase(tables: [SavedMediaTable])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => _kSchemaVersion;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.addColumn(savedMediaTable, savedMediaTable.contentHash);
            await m.addColumn(savedMediaTable, savedMediaTable.visualHash);
          }
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA journal_mode=WAL');
        },
      );

  // ---------------------------------------------------------------------------
  // Queries
  // ---------------------------------------------------------------------------

  /// Ordinary (non-private) library rows, newest first.
  Stream<List<SavedMedia>> watchLibrary() {
    final q = select(savedMediaTable)
      ..where((t) => t.isPrivate.equals(false))
      ..orderBy([(t) => OrderingTerm.desc(t.savedAt)]);
    return q.watch();
  }

  /// Items moved into the Private Folder, newest first.
  Stream<List<SavedMedia>> watchPrivate() {
    final q = select(savedMediaTable)
      ..where((t) => t.isPrivate.equals(true))
      ..orderBy([(t) => OrderingTerm.desc(t.savedAt)]);
    return q.watch();
  }

  /// Every row, private or not (used by the viewer and by storage accounting).
  Stream<List<SavedMedia>> watchAll() {
    final q = select(savedMediaTable)..orderBy([(t) => OrderingTerm.desc(t.savedAt)]);
    return q.watch();
  }

  Future<List<SavedMedia>> allRows() => select(savedMediaTable).get();

  Future<SavedMedia?> findById(String id) =>
      (select(savedMediaTable)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<SavedMedia?> findBySourceKey(String key) =>
      (select(savedMediaTable)..where((t) => t.sourceKey.equals(key))).getSingleOrNull();

  /// Source keys already in the library (for "already saved" markers).
  Stream<Set<String>> watchSourceKeys() {
    final q = selectOnly(savedMediaTable)
      ..addColumns([savedMediaTable.sourceKey])
      ..where(savedMediaTable.sourceKey.isNotNull());
    return q
        .watch()
        .map((rows) => rows.map((r) => r.read(savedMediaTable.sourceKey)!).toSet());
  }

  // ---------------------------------------------------------------------------
  // Writes
  // ---------------------------------------------------------------------------

  Future<void> insertMedia(SavedMediaTableCompanion row) =>
      into(savedMediaTable).insert(row);

  Future<void> setFavourite(Iterable<String> ids, bool value) =>
      (update(savedMediaTable)..where((t) => t.id.isIn(ids)))
          .write(SavedMediaTableCompanion(isFavourite: Value(value)));

  /// Moves rows between the library and the Private Folder, updating paths atomically.
  Future<void> setPrivacy(String id, {required bool isPrivate, required String path, String? thumbnailPath}) =>
      (update(savedMediaTable)..where((t) => t.id.equals(id))).write(SavedMediaTableCompanion(
        isPrivate: Value(isPrivate),
        path: Value(path),
        thumbnailPath: Value(thumbnailPath),
      ));

  Future<void> setHashes(String id, {String? contentHash, String? visualHash}) =>
      (update(savedMediaTable)..where((t) => t.id.equals(id))).write(SavedMediaTableCompanion(
        contentHash: contentHash == null ? const Value.absent() : Value(contentHash),
        visualHash: visualHash == null ? const Value.absent() : Value(visualHash),
      ));

  Future<void> setThumbnail(String id, String? thumbnailPath) =>
      (update(savedMediaTable)..where((t) => t.id.equals(id)))
          .write(SavedMediaTableCompanion(thumbnailPath: Value(thumbnailPath)));

  Future<int> deleteByIds(Iterable<String> ids) =>
      (delete(savedMediaTable)..where((t) => t.id.isIn(ids))).go();
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'wazapp.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
