import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';
import 'package:wazapp/core/database/app_database.dart';
import 'package:wazapp/core/error/app_error.dart';
import 'package:wazapp/features/create/presentation/create_screen.dart';
import 'package:wazapp/features/library/domain/library_models.dart';
import 'package:wazapp/features/video_editor/data/video_encoder.dart';
import 'package:wazapp/features/video_editor/presentation/video_editor_screen.dart';

import '../../support/harness.dart';
import '../../support/video_fakes.dart';

/// A 1920x1080, 10 s video row backed by a real (placeholder) file.
Future<SavedMedia> seedVideo(WidgetTester tester, Harness h, {bool silent = false}) async {
  return (await tester.runAsync(() async {
    final f = File('${h.storage.mediaDir.path}/clip.mp4')..writeAsBytesSync(List.filled(4096, 3));
    await h.db.insertMedia(SavedMediaTableCompanion.insert(
      id: 'vid1',
      path: f.path,
      kind: 'video',
      mimeType: 'video/mp4',
      fileName: 'clip.mp4',
      sizeBytes: 4096,
      savedAt: DateTime(2026, 10, 24),
      sourceType: 'imported',
      width: const Value(1920),
      height: const Value(1080),
      durationMs: const Value(10000),
    ));
    return (await h.db.findById('vid1'))!;
  }))!;
}

Widget host(Harness h) => h.wrapRouter([
      GoRoute(
        path: '/',
        builder: (c, _) => Scaffold(
          body: Center(child: FilledButton(onPressed: () => c.push('/editor'), child: const Text('open'))),
        ),
      ),
      GoRoute(path: '/saved', builder: (_, _) => const Scaffold(body: Text('saved tab'))),
      GoRoute(path: '/editor', builder: (_, _) => const VideoEditorScreen(mediaId: 'vid1')),
    ]);

Future<void> openEditor(WidgetTester tester, Harness h) async {
  await tester.pumpWidget(host(h));
  await h.settle(tester, 3);
  await tester.tap(find.text('open'));
  await h.pumpUntil(tester, () => find.byTooltip('Undo').evaluate().isNotEmpty);
  await h.settle(tester, 4);
}

bool canSave(WidgetTester tester) => tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Save')).onPressed != null;

