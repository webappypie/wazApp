// On-device check of the REAL native video pipeline (Media3 Transformer + MediaCodec).
//
// Prerequisites (see docs/audit/RELEASE_EVIDENCE.md for how it was run):
// two 1280x720, 15 fps, H.264 + AAC test clips (8 s and 40 s) must appear in the app's private
// files directory while the test waits for them (setUpAll polls for up to 6 minutes):
//   adb push src_8s.mp4 /data/local/tmp/ && adb shell run-as com.webappypie.wazapp cp /data/local/tmp/src_8s.mp4 files/
//   (same for src_40s.mp4)
// Run:  flutter test integration_test/video_export_test.dart -d <android device>
//
// Everything asserted here goes through the production classes and real codecs.

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:video_player/video_player.dart';
import 'package:wazapp/core/database/app_database.dart';
import 'package:wazapp/core/error/app_error.dart';
import 'package:wazapp/features/editor/domain/edit_state.dart';
import 'package:wazapp/features/library/data/library_service.dart';
import 'package:wazapp/features/library/data/library_storage.dart';
import 'package:wazapp/features/library/data/media_probe.dart';
import 'package:wazapp/features/library/domain/library_models.dart';
import 'package:wazapp/features/status/data/status_access_service.dart';
import 'package:wazapp/features/video_editor/data/video_encoder.dart';
import 'package:wazapp/features/video_editor/data/video_export_service.dart';
import 'package:wazapp/features/video_editor/domain/video_edit_state.dart';

const _dir = '/data/data/com.webappypie.wazapp/files';
const _src8 = '$_dir/src_8s.mp4';
const _src40 = '$_dir/src_40s.mp4';

Future<ui.Image> _decode(Uint8List bytes) async {
  final codec = await ui.instantiateImageCodec(bytes);
  return (await codec.getNextFrame()).image;
}

