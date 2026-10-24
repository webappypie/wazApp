import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wazapp/core/database/app_database.dart';
import 'package:wazapp/core/error/app_error.dart';
import 'package:wazapp/features/editor/domain/edit_state.dart';
import 'package:wazapp/features/library/data/library_service.dart';
import 'package:wazapp/features/library/data/library_storage.dart';
import 'package:wazapp/features/library/domain/library_models.dart';
import 'package:wazapp/features/video_editor/data/video_encoder.dart';
import 'package:wazapp/features/video_editor/data/video_export_service.dart';
import 'package:wazapp/features/video_editor/domain/video_edit_state.dart';

import '../../support/fakes.dart';
import '../../support/video_fakes.dart';
import '../../support/images.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;
  late AppDatabase db;
  late LibraryStorage storage;
  late FakeStatusAccess tools;
  late FakeEncoder encoder;
  late EchoProbe probe;
  late LibraryService library;
  late VideoExportService service;
  late SavedMedia source;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('wazapp_video_');
    storage = LibraryStorage(Directory('${tmp.path}/support'));
    await storage.ensureCreated();
    db = AppDatabase(NativeDatabase.memory());
    tools = FakeStatusAccess();
    encoder = FakeEncoder();
    probe = EchoProbe(1280, 720, 10000);
    library = LibraryService(db: db, storage: storage, status: tools, tools: tools, probe: probe);
    service = VideoExportService(
      library: library,
      encoder: encoder,
      tools: tools,
      tempDir: Directory('${tmp.path}/tmp'),
    );
    // A 1280x720, 10 s source already in the library.
    final f = File('${tmp.path}/clip.mp4')..writeAsBytesSync(List.filled(2048, 5));
    source = (await library.importFiles([ImportCandidate(path: f.path, name: 'clip.mp4', mimeType: 'video/mp4')]))
        .imported
        .single;
    // Describe the exported file like the platform would.
    tools.describe = (path, kind) => FileInfo(
          sizeBytes: File(path).lengthSync(),
          width: encoder.last!.plan.outWidth,
          height: encoder.last!.plan.outHeight,
          durationMs: encoder.last!.plan.durationMs,
          hasAudio: !encoder.last!.plan.mute,
        );
    probe
      ..width = 1280
      ..height = 720;
  });

  tearDown(() async {
    await db.close();
    try {
      await tmp.delete(recursive: true);
    } on FileSystemException {
      // ignore on Windows
    }
  });

  Directory tempDir() => Directory('${tmp.path}/tmp');
  List<FileSystemEntity> tempLeftovers() => tempDir().existsSync() ? tempDir().listSync() : [];

  Future<SavedMedia> run(VideoEditState s, {bool audio = true}) {
    // The library probe must agree with what the encoder will produce.
    final plan = planVideoExport(srcWidth: source.width, srcHeight: source.height, state: s);
    probe
      ..width = plan.outWidth
      ..height = plan.outHeight
      ..durationMs = plan.durationMs;
    return service.exportVideo(source: source, state: s, sourceHasAudio: audio);
  }

  test('passes trim, mute, crop and size to the encoder and registers a NEW edited video', () async {
    final state = VideoEditState(
      trimStartMs: 2000,
      trimEndMs: 7000,
      mute: true,
      quality: VideoQuality.p720,
      visual: const EditState(crop: CropRect(0, 0, 0.5, 1)),
    );
    final stages = <VideoExportStage>[];
    final plan = planVideoExport(srcWidth: source.width, srcHeight: source.height, state: state);
    probe
      ..width = plan.outWidth
      ..height = plan.outHeight
      ..durationMs = plan.durationMs;
    final out = await service.exportVideo(
      source: source,
      state: state,
      sourceHasAudio: true,
      onStage: stages.add,
    );
    expect(out.sourceType, 'edited');

    final r = encoder.last!;
    expect(r.inputPath, source.path);
    expect((r.plan.startMs, r.plan.endMs), (2000, 7000));
    expect(r.plan.mute, isTrue);
    expect(r.plan.crop, const CropRect(0, 0, 0.5, 1));
    expect(r.overlayPngPath, isNull, reason: 'no overlays, no overlay layer');
    expect(stages, VideoExportStage.values);
    expect(out.isVideo, isTrue);
    expect(out.isEdited, isTrue);
    expect(out.mimeType, 'video/mp4');
    expect(out.fileName, 'edited_clip.mp4');
    expect(out.id, isNot(source.id));
    expect(File(out.path).existsSync(), isTrue);
    expect(File(source.path).readAsBytesSync(), List.filled(2048, 5), reason: 'original untouched');
    expect(await db.select(db.savedMediaTable).get(), hasLength(2));
    expect(tempLeftovers(), isEmpty);
  });

  test('overlays become a transparent PNG of exactly the output size with ink only where text is', () async {
    final state = VideoEditState(
      trimStartMs: 0,
      trimEndMs: 10000,
      quality: VideoQuality.p720,
      visual: const EditState(
        overlays: [TextOverlay(id: 't', text: 'HELLO', cx: 0.5, cy: 0.5, sizeFrac: 0.2, color: 0xFFFF0000, shadow: false)],
      ),
    );
    await run(state);
    final bytes = encoder.overlayBytes!;
    expect(bytes.sublist(1, 4), [0x50, 0x4E, 0x47]);
    final codec = await instantiate(bytes);
    expect((codec.width, codec.height), (1280, 720));
    final px = await readPixels(codec);
    expect(px.at(2, 2).$4, 0, reason: 'corner is fully transparent');
    var opaque = 0;
    for (var y = 0; y < px.height; y += 2) {
      for (var x = 0; x < px.width; x += 2) {
        if (px.at(x, y).$4 > 200) opaque++;
      }
    }
    expect(opaque, greaterThan(100), reason: 'text pixels are present');
    expect(tempLeftovers(), isEmpty, reason: 'overlay PNG removed after export');
  });

  test('progress is forwarded', () async {
    final seen = <double>[];
    final plan = planVideoExport(srcWidth: 1280, srcHeight: 720, state: VideoEditState.initial(10000));
    probe
      ..width = plan.outWidth
      ..height = plan.outHeight;
    await service.exportVideo(
      source: source,
      state: VideoEditState.initial(10000),
      sourceHasAudio: true,
      onProgress: seen.add,
    );
    expect(seen, [0.5, 1.0]);
  });

  group('failures leave nothing behind', () {
    Future<void> expectNothingAdded() async {
      expect(await db.select(db.savedMediaTable).get(), hasLength(1), reason: 'only the source row');
      expect(storage.mediaDir.listSync().where((e) => !e.path.contains(source.id)), isEmpty);
      expect(tempLeftovers(), isEmpty);
    }

    test('encoder error is surfaced', () async {
      encoder.failWith = const MediaAccessError(MediaFailure.unsupported, message: 'format');
      await expectLater(run(VideoEditState.initial(10000)), throwsA(isA<MediaAccessError>()));
      await expectNothingAdded();
    });

    test('cancel while encoding throws OperationCancelled and cleans up', () async {
      encoder.hold = Completer<void>();
      final fut = run(VideoEditState.initial(10000));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await service.cancel();
      await expectLater(fut, throwsA(isA<OperationCancelled>()));
      expect(encoder.cancelCalled, isTrue);
      await expectNothingAdded();
    });

    test('output of the wrong length is rejected', () async {
      tools.describe = (path, kind) => const FileInfo(sizeBytes: 4096, width: 1280, height: 720, durationMs: 3000, hasAudio: true);
      await expectLater(
        run(VideoEditState.initial(10000)),
        throwsA(isA<MediaAccessError>().having((e) => e.failure, 'failure', MediaFailure.verifyFailed)),
      );
      await expectNothingAdded();
    });

    test('mute requested but file still has audio is rejected', () async {
      tools.describe = (path, kind) => const FileInfo(sizeBytes: 4096, width: 1280, height: 720, durationMs: 10000, hasAudio: true);
      await expectLater(
        run(VideoEditState.initial(10000).copyWith(mute: true)),
        throwsA(isA<MediaAccessError>().having((e) => e.message, 'message', contains('sound'))),
      );
      await expectNothingAdded();
    });

    test('unreadable output (describe fails) is rejected', () async {
      tools.describe = (path, kind) => throw const MediaAccessError(MediaFailure.corrupt, message: 'broken');
      await expectLater(run(VideoEditState.initial(10000)), throwsA(isA<MediaAccessError>()));
      await expectNothingAdded();
    });

    test('missing source and unsupported encoder fail before any work', () async {
      File(source.path).deleteSync();
      await expectLater(
        service.exportVideo(source: source, state: VideoEditState.initial(10000), sourceHasAudio: true),
        throwsA(isA<MediaAccessError>().having((e) => e.failure, 'failure', MediaFailure.sourceUnavailable)),
      );
      expect(encoder.last, isNull);

      final unsupported = VideoExportService(
        library: library,
        encoder: const UnsupportedVideoEncoder(),
        tools: tools,
        tempDir: tempDir(),
      );
      await expectLater(
        unsupported.exportVideo(source: source, state: VideoEditState.initial(10000), sourceHasAudio: true),
        throwsA(isA<MediaAccessError>().having((e) => e.failure, 'failure', MediaFailure.unsupported)),
      );
    });
  });
}

Future<ui.Image> instantiate(Uint8List bytes) async {
  final codec = await ui.instantiateImageCodec(bytes);
  return (await codec.getNextFrame()).image;
}