void main() {
  late FakeVideoPlayerPlatform platform;
  late FakeEncoder encoder;
  late EchoProbe probe;
  late Harness h;

  setUp(() {
    platform = FakeVideoPlayerPlatform();
    VideoPlayerPlatform.instance = platform;
    encoder = FakeEncoder();
    probe = EchoProbe(1920, 1080, 10000);
  });

  Future<Harness> make(WidgetTester tester, {bool audio = true}) async {
    h = await Harness.create(tester, probe: probe, encoder: encoder);
    h.access.describe = (path, kind) {
      final plan = encoder.last?.plan;
      return FileInfo(
        sizeBytes: File(path).existsSync() ? File(path).lengthSync() : 1,
        width: plan?.outWidth ?? 1920,
        height: plan?.outHeight ?? 1080,
        durationMs: plan?.durationMs ?? 10000,
        hasAudio: plan == null ? audio : !plan.mute && audio,
      );
    };
    return h;
  }

  testWidgets('fresh editor: nothing to save; only size caps that really shrink the video are offered', (tester) async {
    await make(tester);
    await seedVideo(tester, h);
    await openEditor(tester, h);

    expect(find.text('Edit video'), findsOneWidget);
    expect(canSave(tester), isFalse);
    for (final t in ['Trim', 'Crop', 'Text', 'Stickers', 'Output']) {
      expect(find.text(t), findsWidgets);
    }
    expect(find.text('Sharpness'), findsNothing);

    await tester.tap(find.text('Output'));
    await h.settle(tester, 3);
    expect(find.text('Original'), findsOneWidget);
    expect(find.text('720p'), findsOneWidget);
    expect(find.text('1080p'), findsNothing, reason: 'cap equals the source size, so it would change nothing');
    expect(find.textContaining('1920 × 1080'), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets('trim changes the plan and the displayed length; undo restores it', (tester) async {
    await make(tester);
    await seedVideo(tester, h);
    await openEditor(tester, h);

    final slider = find.byType(RangeSlider);
    final rect = tester.getRect(slider);
    // drag the END handle (right side) to the middle
    await tester.dragFrom(Offset(rect.right - 24, rect.center.dy), Offset(-(rect.width / 2), 0));
    await h.settle(tester, 3);
    expect(canSave(tester), isTrue);
    expect(find.textContaining('Length 0:0'), findsOneWidget); // roughly 5 s
    await tester.tap(find.byTooltip('Undo'));
    await h.settle(tester, 3);
    expect(canSave(tester), isFalse);
    expect(find.text('Length 0:10'), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets('mute is offered only when the video has sound', (tester) async {
    await make(tester, audio: false);
    await seedVideo(tester, h);
    await openEditor(tester, h);
    await tester.tap(find.text('Output'));
    await h.settle(tester, 3);
    expect(tester.widget<SwitchListTile>(find.byType(SwitchListTile)).onChanged, isNull);
    expect(find.text('This video has no sound'), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets('trim + mute + 9:16 crop + 720p + Hindi text -> encoder receives exactly that, new item saved', (tester) async {
    await make(tester);
    await seedVideo(tester, h);
    await openEditor(tester, h);

    // Trim: move the start handle right.
    final rect = tester.getRect(find.byType(RangeSlider));
    await tester.dragFrom(Offset(rect.left + 24, rect.center.dy), Offset(rect.width * 0.3, 0));
    await h.settle(tester, 3);

    await tester.tap(find.text('Output'));
    await h.settle(tester, 3);
    await tester.tap(find.byType(SwitchListTile));
    await h.settle(tester, 3);
    await tester.tap(find.text('720p'));
    await h.settle(tester, 3);

    await tester.tap(find.text('Crop').last);
    await h.settle(tester, 3);
    await tester.tap(find.text('9:16'));
    await h.settle(tester, 3);

    await tester.tap(find.text('Text').last);
    await h.settle(tester, 3);
    await tester.tap(find.text('Add text'));
    await h.settle(tester, 3);
    await tester.enterText(find.byType(TextField), 'नमस्ते');
    await tester.tap(find.text('Done'));
    await h.settle(tester, 3);

    // Encoder output must agree with what the library probe sees; prepare after the plan is known.
    encoder.produce = (r) {
      probe
        ..width = r.plan.outWidth
        ..height = r.plan.outHeight
        ..durationMs = r.plan.durationMs;
      return VideoEncodeResult(
        outputPath: r.outputPath,
        width: r.plan.outWidth,
        height: r.plan.outHeight,
        durationMs: r.plan.durationMs,
      );
    };
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await h.pumpUntil(tester, () => find.textContaining('Saved as a new video').evaluate().isNotEmpty);

    final r = encoder.last!;
    expect(r.plan.startMs, greaterThan(1500));
    expect(r.plan.endMs, 10000);
    expect(r.plan.mute, isTrue);
    expect(r.plan.crop, isNotNull);
    final c = r.plan.crop!;
    expect(((c.width * 1920) / (c.height * 1080) - 9 / 16).abs(), lessThan(0.01));
    expect(r.plan.outHeight, lessThanOrEqualTo(1280));
    expect(r.plan.outWidth.isEven && r.plan.outHeight.isEven, isTrue);
    expect(r.plan.hasOverlays, isTrue);
    expect(r.overlayPngPath, isNotNull);
    expect(r.inputPath, isNot(contains('export')), reason: 'the original is the input');

    final rows = (await tester.runAsync(() => h.db.select(h.db.savedMediaTable).get()))!;
    expect(rows, hasLength(2));
    final edited = rows.firstWhere((x) => x.isEdited);
    expect(edited.kind, 'video');
    expect(edited.mimeType, 'video/mp4');
    expect(File(rows.firstWhere((x) => !x.isEdited).path).readAsBytesSync(), List.filled(4096, 3));
    expect(find.text('open'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await h.dispose(tester);
  });

  testWidgets('Cancel in the progress dialog stops the export and saves nothing', (tester) async {
    await make(tester);
    await seedVideo(tester, h);
    encoder.hold = Completer<void>();
    await openEditor(tester, h);
    await tester.tap(find.text('Output'));
    await h.settle(tester, 3);
    await tester.tap(find.byType(SwitchListTile));
    await h.settle(tester, 3);

    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await h.pumpUntil(tester, () => find.text('Saving video').evaluate().isNotEmpty);
    expect(find.text('Saving video'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await h.pumpUntil(tester, () => find.textContaining('Cancelled').evaluate().isNotEmpty);

    expect(encoder.cancelCalled, isTrue);
    expect(find.textContaining('Cancelled. Nothing was saved.'), findsOneWidget);
    expect(await tester.runAsync(() => h.db.select(h.db.savedMediaTable).get()), hasLength(1));
    await tester.pump(const Duration(seconds: 5));
    await h.dispose(tester);
  });

  testWidgets('encoder failure shows a clear message with retry; nothing is saved', (tester) async {
    await make(tester);
    await seedVideo(tester, h);
    encoder.failWith = const MediaAccessError(MediaFailure.unsupported, message: 'This video format cannot be edited on this device.');
    await openEditor(tester, h);
    await tester.tap(find.text('Output'));
    await h.settle(tester, 3);
    await tester.tap(find.byType(SwitchListTile));
    await h.settle(tester, 3);
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await h.pumpUntil(tester, () => find.text('Could not save').evaluate().isNotEmpty);

    expect(find.text('This video format cannot be edited on this device.'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    expect(await tester.runAsync(() => h.db.select(h.db.savedMediaTable).get()), hasLength(1));
    await tester.tap(find.text('Close'));
    await h.settle(tester, 3);
    await h.dispose(tester);
  });

  testWidgets('closing with unsaved edits asks for confirmation', (tester) async {
    await make(tester);
    await seedVideo(tester, h);
    await openEditor(tester, h);
    await tester.tap(find.text('Output'));
    await h.settle(tester, 3);
    await tester.tap(find.byType(SwitchListTile));
    await h.settle(tester, 3);
    await tester.tap(find.byTooltip('Close editor'));
    await h.settle(tester, 3);
    expect(find.text('Discard changes?'), findsOneWidget);
    await tester.tap(find.text('Discard'));
    await h.settle(tester, 3);
    expect(find.text('open'), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets('Create shows "Edit a video" only where an encoder exists', (tester) async {
    h = await Harness.create(tester, encoder: const UnsupportedVideoEncoder());
    await tester.pumpWidget(h.wrapRouter([GoRoute(path: '/', builder: (_, _) => const CreateScreen())]));
    await h.settle(tester, 3);
    expect(find.text('Edit a video'), findsNothing);
    expect(find.text('Edit a photo'), findsOneWidget);
    await h.dispose(tester);

    h = await Harness.create(tester, encoder: FakeEncoder());
    await tester.pumpWidget(h.wrapRouter([GoRoute(path: '/', builder: (_, _) => const CreateScreen())]));
    await h.settle(tester, 3);
    expect(find.text('Edit a video'), findsOneWidget);
    await h.dispose(tester);
  });
}