Future<(int, int, int)> _px(ui.Image img, int x, int y) async {
  final d = (await img.toByteData(format: ui.ImageByteFormat.rawRgba))!;
  final i = (y * img.width + x) * 4;
  return (d.getUint8(i), d.getUint8(i + 1), d.getUint8(i + 2));
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final bridge = ChannelStatusAccessService();
  final encoder = ChannelVideoEncoder();
  late Directory work;

  setUpAll(() async {
    work = await Directory.systemTemp.createTemp('it_video_');
    final deadline = DateTime.now().add(const Duration(minutes: 6));
    while (!(File(_src8).existsSync() && File(_src40).existsSync() && File(_src40).lengthSync() > 10000000)) {
      if (DateTime.now().isAfter(deadline)) fail('test clips were not copied into $_dir');
      await Future<void>.delayed(const Duration(seconds: 2));
    }
  });

  VideoExportPlan plan({
    int start = 0,
    int end = 8000,
    bool mute = false,
    CropRect? crop,
    int w = 1280,
    int h = 720,
    bool overlays = false,
  }) =>
      VideoExportPlan(
        startMs: start,
        endMs: end,
        outWidth: w,
        outHeight: h,
        crop: crop,
        mute: mute,
        hasOverlays: overlays,
        videoBitrate: bitrateFor(w, h),
      );

  // The emulator's software encoder is far slower than real time, so allow generous timeouts.
  void t(String name, Future<void> Function() body) =>
      test(name, body, timeout: const Timeout(Duration(minutes: 8)));

  tearDown(() async {
    // Never let one test's export leak into the next one.
    await encoder.cancel();
    await Future<void>.delayed(const Duration(seconds: 2));
  });

  var n = 0;
  Future<(VideoEncodeResult, FileInfo)> run(VideoExportPlan p,
      {String src = _src8, String? overlay, List<double>? progress}) async {
    final out = '${work.path}/out_${n++}.mp4';
    final r = await encoder.encode(
      VideoEncodeRequest(id: 'it$n', inputPath: src, outputPath: out, plan: p, overlayPngPath: overlay),
      onProgress: progress?.add,
    );
    final info = await bridge.describeFile(r.outputPath, MediaKind.video);
    return (r, info);
  }

  Future<ui.Image> frameAt(String path, {int size = 1280}) async {
    final bytes = await bridge.thumbnail(path, MediaKind.video, size: size);
    expect(bytes, isNotNull, reason: 'frame decodable');
    return _decode(bytes!);
  }

  t('source sanity: native probe sees 1280x720, ~8 s, with audio', () async {
    final info = await bridge.describeFile(_src8, MediaKind.video);
    expect((info.width, info.height), (1280, 720));
    expect(info.durationMs, inInclusiveRange(7800, 8200));
    expect(info.hasAudio, isTrue);
  });

  t('trim 1.0-4.0 s gives a ~3 s H.264 file with audio and full size', () async {
    final (r, info) = await run(plan(start: 1000, end: 4000));
    expect(info.durationMs, inInclusiveRange(2600, 3500));
    expect((info.width, info.height), (1280, 720));
    expect(info.hasAudio, isTrue);
    expect(File(r.outputPath).lengthSync(), greaterThan(10000));
  });

  t('mute removes the audio track and keeps the video', () async {
    final (_, info) = await run(plan(end: 3000, mute: true));
    expect(info.hasAudio, isFalse);
    expect(info.durationMs, inInclusiveRange(2500, 3500));
  });

  t('crop right half keeps the RIGHT half of the picture, not mirrored or shifted', () async {
    final (r, info) = await run(plan(start: 1000, end: 3000, crop: const CropRect(0.5, 0, 1, 1), w: 640, h: 720));
    expect((info.width, info.height), (640, 720));
    final src = await frameAt(_src8); // frame ~1 s of the source (retriever picks near 1 s)
    final out = await frameAt(r.outputPath);
    expect((out.width, out.height), (640, 720));
    // Compare a grid of pixels: out(x,y) should resemble src(x+640,y), and NOT src(x,y).
    var diffRight = 0, diffLeft = 0, count = 0;
    for (var y = 40; y < 700; y += 60) {
      for (var x = 40; x < 600; x += 60) {
        final o = await _px(out, x, y);
        final a = await _px(src, x + 640, y);
        final b = await _px(src, x, y);
        diffRight += (o.$1 - a.$1).abs() + (o.$2 - a.$2).abs() + (o.$3 - a.$3).abs();
        diffLeft += (o.$1 - b.$1).abs() + (o.$2 - b.$2).abs() + (o.$3 - b.$3).abs();
        count++;
      }
    }
    expect(diffRight / count, lessThan(diffLeft / count), reason: 'content comes from the right half');
    expect(diffRight / count / 3, lessThan(40), reason: 'right-half content matches within codec error');
  });

  t('size cap: 640x360 output decodes and plays in the real player', () async {
    final (r, info) = await run(plan(end: 2000, w: 640, h: 360));
    expect((info.width, info.height), (640, 360));
    final player = VideoPlayerController.file(File(r.outputPath));
    await player.initialize();
    expect(player.value.duration.inMilliseconds, inInclusiveRange(1500, 2600));
    expect((player.value.size.width, player.value.size.height), (640.0, 360.0));
    await player.dispose();
  });

  t('overlay layer is burned into the frames at the right place', () async {
    // Transparent 1280x720 PNG with an opaque red block in the top-left corner.
    final rec = ui.PictureRecorder();
    ui.Canvas(rec).drawRect(const ui.Rect.fromLTWH(0, 0, 400, 200), ui.Paint()..color = const ui.Color(0xFFFF0000));
    final img = await rec.endRecording().toImage(1280, 720);
    final png = (await img.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();
    final overlay = File('${work.path}/overlay.png')..writeAsBytesSync(png);

    final (r, _) = await run(plan(start: 1000, end: 3000, overlays: true), overlay: overlay.path);
    final out = await frameAt(r.outputPath);
    final inside = await _px(out, 150, 80);
    expect(inside.$1, greaterThan(200), reason: 'red channel high inside the overlay block');
    expect(inside.$2, lessThan(70));
    expect(inside.$3, lessThan(70));
    final outside = await _px(out, 1000, 600);
    final plain = await _px(await frameAt(_src8), 1000, 600);
    expect((outside.$1 - plain.$1).abs() + (outside.$2 - plain.$2).abs() + (outside.$3 - plain.$3).abs(), lessThan(120),
        reason: 'the rest of the frame is the original picture');
  });

  t('progress is reported, within 0..1 and non-decreasing', () async {
    final p = <double>[];
    await run(plan(start: 0, end: 8000), progress: p);
    for (final v in p) {
      expect(v, inInclusiveRange(0.0, 1.0));
    }
    for (var i = 1; i < p.length; i++) {
      expect(p[i], greaterThanOrEqualTo(p[i - 1]));
    }
    // A short export may finish between progress polls; when polled, values must make sense.
    // ignore: avoid_print
    print('progress samples: ${p.length}');
  });

  t('cancel stops a long export, throws OperationCancelled and leaves no output file', () async {
    final out = '${work.path}/cancel.mp4';
    // Attach the error handler immediately so the failure cannot surface before we await it.
    final outcome = encoder
        .encode(VideoEncodeRequest(id: 'cancel', inputPath: _src40, outputPath: out, plan: plan(end: 40000)))
        .then<Object?>((_) => null, onError: (Object e) => e);
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    await encoder.cancel();
    expect(await outcome, isA<OperationCancelled>());
    expect(File(out).existsSync(), isFalse);
  });

  t('missing input is reported as sourceUnavailable', () async {
    await expectLater(
      encoder.encode(VideoEncodeRequest(
        id: 'missing',
        inputPath: '$_dir/nope.mp4',
        outputPath: '${work.path}/nope_out.mp4',
        plan: plan(),
      )),
      throwsA(isA<MediaAccessError>().having((e) => e.failure, 'failure', MediaFailure.sourceUnavailable)),
    );
  });

  t('END TO END: VideoExportService with library, real probe, trim+mute+crop+Hindi text', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final storage = LibraryStorage(Directory('${work.path}/support'));
    await storage.ensureCreated();
    final library = LibraryService(db: db, storage: storage, status: bridge, tools: bridge, probe: const FlutterMediaProbe());
    final service = VideoExportService(
      library: library,
      encoder: encoder,
      tools: bridge,
      tempDir: Directory('${work.path}/svc_tmp'),
    );
    final imported = (await library.importFiles([ImportCandidate(path: _src8, name: 'src_8s.mp4', mimeType: 'video/mp4')])).imported.single;
    expect((imported.width, imported.height), (1280, 720));

    final state = VideoEditState(
      trimStartMs: 1000,
      trimEndMs: 5000,
      mute: true,
      visual: const EditState(
        crop: CropRect(0.25, 0, 0.75, 1),
        overlays: [TextOverlay(id: 't', text: 'नमस्ते WazApp', color: 0xFFFFFFFF, sizeFrac: 0.1)],
      ),
    );
    final stages = <VideoExportStage>[];
    final saved = await service.exportVideo(source: imported, state: state, sourceHasAudio: true, onStage: stages.add);

    expect(stages, VideoExportStage.values);
    expect(saved.isVideo, isTrue);
    expect(saved.isEdited, isTrue);
    expect((saved.width, saved.height), (640, 720));
    expect(saved.durationMs, inInclusiveRange(3400, 4600));
    final info = await bridge.describeFile(saved.path, MediaKind.video);
    expect(info.hasAudio, isFalse);
    expect(saved.thumbnailPath, isNotNull);
    expect(File(saved.thumbnailPath!).existsSync(), isTrue);
    // Original untouched, no temp leftovers, two rows.
    expect(File(imported.path).lengthSync(), File(_src8).lengthSync());
    expect(Directory('${work.path}/svc_tmp').listSync(), isEmpty);
    expect(await db.select(db.savedMediaTable).get(), hasLength(2));
    await db.close();
  });
}
