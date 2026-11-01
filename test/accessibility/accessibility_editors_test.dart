// Accessibility checks for the screens that need seeded media: the photo editor, the video editor,
// the viewer and onboarding. Same guidelines as accessibility_test.dart (tap targets, labels, contrast)
// plus a 2.0x text-size overflow check. Needs a person with TalkBack for reading order (see
// docs/audit/ACCESSIBILITY_AUDIT.md).

import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';
import 'package:wazapp/core/database/app_database.dart';
import 'package:wazapp/features/editor/presentation/photo_editor_screen.dart';
import 'package:wazapp/features/library/data/library_service.dart';
import 'package:wazapp/features/library/presentation/saved_screen.dart' show ViewerArgs;
import 'package:wazapp/features/library/presentation/viewer_screen.dart';
import 'package:wazapp/features/onboarding/presentation/onboarding_screen.dart';
import 'package:wazapp/features/video_editor/presentation/video_editor_screen.dart';

import '../support/harness.dart';
import '../support/images.dart';
import '../support/video_fakes.dart';

Future<String> seedPhoto(WidgetTester tester, Harness h) async => (await tester.runAsync(() async {
      final bytes = await encodePng(await quadrantImage(120, 80));
      final f = File('${h.sourceDir.path}/photo.png')..writeAsBytesSync(bytes);
      final service = LibraryService(db: h.db, storage: h.storage, status: h.access, tools: h.access);
      final r = await service.importFiles([ImportCandidate(path: f.path, name: 'photo.png', mimeType: 'image/png')]);
      return r.imported.single.id;
    }))!;

Future<void> seedVideo(WidgetTester tester, Harness h) async => tester.runAsync(() async {
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
    });

void phone(WidgetTester tester, {Brightness brightness = Brightness.light, double textScale = 1.0}) {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3.0;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  tester.platformDispatcher.platformBrightnessTestValue = brightness;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    tester.platformDispatcher.clearAllTestValues();
  });
}

typedef Opener = Future<void> Function(WidgetTester tester, Harness h);

Widget app(Harness h, String initial, List<RouteBase> routes) => h.wrapRouter(routes, initial: initial);

class Case {
  Case(this.name, {required this.make, required this.waitFor, this.onboarded = true, this.tool});
  final String name;

  /// Bottom-bar tool to open before checking (editors).
  final String? tool;
  final Future<(Harness, Widget)> Function(WidgetTester) make;
  final String waitFor; // tooltip/text that proves the screen is ready
  final bool onboarded;
}

Future<void> ready(WidgetTester tester, Harness h, String marker) async {
  await h.pumpUntil(tester, () => find.byTooltip(marker).evaluate().isNotEmpty || find.text(marker).evaluate().isNotEmpty);
  await h.settle(tester, 6);
}

Future<void> openTool(WidgetTester tester, Harness h, String? tool) async {
  if (tool == null) return;
  await tester.tap(find.text(tool).last);
  await h.settle(tester, 8);
}

final List<Case> cases = [
  Case('Onboarding', waitFor: 'Skip', onboarded: false, make: (tester) async {
    final h = await Harness.create(tester, onboarded: false);
    return (h, app(h, '/', [GoRoute(path: '/', builder: (_, _) => const OnboardingScreen())]));
  }),
  Case('Photo editor', waitFor: 'Undo', make: (tester) async {
    final h = await Harness.create(tester);
    final id = await seedPhoto(tester, h);
    return (h, app(h, '/', [GoRoute(path: '/', builder: (_, _) => PhotoEditorScreen(mediaId: id))]));
  }),
  Case('Video editor', waitFor: 'Undo', make: (tester) async {
    VideoPlayerPlatform.instance = FakeVideoPlayerPlatform();
    final h = await Harness.create(tester, probe: EchoProbe(1920, 1080, 10000), encoder: FakeEncoder());
    await seedVideo(tester, h);
    return (h, app(h, '/', [GoRoute(path: '/', builder: (_, _) => const VideoEditorScreen(mediaId: 'vid1'))]));
  }),
  Case('Viewer (photo)', waitFor: 'Share', make: (tester) async {
    final h = await Harness.create(tester);
    final id = await seedPhoto(tester, h);
    return (h, app(h, '/', [GoRoute(path: '/', builder: (_, _) => ViewerScreen(args: ViewerArgs(ids: [id], index: 0)))]));
  }),
];

List<Case> withTools() {
  Case base(String n) => cases.firstWhere((c) => c.name == n);
  Case variant(String n, String tool) {
    final b = base(n);
    return Case('$n / $tool', make: b.make, waitFor: b.waitFor, tool: tool);
  }

  return [
    ...cases,
    for (final t in ['Crop', 'Filters', 'Text', 'Stickers']) variant('Photo editor', t),
    for (final t in ['Crop', 'Text', 'Stickers', 'Output']) variant('Video editor', t),
  ];
}

void main() {
  for (final c in withTools()) {
    for (final brightness in Brightness.values) {
      testWidgets('${c.name} (${brightness.name}): tap targets, labels and contrast', (tester) async {
        final handle = tester.ensureSemantics();
        phone(tester, brightness: brightness);
        final (h, widget) = await c.make(tester);
        await tester.pumpWidget(widget);
        await ready(tester, h, c.waitFor);
        await openTool(tester, h, c.tool);
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        await h.dispose(tester);
        handle.dispose();
      });
    }

    testWidgets('${c.name}: no overflow at 2.0x text size', (tester) async {
      final errors = <String>[];
      final previous = FlutterError.onError;
      phone(tester, textScale: 2.0);
      final (h, widget) = await c.make(tester);
      FlutterError.onError = (details) {
        final where = RegExp(r'lib/[a-z_/]+\.dart:\d+').allMatches(details.toString()).map((m) => m.group(0)).toSet();
        errors.add('${details.exceptionAsString().trim().split(RegExp(r'[\r\n]+')).first} @ ${where.join(', ')}');
      };
      try {
        await tester.pumpWidget(widget);
        await ready(tester, h, c.waitFor);
        await openTool(tester, h, c.tool);
      } catch (e) {
        errors.add('scenario failed: ${e.toString().split(RegExp(r'[\r\n]+')).first}');
      } finally {
        FlutterError.onError = previous;
      }
      await h.dispose(tester);
      expect(errors.toSet(), isEmpty, reason: '${c.name} overflows or throws at 2.0x text');
    });
  }
}
