// lib/core/database/app_database.dart
//
// Drift database — Phase 0: empty schema, migrations wired, verified to open.
// Tables are added in Phase 3 (indexing engine).
// The migration runner is set up now so Phase 3 additions integrate cleanly.

import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'app_database.g.dart';

/// Current schema version. Bump this (and add a migration) whenever a table
/// is added or altered. Phase 3 will bump to version 2.
const int _kSchemaVersion = 1;

@DriftDatabase(tables: [])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
      : super(executor ?? _openConnection());

  @override
  int get schemaVersion => _kSchemaVersion;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
        },
        onUpgrade: (m, from, to) async {
          // Migrations are added here as tables grow through phases.
          // Example for Phase 3: if (from < 2) { await m.createTable(mediaItems); }
        },
        beforeOpen: (details) async {
          // Enable WAL and foreign keys on every open.
          await customStatement('PRAGMA journal_mode=WAL');
          await customStatement('PRAGMA foreign_keys=ON');
        },
      );
}

/// Opens the SQLite file in the app's documents directory.
LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'wapptidy.db'));
    return NativeDatabase.createInBackground(file);
  });
}
