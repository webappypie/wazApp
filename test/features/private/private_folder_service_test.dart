import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wazapp/core/database/app_database.dart';
import 'package:wazapp/features/library/data/library_service.dart';
import 'package:wazapp/features/library/data/library_storage.dart';
import 'package:wazapp/features/library/domain/library_models.dart';

import '../../support/fakes.dart';

/// A database whose privacy update can be made to fail, to prove the file move is rolled back.
class _FlakyDb extends AppDatabase {
  _FlakyDb() : super(NativeDatabase.memory());
  bool failPrivacy = false;

  @override
  Future<void> setPrivacy(String id, {required bool isPrivate, required String path, String? thumbnailPath}) {
    if (failPrivacy) throw StateError('disk I/O error');
    return super.setPrivacy(id, isPrivate: isPrivate, path: path, thumbnailPath: thumbnailPath);
  }
}

void main() {
  late Directory tmp;
  late Directory sourceDir;
  late _FlakyDb db;
  late LibraryStorage storage;
  late FakeStatusAccess access;
  late LibraryService service;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('wazapp_private_');
    sourceDir = await Directory('${tmp.path}/source').create();
    storage = LibraryStorage(Directory('${tmp.path}/support'));
    await storage.ensureCreated();
    db = _FlakyDb();
    access = FakeStatusAccess();
    service = LibraryService(db: db, storage: storage, status: access, tools: access, probe: FakeProbe());
  });

  tearDown(() async {
    await db.close();
    await tmp.delete(recursive: true);
  });

  Future<SavedMedia> saveImage(String name, {List<int>? bytes}) async =>
      (await service.saveStatus(access.addStatus(sourceDir, name, bytes: bytes))).media;
  Future<SavedMedia> saveVideo(String name) async =>
      (await service.saveStatus(access.addStatus(sourceDir, name, kind: MediaKind.video))).media;

  List<String> names(Directory d) => d.listSync().map((e) => e.uri.pathSegments.last).toList();

  test('moving to the Private Folder relocates the file, keeps its bytes, and hides it from the library', () async {
    final m = await saveImage('a.jpg', bytes: List.generate(3000, (i) => i % 251));
    final original = File(m.path).readAsBytesSync();

    final r = await service.moveToPrivate([m.id]);
    expect(r.moved, 1);
    expect(r.failedIds, isEmpty);

    final row = (await db.findById(m.id))!;
    expect(row.isPrivate, isTrue);
    expect(row.path, startsWith(storage.privateDir.path));
    expect(File(row.path).readAsBytesSync(), original);
    expect(File(m.path).existsSync(), isFalse, reason: 'no copy is left in the normal library folder');
    expect(names(storage.mediaDir), isEmpty);

    expect((await db.watchLibrary().first).map((x) => x.id), isNot(contains(m.id)));
    expect((await db.watchPrivate().first).map((x) => x.id), [m.id]);
    expect((await db.watchAll().first).map((x) => x.id), [m.id]);
  });

  test('thumbnails move with the video and stay consistent', () async {
    final v = await saveVideo('v.mp4');
    expect(v.thumbnailPath, isNotNull);
    await service.moveToPrivate([v.id]);
    final row = (await db.findById(v.id))!;
    expect(row.thumbnailPath, startsWith(storage.privateThumbsDir.path));
    expect(File(row.thumbnailPath!).existsSync(), isTrue);
    expect(File(v.thumbnailPath!).existsSync(), isFalse);

    await service.restoreFromPrivate([v.id]);
    final back = (await db.findById(v.id))!;
    expect(back.isPrivate, isFalse);
    expect(back.path, startsWith(storage.mediaDir.path));
    expect(back.thumbnailPath, startsWith(storage.thumbsDir.path));
    expect(File(back.thumbnailPath!).existsSync(), isTrue);
    expect(names(storage.privateDir), isEmpty);
    expect(names(storage.privateThumbsDir), isEmpty);
  });

  test('restore returns the item to the library with identical bytes', () async {
    final m = await saveImage('b.jpg', bytes: List.filled(1500, 9));
    await service.moveToPrivate([m.id]);
    final r = await service.restoreFromPrivate([m.id]);
    expect(r.moved, 1);
    final row = (await db.findById(m.id))!;
    expect(row.isPrivate, isFalse);
    expect(File(row.path).readAsBytesSync(), List.filled(1500, 9));
    expect((await db.watchLibrary().first).map((x) => x.id), [m.id]);
    expect(await db.watchPrivate().first, isEmpty);
  });

  test('a failing database update rolls the file move back (path and flag never disagree)', () async {
    final v = await saveVideo('v.mp4');
    db.failPrivacy = true;
    final r = await service.moveToPrivate([v.id]);
    expect(r.moved, 0);
    expect(r.failedIds, [v.id]);

    final row = (await db.findById(v.id))!;
    expect(row.isPrivate, isFalse);
    expect(row.path, v.path);
    expect(File(v.path).existsSync(), isTrue, reason: 'file is back where the row says it is');
    expect(File(v.thumbnailPath!).existsSync(), isTrue);
    expect(names(storage.privateDir), isEmpty);
    expect(names(storage.privateThumbsDir), isEmpty);
  });

  test('a missing file fails cleanly for that item only; others still move', () async {
    final a = await saveImage('a.jpg');
    final b = await saveImage('b.jpg');
    File(a.path).deleteSync();
    final r = await service.moveToPrivate([a.id, b.id]);
    expect(r.moved, 1);
    expect(r.failedIds, [a.id]);
    expect((await db.findById(a.id))!.isPrivate, isFalse);
    expect((await db.findById(b.id))!.isPrivate, isTrue);
  });

  test('moving something already private (or unknown) is a no-op', () async {
    final a = await saveImage('a.jpg');
    await service.moveToPrivate([a.id]);
    final again = await service.moveToPrivate([a.id, 'does-not-exist']);
    expect(again.moved, 0);
    expect(again.failedIds, isEmpty);
    expect(names(storage.privateDir), hasLength(1));
  });

  test('deleting a private item removes its private file and thumbnail', () async {
    final v = await saveVideo('v.mp4');
    await service.moveToPrivate([v.id]);
    final row = (await db.findById(v.id))!;
    final r = await service.delete([v.id]);
    expect(r.deleted, 1);
    expect(File(row.path).existsSync(), isFalse);
    expect(File(row.thumbnailPath!).existsSync(), isFalse);
    expect(await db.findById(v.id), isNull);
  });

  test('storage accounting and maintenance cover the private directories', () async {
    final a = await saveImage('a.jpg', bytes: List.filled(1000, 1));
    await service.moveToPrivate([a.id]);
    expect(await storage.usedBytes(), 1000);

    File('${storage.privateDir.path}/leftover.jpg.part').writeAsStringSync('x');
    File('${storage.privateThumbsDir.path}/orphan.jpg').writeAsBytesSync([1]);
    expect(await storage.cleanPartialFiles(), 1);
    await service.reconcile();
    expect(names(storage.privateDir), [(await db.findById(a.id))!.path.split(Platform.pathSeparator).last]);
    expect(names(storage.privateThumbsDir), isEmpty, reason: 'orphan private thumbnail swept');
  });

  test('private items stay out of the normal library even when re-saved status keys exist', () async {
    final a = await saveImage('a.jpg');
    await service.moveToPrivate([a.id]);
    // The same status is still recognised as saved (no duplicate copy is created behind the user's back)...
    final again = await service.saveStatus(access.statuses.values.first.first);
    expect(again.created, isFalse);
    // ...yet it never appears in the ordinary library list.
    expect(await db.watchLibrary().first, isEmpty);
  });
}
