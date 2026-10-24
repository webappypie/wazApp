import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wazapp/core/database/app_database.dart';
import 'package:wazapp/core/error/app_error.dart';
import 'package:wazapp/features/library/data/library_service.dart';
import 'package:wazapp/features/library/data/library_storage.dart';
import 'package:wazapp/features/library/domain/library_models.dart';
import 'package:wazapp/features/status/domain/status_models.dart';

import '../../support/fakes.dart';

void main() {
  late Directory tmp;
  late Directory sourceDir;
  late AppDatabase db;
  late LibraryStorage storage;
  late FakeStatusAccess access;
  late LibraryService service;
  var clockTick = 0;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('wazapp_test_');
    sourceDir = await Directory('${tmp.path}/source').create();
    storage = LibraryStorage(Directory('${tmp.path}/support'));
    await storage.ensureCreated();
    db = AppDatabase(NativeDatabase.memory());
    access = FakeStatusAccess();
    clockTick = 0;
    service = LibraryService(
      db: db,
      storage: storage,
      status: access,
      tools: access,
      probe: FakeProbe(),
      clock: () => DateTime(2026, 10, 24, 12).add(Duration(minutes: clockTick++)),
    );
  });

  tearDown(() async {
    await db.close();
    await tmp.delete(recursive: true);
  });

  List<FileSystemEntity> libraryFiles() => storage.mediaDir.listSync();

  group('saveStatus', () {
    test('copies, verifies and persists metadata', () async {
      final item = access.addStatus(sourceDir, 'a.jpg');
      final r = await service.saveStatus(item);

      expect(r.created, isTrue);
      expect(await File(r.media.path).length(), item.sizeBytes);
      expect(r.media.sourceType, 'status');
      expect(r.media.sourceApp, 'whatsapp');
      expect(r.media.sourceKey, item.sourceKey);
      expect(r.media.width, 720);
      // The original is never touched.
      expect(access.backing[item.uri]!.existsSync(), isTrue);
      expect(libraryFiles(), hasLength(1));
    });

    test('video gets a thumbnail file and duration', () async {
      final item = access.addStatus(sourceDir, 'v.mp4', kind: MediaKind.video);
      final r = await service.saveStatus(item);
      expect(r.media.isVideo, isTrue);
      expect(r.media.durationMs, 5000);
      expect(r.media.thumbnailPath, isNotNull);
      expect(File(r.media.thumbnailPath!).existsSync(), isTrue);
    });

    test('saving the same status twice does not duplicate it', () async {
      final item = access.addStatus(sourceDir, 'a.jpg');
      final first = await service.saveStatus(item);
      final second = await service.saveStatus(item);
      expect(second.created, isFalse);
      expect(second.media.id, first.media.id);
      expect(libraryFiles(), hasLength(1));
      expect(await db.select(db.savedMediaTable).get(), hasLength(1));
    });

    test('WhatsApp and Business statuses with the same name are distinct', () async {
      final a = access.addStatus(sourceDir, 'same.jpg');
      final b = access.addStatus(sourceDir, 'same.jpg', app: StatusApp.business);
      expect((await service.saveStatus(a)).created, isTrue);
      expect((await service.saveStatus(b)).created, isTrue);
    });

    test('failed copy leaves no row and no file', () async {
      final item = access.addStatus(sourceDir, 'a.jpg');
      access.copyFailures[item.uri] = MediaFailure.lowStorage;
      await expectLater(
        service.saveStatus(item),
        throwsA(isA<MediaAccessError>().having((e) => e.failure, 'failure', MediaFailure.lowStorage)),
      );
      expect(libraryFiles(), isEmpty);
      expect(await db.select(db.savedMediaTable).get(), isEmpty);
    });

    test('a stale row whose file vanished is replaced on re-save', () async {
      final item = access.addStatus(sourceDir, 'a.jpg');
      final first = await service.saveStatus(item);
      File(first.media.path).deleteSync();
      final again = await service.saveStatus(item);
      expect(again.created, isTrue);
      expect(File(again.media.path).existsSync(), isTrue);
      expect(await db.select(db.savedMediaTable).get(), hasLength(1));
    });
  });

  group('saveStatuses (batch)', () {
    test('reports partial failure without aborting the rest', () async {
      final a = access.addStatus(sourceDir, 'a.jpg');
      final b = access.addStatus(sourceDir, 'b.jpg');
      final c = access.addStatus(sourceDir, 'c.jpg');
      access.copyFailures[b.uri] = MediaFailure.sourceUnavailable;

      final progress = <int>[];
      final r = await service.saveStatuses([a, b, c], onProgress: (d, t) => progress.add(d));

      expect(r.saved.map((m) => m.fileName), ['a.jpg', 'c.jpg']);
      expect(r.failed.single.item, b);
      expect(progress, [1, 2, 3]);
      expect(libraryFiles(), hasLength(2));
    });

    test('cancel stops before the next item', () async {
      final items = [for (var i = 0; i < 4; i++) access.addStatus(sourceDir, 'f$i.jpg')];
      var done = 0;
      final r = await service.saveStatuses(
        items,
        onProgress: (d, t) => done = d,
        isCancelled: () => done >= 2,
      );
      expect(r.cancelled, isTrue);
      expect(r.saved, hasLength(2));
      expect(libraryFiles(), hasLength(2));
    });

    test('already-saved items are reported separately', () async {
      final a = access.addStatus(sourceDir, 'a.jpg');
      await service.saveStatus(a);
      final b = access.addStatus(sourceDir, 'b.jpg');
      final r = await service.saveStatuses([a, b]);
      expect(r.alreadySaved, [a]);
      expect(r.saved.map((m) => m.fileName), ['b.jpg']);
    });
  });

  group('importFiles', () {
    ImportCandidate file(String name, List<int> bytes, {String? mime}) {
      final f = File('${sourceDir.path}/$name')..writeAsBytesSync(bytes);
      return ImportCandidate(path: f.path, name: name, mimeType: mime);
    }

    test('imports a photo and keeps the original', () async {
      final c = file('holiday.png', List.filled(500, 3), mime: 'image/png');
      final r = await service.importFiles([c]);
      expect(r.failed, isEmpty);
      final m = r.imported.single;
      expect(m.sourceType, 'imported');
      expect(m.fileName, 'holiday.png');
      expect(File(c.path).existsSync(), isTrue);
      expect(await File(m.path).length(), 500);
    });

    test('rejects unsupported types, corrupt files and empty files; others still import', () async {
      final good = file('ok.jpg', List.filled(100, 1));
      final bad = file('notes.txt', [1, 2, 3]);
      final corrupt = file('broken.jpg', [0xFF, 0xFF, 0xFF, 0]);
      final empty = file('empty.jpg', []);

      final r = await service.importFiles([bad, corrupt, empty, good]);

      expect(r.imported.map((m) => m.fileName), ['ok.jpg']);
      expect(r.failed, hasLength(3));
      // Nothing from the failed items is left behind.
      expect(libraryFiles().where((e) => e.path.endsWith('.part')), isEmpty);
      expect(libraryFiles(), hasLength(1));
      expect(await db.select(db.savedMediaTable).get(), hasLength(1));
    });

    test('missing source reports sourceUnavailable', () async {
      final r = await service.importFiles([
        ImportCandidate(path: '${sourceDir.path}/ghost.jpg', name: 'ghost.jpg'),
      ]);
      final err = r.failed.single.error as MediaAccessError;
      expect(err.failure, MediaFailure.sourceUnavailable);
    });

    test('kindFor uses mime first, then extension', () {
      expect(LibraryService.kindFor(mimeType: 'video/quicktime', name: 'x'), MediaKind.video);
      expect(LibraryService.kindFor(name: 'IMG.HEIC'), MediaKind.image);
      expect(LibraryService.kindFor(name: 'x.pdf'), isNull);
    });
  });

  group('mutations', () {
    test('delete removes file, thumbnail and row after confirmation', () async {
      final item = access.addStatus(sourceDir, 'v.mp4', kind: MediaKind.video);
      final m = (await service.saveStatus(item)).media;
      final r = await service.delete([m.id]);
      expect(r.deleted, 1);
      expect(File(m.path).existsSync(), isFalse);
      expect(File(m.thumbnailPath!).existsSync(), isFalse);
      expect(await db.findById(m.id), isNull);
    });

    test('delete tolerates an already-missing file', () async {
      final m = (await service.saveStatus(access.addStatus(sourceDir, 'a.jpg'))).media;
      File(m.path).deleteSync();
      final r = await service.delete([m.id]);
      expect(r.deleted, 1);
      expect(await db.findById(m.id), isNull);
    });

    test('favourite toggles persist', () async {
      final m = (await service.saveStatus(access.addStatus(sourceDir, 'a.jpg'))).media;
      await service.setFavourite([m.id], true);
      expect((await db.findById(m.id))!.isFavourite, isTrue);
      await service.setFavourite([m.id], false);
      expect((await db.findById(m.id))!.isFavourite, isFalse);
    });

    test('reconcile drops rows whose file is gone and removes leftover .part files', () async {
      final keep = (await service.saveStatus(access.addStatus(sourceDir, 'a.jpg'))).media;
      final gone = (await service.saveStatus(access.addStatus(sourceDir, 'b.jpg'))).media;
      File(gone.path).deleteSync();
      File('${storage.mediaDir.path}/orphan.jpg.part').writeAsStringSync('x');

      final removed = await service.reconcile();

      expect(removed, 1);
      expect(await db.findById(keep.id), isNotNull);
      expect(await db.findById(gone.id), isNull);
      expect(File('${storage.mediaDir.path}/orphan.jpg.part').existsSync(), isFalse);
    });

    test('reconcile sweeps thumbnails that no row references', () async {
      final m = (await service.saveStatus(access.addStatus(sourceDir, 'v.mp4', kind: MediaKind.video))).media;
      final orphan = File('${storage.thumbsDir.path}/orphan.jpg')..writeAsBytesSync([1]);
      await service.reconcile();
      expect(orphan.existsSync(), isFalse);
      expect(File(m.thumbnailPath!).existsSync(), isTrue);
    });

    test('exportToGallery forwards to the platform and surfaces failures', () async {
      final m = (await service.saveStatus(access.addStatus(sourceDir, 'a.jpg'))).media;
      await service.exportToGallery(m);
      expect(access.exported.single['name'], 'a.jpg');

      access.exportFailure = MediaFailure.unsupported;
      await expectLater(service.exportToGallery(m), throwsA(isA<MediaAccessError>()));
    });

    test('exportToGallery on a missing file reports sourceUnavailable', () async {
      final m = (await service.saveStatus(access.addStatus(sourceDir, 'a.jpg'))).media;
      File(m.path).deleteSync();
      await expectLater(
        service.exportToGallery(m),
        throwsA(isA<MediaAccessError>().having((e) => e.failure, 'f', MediaFailure.sourceUnavailable)),
      );
    });
  });

  group('library queries and filters', () {
    test('watchLibrary is newest first and excludes private items', () async {
      final a = (await service.saveStatus(access.addStatus(sourceDir, 'a.jpg'))).media;
      final b = (await service.saveStatus(access.addStatus(sourceDir, 'b.jpg'))).media;
      await (db.update(db.savedMediaTable)..where((t) => t.id.equals(a.id)))
          .write(const SavedMediaTableCompanion(isPrivate: Value(true)));
      final list = await db.watchLibrary().first;
      expect(list.map((m) => m.id), [b.id]);
    });

    test('applyLibraryFilter changes results for every filter and search', () async {
      final img = (await service.saveStatus(access.addStatus(sourceDir, 'pic.jpg'))).media;
      final vid = (await service.saveStatus(access.addStatus(sourceDir, 'clip.mp4', kind: MediaKind.video))).media;
      final biz = (await service.saveStatus(access.addStatus(sourceDir, 'b.jpg', app: StatusApp.business))).media;
      await service.setFavourite([vid.id], true);
      final all = await db.watchLibrary().first;
      final now = DateTime(2026, 10, 24, 13);

      List<String> names(LibraryFilter f, {String q = ''}) =>
          applyLibraryFilter(all, filter: f, query: q, now: now).map((m) => m.fileName).toList()..sort();

      expect(names(LibraryFilter.all), ['b.jpg', 'clip.mp4', 'pic.jpg']);
      expect(names(LibraryFilter.photos), ['b.jpg', 'pic.jpg']);
      expect(names(LibraryFilter.videos), ['clip.mp4']);
      expect(names(LibraryFilter.favourites), ['clip.mp4']);
      expect(names(LibraryFilter.recent), ['b.jpg', 'clip.mp4', 'pic.jpg']);
      expect(names(LibraryFilter.recent, q: 'PIC'), ['pic.jpg']);
      expect(names(LibraryFilter.all, q: 'business'), ['b.jpg']);
      expect(names(LibraryFilter.all, q: 'nomatch'), isEmpty);
      // Recent excludes items saved more than a week ago.
      expect(
        applyLibraryFilter(all, filter: LibraryFilter.recent, now: now.add(const Duration(days: 30))),
        isEmpty,
      );
      expect(img.sourceType, 'status');
      expect(biz.sourceApp, 'business');
    });
  });
}
