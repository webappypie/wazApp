import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wazapp/core/database/app_database.dart';

void main() {
  test('v1 -> v2 migration keeps existing rows and adds the hash columns', () async {
    // A database exactly as schema v1 (Phase 1-3) created it, with one saved item.
    final db = AppDatabase(NativeDatabase.memory(setup: (raw) {
      raw.execute('''
        CREATE TABLE saved_media (
          id TEXT NOT NULL PRIMARY KEY,
          path TEXT NOT NULL,
          kind TEXT NOT NULL,
          mime_type TEXT NOT NULL,
          file_name TEXT NOT NULL,
          size_bytes INTEGER NOT NULL,
          saved_at INTEGER NOT NULL,
          original_at INTEGER NULL,
          source_type TEXT NOT NULL,
          source_app TEXT NULL,
          source_key TEXT NULL UNIQUE,
          width INTEGER NOT NULL DEFAULT 0,
          height INTEGER NOT NULL DEFAULT 0,
          duration_ms INTEGER NOT NULL DEFAULT 0,
          is_favourite INTEGER NOT NULL DEFAULT 0 CHECK (is_favourite IN (0, 1)),
          is_private INTEGER NOT NULL DEFAULT 0 CHECK (is_private IN (0, 1)),
          is_edited INTEGER NOT NULL DEFAULT 0 CHECK (is_edited IN (0, 1)),
          thumbnail_path TEXT NULL
        )''');
      raw.execute("INSERT INTO saved_media (id, path, kind, mime_type, file_name, size_bytes, saved_at, source_type, is_favourite) "
          "VALUES ('old1', '/x/old1.jpg', 'image', 'image/jpeg', 'old.jpg', 1234, 1700000000, 'imported', 1)");
      raw.execute('PRAGMA user_version = 1');
    }));

    final old = await db.findById('old1');
    expect(old, isNotNull);
    expect(old!.fileName, 'old.jpg');
    expect(old.isFavourite, isTrue);
    expect(old.sizeBytes, 1234);
    expect(old.contentHash, isNull);
    expect(old.visualHash, isNull);

    await db.setHashes('old1', contentHash: 'abc', visualHash: '00ff');
    final after = (await db.findById('old1'))!;
    expect((after.contentHash, after.visualHash), ('abc', '00ff'));
    await db.close();
  });

  test('setHashes only touches the provided hash', () async {
    final db = AppDatabase(NativeDatabase.memory());
    await db.insertMedia(SavedMediaTableCompanion.insert(
      id: 'a',
      path: '/a',
      kind: 'image',
      mimeType: 'image/png',
      fileName: 'a.png',
      sizeBytes: 1,
      savedAt: DateTime(2026),
      sourceType: 'imported',
    ));
    await db.setHashes('a', contentHash: 'h1');
    await db.setHashes('a', visualHash: 'v1');
    final r = (await db.findById('a'))!;
    expect((r.contentHash, r.visualHash), ('h1', 'v1'));
    await db.close();
  });
}
