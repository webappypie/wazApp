import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wazapp/core/database/app_database.dart';
import 'package:wazapp/core/error/app_error.dart';
import 'package:wazapp/features/editor/data/photo_export_service.dart';
import 'package:wazapp/features/editor/domain/edit_state.dart';
import 'package:wazapp/features/library/data/library_service.dart';
import 'package:wazapp/features/library/data/library_storage.dart';
import 'package:wazapp/features/library/domain/library_models.dart';

import '../../support/fakes.dart';
import '../../support/images.dart';

/// Uses the REAL image codecs and probe: output files are decoded back and inspected.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;
  late AppDatabase db;
  late LibraryStorage storage;
  late LibraryService library;
  late PhotoExportService exporter;
  late SavedMedia source;
  late Uint8List sourceBytes;

  Future<SavedMedia> importPng(ui.Image image, String name) async {
    final bytes = await encodePng(image);
    final f = File('${tmp.path}/$name')..writeAsBytesSync(bytes);
    final r = await library.importFiles([ImportCandidate(path: f.path, name: name, mimeType: 'image/png')]);
    expect(r.failed, isEmpty);
    return r.imported.single;
  }

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('wazapp_export_');
    storage = LibraryStorage(Directory('${tmp.path}/support'));
    await storage.ensureCreated();
    db = AppDatabase(NativeDatabase.memory());
    final fake = FakeStatusAccess();
    library = LibraryService(db: db, storage: storage, status: fake, tools: fake); // real FlutterMediaProbe
    exporter = PhotoExportService(library: library, tempDir: Directory('${tmp.path}/tmp'));
    source = await importPng(await quadrantImage(120, 80), 'src.png');
    sourceBytes = File(source.path).readAsBytesSync();
  });

  tearDown(() async {
    await db.close();
    try {
      await tmp.delete(recursive: true);
    } on FileSystemException {
      // ignore on Windows
    }
  });

  Future<ui.Image> decode(String path) async {
    final codec = await ui.instantiateImageCodec(File(path).readAsBytesSync());
    return (await codec.getNextFrame()).image;
  }

  test('exports a new valid JPEG with the expected dimensions; original is untouched', () async {
    const state = EditState(quarterTurns: 1, crop: CropRect(0, 0, 1, 0.5));
    final stages = <ExportStage>[];
    final out = await exporter.exportPhoto(source: source, state: state, onStage: stages.add);

    expect(stages, ExportStage.values);
    // 120x80 rotated cw = 80x120; crop top half => 80x60
    expect((out.width, out.height), (80, 60));
    final bytes = File(out.path).readAsBytesSync();
    expect(bytes.sublist(0, 3), [0xFF, 0xD8, 0xFF], reason: 'JPEG magic');
    expect(out.mimeType, 'image/jpeg');
    expect(out.sourceType, 'edited');
    expect(out.isEdited, isTrue);
    expect(out.fileName, 'edited_src.jpg');
    expect(out.id, isNot(source.id));

    final img = await decode(out.path);
    expect((img.width, img.height), (80, 60));
    final px = await readPixels(img);
    // After cw rotation the top half is: blue (left) | red (right).
    expect(near(px.at(10, 30), 0, 0, 255, tol: 40), isTrue, reason: 'blue top-left');
    expect(near(px.at(70, 30), 255, 0, 0, tol: 40), isTrue, reason: 'red top-right');

    // Original file and row are unchanged.
    expect(File(source.path).readAsBytesSync(), sourceBytes);
    expect((await db.findById(source.id))!.isEdited, isFalse);
    expect(await db.select(db.savedMediaTable).get(), hasLength(2));
    // No temp leftovers.
    final leftovers = Directory('${tmp.path}/tmp').existsSync() ? Directory('${tmp.path}/tmp').listSync() : [];
    expect(leftovers, isEmpty);
  });

  test('colour adjustments and text overlay appear in the exported pixels', () async {
    final white = await importPng(await solidImage(200, 200, const ui.Color(0xFFFFFFFF)), 'white.png');
    const state = EditState(
      adjust: ColorAdjust(brightness: -0.5),
      overlays: [TextOverlay(id: 't', text: 'HI', color: 0xFFFF0000, shadow: false, sizeFrac: 0.3)],
    );
    final out = await exporter.exportPhoto(source: white, state: state);
    final px = await readPixels(await decode(out.path));
    final corner = px.at(2, 2);
    expect(corner.$1, inInclusiveRange(196, 212), reason: 'brightness -0.5 darkens white to ~204');
    var reddish = 0;
    for (var y = 0; y < px.height; y++) {
      for (var x = 0; x < px.width; x++) {
        final c = px.at(x, y);
        if (c.$1 > 180 && c.$2 < 90 && c.$3 < 90) reddish++;
      }
    }
    expect(reddish, greaterThan(40), reason: 'red text visible');
  });

  test('large images are downscaled to the bound, never upscaled', () async {
    final big = await importPng(await quadrantImage(1600, 800), 'big.png');
    final out = await exporter.exportPhoto(source: big, state: EditState.initial, maxDimension: 400);
    expect(out.width, 400);
    expect(out.height, 200);
    final small = await exporter.exportPhoto(source: source, state: EditState.initial, maxDimension: 4096);
    expect((small.width, small.height), (120, 80));
  });

  test('cancel before encoding leaves no library row, file or temp output', () async {
    var calls = 0;
    await expectLater(
      exporter.exportPhoto(source: source, state: EditState.initial, isCancelled: () => ++calls >= 3),
      throwsA(isA<OperationCancelled>()),
    );
    expect(await db.select(db.savedMediaTable).get(), hasLength(1));
    expect(storage.mediaDir.listSync().where((e) => !e.path.contains(source.id)), isEmpty);
  });

  test('missing or corrupt originals fail with a clear error and add nothing', () async {
    File(source.path).deleteSync();
    await expectLater(
      exporter.exportPhoto(source: source, state: EditState.initial),
      throwsA(isA<MediaAccessError>().having((e) => e.failure, 'failure', MediaFailure.sourceUnavailable)),
    );

    final bad = File('${tmp.path}/bad.png')..writeAsBytesSync(List.filled(500, 3));
    final badRow = SavedMedia(
      id: 'bad',
      path: bad.path,
      kind: 'image',
      mimeType: 'image/png',
      fileName: 'bad.png',
      sizeBytes: 500,
      savedAt: DateTime(2026),
      sourceType: 'imported',
      width: 10,
      height: 10,
      durationMs: 0,
      isFavourite: false,
      isPrivate: false,
      isEdited: false,
    );
    await expectLater(
      exporter.exportPhoto(source: badRow, state: EditState.initial),
      throwsA(isA<MediaAccessError>().having((e) => e.failure, 'failure', MediaFailure.corrupt)),
    );
    // Only the pre-existing source row remains; nothing was added by the failed exports.
    expect(await db.select(db.savedMediaTable).get(), hasLength(1));
  });

  test('addCreatedFile rejects an output whose size differs from the expected one and rolls back', () async {
    final f = File('${tmp.path}/x.png')..writeAsBytesSync(await encodePng(await solidImage(10, 10, const ui.Color(0xFF00FF00))));
    await expectLater(
      library.addCreatedFile(f.path,
          fileName: 'x.png',
          mimeType: 'image/png',
          kind: MediaKind.image,
          sourceType: SourceType.created,
          expectedWidth: 11,
          expectedHeight: 10),
      throwsA(isA<MediaAccessError>().having((e) => e.failure, 'failure', MediaFailure.verifyFailed)),
    );
    expect(await db.select(db.savedMediaTable).get(), hasLength(1)); // only the seeded source
    expect(storage.mediaDir.listSync().where((e) => e.path.endsWith('.png') && !e.path.contains(source.id)), isEmpty);
    expect(storage.mediaDir.listSync().where((e) => e.path.endsWith('.part')), isEmpty);
  });
}
