import 'dart:io';
import 'dart:ui' as ui;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wazapp/core/database/app_database.dart';
import 'package:wazapp/features/library/data/library_service.dart';
import 'package:wazapp/features/library/data/library_storage.dart';
import 'package:wazapp/features/library/domain/library_models.dart';
import 'package:wazapp/features/storage_manager/data/storage_service.dart';
import 'package:wazapp/features/storage_manager/domain/storage_models.dart';

import '../../support/fakes.dart';
import '../../support/images.dart';

/// Distinct synthetic pictures (so fingerprints differ) at any size.
Future<ui.Image> pattern(String kind, int w, int h, {double brightness = 1}) async {
  final rec = ui.PictureRecorder();
  final c = ui.Canvas(rec);
  final rect = ui.Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble());
  int b(int v) => (v * brightness).clamp(0, 255).round();
  switch (kind) {
    case 'ltr': // bright left -> dark right
      c.drawRect(rect, ui.Paint()..shader = ui.Gradient.linear(rect.centerLeft, rect.centerRight, [ui.Color.fromARGB(255, b(255), b(255), b(255)), ui.Color.fromARGB(255, b(10), b(10), b(10))]));
    case 'rtl': // dark left -> bright right
      c.drawRect(rect, ui.Paint()..shader = ui.Gradient.linear(rect.centerLeft, rect.centerRight, [ui.Color.fromARGB(255, b(10), b(10), b(10)), ui.Color.fromARGB(255, b(255), b(255), b(255))]));
    case 'stripes':
      c.drawRect(rect, ui.Paint()..color = ui.Color.fromARGB(255, b(30), b(30), b(30)));
      final n = 8;
      for (var i = 0; i < n; i += 2) {
        c.drawRect(ui.Rect.fromLTWH(w * i / n, 0, w / n, h.toDouble()), ui.Paint()..color = ui.Color.fromARGB(255, b(230), b(230), b(230)));
      }
  }
  return rec.endRecording().toImage(w, h);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;
  late AppDatabase db;
  late LibraryStorage storage;
  late LibraryService library;
  late StorageService service;
  late Directory tempDir;
  var clock = 0;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('wazapp_storage_');
    storage = LibraryStorage(Directory('${tmp.path}/support'));
    await storage.ensureCreated();
    tempDir = Directory('${tmp.path}/export_tmp');
    db = AppDatabase(NativeDatabase.memory());
    final fake = FakeStatusAccess();
    clock = 0;
    library = LibraryService(
      db: db,
      storage: storage,
      status: fake,
      tools: fake,
      probe: FakeProbe(), // size/dimension come from the file via the importers below
      clock: () => DateTime(2026, 10, 25).add(Duration(minutes: clock++)),
    );
    service = StorageService(db: db, storage: storage, library: library, tempDir: tempDir);
  });

  tearDown(() async {
    await db.close();
    try {
      await tmp.delete(recursive: true);
    } on FileSystemException {
      // ignore on Windows
    }
  });

  /// Imports raw bytes as a library item with explicit metadata.
  Future<SavedMedia> addRow(String name, List<int> bytes,
      {MediaKind kind = MediaKind.image, int w = 100, int h = 100, String source = 'imported', bool isPrivate = false}) async {
    final id = storage.newId();
    final ext = name.split('.').last;
    final path = isPrivate ? storage.privatePath(id, ext) : storage.mediaPath(id, ext);
    await File(path).writeAsBytes(bytes);
    await db.insertMedia(SavedMediaTableCompanion.insert(
      id: id,
      path: path,
      kind: kind.name,
      mimeType: kind == MediaKind.video ? 'video/mp4' : 'image/png',
      fileName: name,
      sizeBytes: bytes.length,
      savedAt: DateTime(2026, 10, 25).add(Duration(minutes: clock++)),
      sourceType: source,
    ));
    await db.customStatement('UPDATE saved_media SET width = $w, height = $h, is_private = ${isPrivate ? 1 : 0} WHERE id = ?', [id]);
    return (await db.findById(id))!;
  }

  Future<SavedMedia> addImage(ui.Image image, String name, {String source = 'imported', bool isPrivate = false}) async =>
      addRow(name, await encodePng(image), w: image.width, h: image.height, source: source, isPrivate: isPrivate);

  group('report', () {
    test('measures real file sizes, splits photos/videos/private, and never lists private items', () async {
      final photo = await addRow('p.png', List.filled(2000, 1), source: 'status');
      await addRow('v.mp4', List.filled(5 * 1024 * 1024, 2), kind: MediaKind.video, source: 'imported');
      final secret = await addRow('secret.png', List.filled(3 * 1024 * 1024, 3), isPrivate: true);
      // The stored size is wrong on purpose: the report must trust the disk.
      await db.customStatement('UPDATE saved_media SET size_bytes = 5 WHERE id = ?', [photo.id]);

      final r = await service.report();
      expect((r.photos.count, r.photos.bytes), (1, 2000));
      expect((r.videos.count, r.videos.bytes), (1, 5 * 1024 * 1024));
      expect((r.privateItems.count, r.privateItems.bytes), (1, 3 * 1024 * 1024));
      expect(r.bySource['status'], const SourceUsage(1, 2000));
      expect(r.bySource['imported']!.count, 1);
      expect(r.largeFiles.map((m) => m.fileName), ['v.mp4'], reason: 'private items are never listed');
      expect(r.largeFiles.any((m) => m.id == secret.id), isFalse);
      expect(r.totalBytes, 2000 + 5 * 1024 * 1024 + 3 * 1024 * 1024);
      expect(r.missingIds, isEmpty);
    });

    test('counts thumbnails, temp files, unreferenced files and missing files', () async {
      final video = await addRow('v.mp4', List.filled(1000, 1), kind: MediaKind.video);
      final thumb = File(storage.thumbPath(video.id))..writeAsBytesSync(List.filled(300, 4));
      await db.setThumbnail(video.id, thumb.path);
      final gone = await addRow('gone.png', List.filled(100, 1));
      File(gone.path).deleteSync();
      File('${storage.mediaDir.path}/orphan.jpg').writeAsBytesSync(List.filled(700, 5));
      File('${storage.privateThumbsDir.path}/orphan2.jpg').writeAsBytesSync(List.filled(50, 5));
      tempDir.createSync(recursive: true);
      File('${tempDir.path}/video_1.mp4').writeAsBytesSync(List.filled(900, 6));

      final r = await service.report();
      expect(r.thumbnailBytes, 300);
      expect(r.tempBytes, 900);
      expect(r.unreferenced.map((f) => f.sizeBytes).toList()..sort(), [50, 700]);
      expect(r.unreferencedBytes, 750);
      expect(r.missingIds, [gone.id]);
      // Every byte on disk is accounted for exactly once.
      expect(r.totalBytes, 1000 + 300 + 900 + 750);
    });

    test('large files are sorted largest first and limited', () async {
      final limited = StorageService(
        db: db, storage: storage, library: library, tempDir: tempDir, largeFileMinBytes: 1000, largeFileLimit: 2);
      await addRow('a.png', List.filled(1500, 1));
      await addRow('b.png', List.filled(3000, 2));
      await addRow('c.png', List.filled(2000, 3));
      await addRow('tiny.png', List.filled(10, 4));
      final r = await limited.report();
      expect(r.largeFiles.map((m) => m.fileName), ['b.png', 'c.png']);
    });
  });

  group('duplicates', () {
    test('identical content is found by SHA-256; same size with different content is NOT a duplicate', () async {
      final a = await addRow('a.png', List.filled(4000, 7));
      final b = await addRow('copy_of_a.png', List.filled(4000, 7));
      await addRow('other.png', List.filled(4000, 8)); // same size, different bytes
      await addRow('unique.png', List.filled(123, 9));

      final scan = await service.findDuplicates();
      final identical = scan.groups.where((g) => g.reason == DuplicateReason.identical).toList();
      expect(identical, hasLength(1));
      expect(identical.single.items.map((m) => m.id), [a.id, b.id], reason: 'oldest first');
      expect(identical.single.reclaimableBytes, 4000);
      expect(identical.single.suggestedExtras.map((m) => m.id), [b.id], reason: 'keeps the oldest');
      expect(scan.filesHashed, 3, reason: 'only the 3 files sharing a size were hashed; the unique-size file was not');
      expect((await db.findById(a.id))!.contentHash, isNotNull);

      // Cached: a second scan hashes nothing new.
      final again = await service.findDuplicates();
      expect(again.filesHashed, 0);
      expect(again.groups.where((g) => g.reason == DuplicateReason.identical), hasLength(1));
    });

    test('different media kinds never match even with equal bytes', () async {
      await addRow('x.png', List.filled(2000, 1));
      await addRow('x.mp4', List.filled(2000, 1), kind: MediaKind.video);
      expect((await service.findDuplicates()).groups, isEmpty);
    });

    test('look-alike photos: resized and brightened copies group together; different pictures and rotations do not', () async {
      final big = await addImage(await pattern('ltr', 400, 200), 'big.png');
      final small = await addImage(await pattern('ltr', 100, 50), 'small.png');
      await addImage(await pattern('ltr', 400, 200, brightness: 0.85), 'dim.png');
      await addImage(await pattern('rtl', 400, 200), 'different.png');
      await addImage(await pattern('stripes', 400, 200), 'stripes.png');
      await addImage(await pattern('ltr', 200, 400), 'portrait_same_look.png'); // other aspect ratio

      final scan = await service.findDuplicates();
      final look = scan.groups.where((g) => g.reason == DuplicateReason.lookAlike).toList();
      expect(look, hasLength(1));
      expect(look.single.items.map((m) => m.fileName).toSet(), {'big.png', 'small.png', 'dim.png'});
      expect(look.single.items.first.id, big.id);
      expect(scan.groups.where((g) => g.reason == DuplicateReason.identical), isEmpty);
      expect((await db.findById(small.id))!.visualHash, hasLength(16));
      });

    test('no file is ever suggested for deletion twice (identical extras are not repeated in a look-alike group)', () async {
      final bytes = await encodePng(await pattern('ltr', 200, 100));
      await addRow('a.png', bytes, w: 200, h: 100);
      await addRow('a_copy.png', bytes, w: 200, h: 100);
      await addImage(await pattern('ltr', 100, 50), 'resized.png');
      final scan = await service.findDuplicates();
      final extras = [for (final g in scan.groups) ...g.suggestedExtras.map((m) => m.id)];
      expect(extras.toSet().length, extras.length, reason: 'reclaimable space is never double counted');
      expect(extras, hasLength(2));
      expect(scan.groups.map((g) => g.reason).toSet(), {DuplicateReason.identical, DuplicateReason.lookAlike});
    });

    test('private items are never compared or revealed', () async {
      final bytes = List.filled(3000, 5);
      await addRow('visible.png', bytes);
      await addRow('hidden.png', bytes, isPrivate: true);
      expect((await service.findDuplicates()).groups, isEmpty);
    });

    test('cancel stops hashing without error', () async {
      for (var i = 0; i < 4; i++) {
        await addRow('f$i.png', List.filled(1000, 1));
      }
      var polls = 0;
      final scan = await service.findDuplicates(isCancelled: () => ++polls > 1);
      expect(scan.filesHashed, lessThan(4));
    });

    test('corrupt photos are skipped by the visual comparison instead of failing the scan', () async {
      await addRow('broken1.png', List.filled(500, 0));
      await addRow('broken2.png', List.filled(501, 0));
      final scan = await service.findDuplicates();
      expect(scan.groups, isEmpty);
    });
  });

  group('fingerprints', () {
    test('dHash / hamming basics', () {
      final flat = List.filled(72, 100);
      expect(dHashFromGray9x8(flat), '0' * 16);
      final falling = [for (var y = 0; y < 8; y++) for (var x = 0; x < 9; x++) 255 - x * 20];
      expect(dHashFromGray9x8(falling), 'f' * 16);
      expect(hammingHex('0' * 16, 'f' * 16), 64);
      expect(hammingHex('0' * 16, '0' * 16), 0);
      expect(hammingHex('0000000000000001', '0000000000000000'), 1);
      expect(hammingHex('abc', 'abcd'), 64, reason: 'different lengths never match');
    });

    test('similarShape tolerance', () async {
      final a = await addRow('a.png', [1], w: 400, h: 200);
      final b = await addRow('b.png', [2], w: 401, h: 200);
      final c = await addRow('c.png', [3], w: 200, h: 400);
      final d = await addRow('d.png', [4], w: 0, h: 0);
      expect(similarShape(a, b), isTrue);
      expect(similarShape(a, c), isFalse);
      expect(similarShape(a, d), isFalse);
    });
  });

  group('clean-up actions', () {
    test('deleteUnreferenced removes only unreferenced files inside WazApp directories', () async {
      final kept = await addRow('kept.png', List.filled(100, 1));
      final orphan = File('${storage.mediaDir.path}/orphan.jpg')..writeAsBytesSync(List.filled(200, 2));
      final outside = File('${tmp.path}/not_ours.jpg')..writeAsBytesSync([1, 2, 3]);

      final r = await service.deleteUnreferenced([
        UnreferencedFile(orphan.path, 200),
        UnreferencedFile(outside.path, 3), // outside our directories: refused
        UnreferencedFile(kept.path, 100), // referenced by a row: refused
      ]);
      expect((r.deleted, r.failed, r.bytes), (1, 2, 200));
      expect(orphan.existsSync(), isFalse);
      expect(outside.existsSync(), isTrue);
      expect(File(kept.path).existsSync(), isTrue);
    });

    test('removeBrokenEntries drops rows whose file is gone and keeps healthy ones', () async {
      final ok = await addRow('ok.png', List.filled(10, 1));
      final gone = await addRow('gone.png', List.filled(10, 2));
      File(gone.path).deleteSync();
      expect(await service.removeBrokenEntries([ok.id, gone.id]), 1);
      expect(await db.findById(gone.id), isNull);
      expect(await db.findById(ok.id), isNotNull);
    });

    test('clearTemp deletes scratch files only and reports bytes', () async {
      tempDir.createSync(recursive: true);
      File('${tempDir.path}/a.mp4').writeAsBytesSync(List.filled(400, 1));
      File('${tempDir.path}/b.png').writeAsBytesSync(List.filled(100, 1));
      final keep = await addRow('keep.png', List.filled(10, 1));
      expect(await service.clearTemp(), 500);
      expect(tempDir.listSync(), isEmpty);
      expect(File(keep.path).existsSync(), isTrue);
      expect(await service.clearTemp(), 0);
    });

    test('deleteItems removes files and rows (confirmation is the UI\'s job)', () async {
      final a = await addRow('a.png', List.filled(10, 1));
      final r = await service.deleteItems([a.id]);
      expect(r.deleted, 1);
      expect(File(a.path).existsSync(), isFalse);
      expect(await db.findById(a.id), isNull);
    });
  });

  test('DuplicateGroup math', () async {
    final x = await addRow('x.png', List.filled(100, 1));
    final y = await addRow('y.png', List.filled(100, 1));
    final z = await addRow('z.png', List.filled(100, 1));
    final g = DuplicateGroup(reason: DuplicateReason.identical, items: [x, y, z]);
    expect(g.reclaimableBytes, 200);
    expect(g.suggestedExtras, [y, z]);
  });
}
