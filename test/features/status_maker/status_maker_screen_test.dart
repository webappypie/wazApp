import 'dart:io';
import 'dart:ui' as ui;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:wazapp/core/database/app_database.dart';
import 'package:wazapp/core/error/app_error.dart';
import 'package:wazapp/features/create/presentation/create_screen.dart';
import 'package:wazapp/features/library/data/library_service.dart';
import 'package:wazapp/features/library/data/library_storage.dart';
import 'package:wazapp/features/status_maker/data/status_export_service.dart';
import 'package:wazapp/features/status_maker/domain/status_renderer.dart';
import 'package:wazapp/features/status_maker/domain/status_templates.dart';
import 'package:wazapp/features/status_maker/presentation/status_maker_screen.dart';

import '../../support/fakes.dart';
import '../../support/fonts.dart';
import '../../support/harness.dart';
import '../../support/images.dart';

Widget host(Harness h) => h.wrapRouter([
      GoRoute(path: '/', builder: (_, _) => const CreateScreen()),
      GoRoute(path: '/status-maker', builder: (_, _) => const StatusMakerScreen()),
      GoRoute(path: '/saved', builder: (_, _) => const Scaffold(body: Text('saved tab'))),
    ]);

Finder get outerScrollable =>
    find.descendant(of: find.byType(ListView).first, matching: find.byType(Scrollable)).first;

Future<void> showSave(WidgetTester tester) async {
  await tester.scrollUntilVisible(find.text('Save'), 200, scrollable: outerScrollable);
  await tester.ensureVisible(find.text('Save'));
  await tester.pump();
}

String fieldText(WidgetTester tester) => tester.widget<TextField>(find.byType(TextField)).controller!.text;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadBundledFonts);

  testWidgets('Create lists only working tools and opens the status maker', (tester) async {
    final h = await Harness.create(tester);
    await tester.pumpWidget(host(h));
    await h.settle(tester, 3);

    expect(find.text('Edit a photo'), findsOneWidget);
    expect(find.text('Text status'), findsOneWidget);
    expect(find.textContaining('${kStatusTemplates.length} designs'), findsOneWidget);
    expect(find.textContaining('Video'), findsNothing, reason: 'no control for features that do not exist');

    await tester.tap(find.text('Text status'));
    await h.settle(tester, 3);
    expect(find.text('Your message'), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets('language switch swaps built-in samples but never overwrites the user\'s own text', (tester) async {
    final h = await Harness.create(tester);
    await tester.pumpWidget(h.wrap(const StatusMakerScreen()));
    await h.settle(tester, 3);

    final first = kStatusTemplates.first;
    expect(fieldText(tester), sampleFor(first, StatusLanguage.english));
    await tester.tap(find.text('हिन्दी'));
    await h.settle(tester, 3);
    expect(fieldText(tester), sampleFor(first, StatusLanguage.hindi));
    expect(containsDevanagari(fieldText(tester)), isTrue);

    await tester.enterText(find.byType(TextField), 'मेरा अपना संदेश');
    await h.settle(tester, 3);
    await tester.tap(find.text('English'));
    await h.settle(tester, 3);
    expect(fieldText(tester), 'मेरा अपना संदेश');
    await h.dispose(tester);
  });

  testWidgets('choosing a template changes the text sample and exposes every template by name', (tester) async {
    final h = await Harness.create(tester);
    await tester.pumpWidget(h.wrap(const StatusMakerScreen()));
    await h.settle(tester, 3);

    final target = kStatusTemplates.firstWhere((t) => t.sample != kStatusTemplates.first.sample);
    final tile = find.bySemanticsLabel('${target.name} template');
    await tester.scrollUntilVisible(tile, 120, scrollable: find.byType(Scrollable).at(1));
    await tester.tap(tile);
    await h.settle(tester, 3);
    expect(fieldText(tester), sampleFor(target, StatusLanguage.english));
    await h.dispose(tester);
  });

  testWidgets('Save with empty text is refused; with text it writes a verified 1080x1920 PNG to the library', (tester) async {
    final h = await Harness.create(tester, realProbe: true);
    await tester.pumpWidget(h.wrapRouter([GoRoute(path: '/', builder: (_, _) => const StatusMakerScreen())]));
    await h.settle(tester, 3);

    await tester.enterText(find.byType(TextField), '   ');
    await h.settle(tester, 2);
    await showSave(tester);
    await tester.tap(find.text('Save'));
    await h.settle(tester, 3);
    expect(find.text('Type a message first.'), findsOneWidget);
    expect(await tester.runAsync(() => h.db.select(h.db.savedMediaTable).get()), isEmpty);

    await tester.scrollUntilVisible(find.byType(TextField), -200, scrollable: outerScrollable);
    await tester.enterText(find.byType(TextField), 'शुभ प्रभात! Good morning');
    await h.settle(tester, 2);
    await showSave(tester);
    await tester.tap(find.text('Save'));
    await h.pumpUntil(tester, () => find.text('Saved to your library').evaluate().isNotEmpty);

    final rows = (await tester.runAsync(() => h.db.select(h.db.savedMediaTable).get()))!;
    expect(rows, hasLength(1));
    final row = rows.single;
    expect((row.width, row.height), (1080, 1920));
    expect(row.mimeType, 'image/png');
    expect(row.sourceType, 'created');
    expect(File(row.path).readAsBytesSync().sublist(1, 4), [0x50, 0x4E, 0x47]);
    await tester.pump(const Duration(seconds: 5));
    await h.dispose(tester);
  });

  group('StatusExportService (real codecs)', () {
    late Directory tmp;
    late AppDatabase db;
    late StatusExportService service;

    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('wazapp_status_');
      final storage = LibraryStorage(Directory('${tmp.path}/support'));
      await storage.ensureCreated();
      db = AppDatabase(NativeDatabase.memory());
      final fake = FakeStatusAccess();
      service = StatusExportService(
        library: LibraryService(db: db, storage: storage, status: fake, tools: fake),
        tempDir: Directory('${tmp.path}/t'),
      );
    });

    tearDown(() async {
      await db.close();
      try {
        await tmp.delete(recursive: true);
      } on FileSystemException {
        // ignore on Windows
      }
    });

    test('output decodes to the rendered pixels (Hindi text visible) and no temp file remains', () async {
      final saved = await service.export(
        const StatusDraft(templateId: 'peach', text: 'क्षत्रिय ज्ञान', textColor: 0xFF000000),
      );
      final codec = await ui.instantiateImageCodec(File(saved.path).readAsBytesSync());
      final img = (await codec.getNextFrame()).image;
      expect((img.width, img.height), (1080, 1920));
      final px = await readPixels(img);
      final bg = px.at(5, 5);
      var ink = 0;
      for (var y = 700; y < 1200; y += 2) {
        for (var x = 100; x < 980; x += 2) {
          if (px.at(x, y).$1 < 80 && bg.$1 > 200) ink++;
        }
      }
      expect(ink, greaterThan(300), reason: 'dark glyph pixels in the middle band');
      expect(Directory('${tmp.path}/t').listSync(), isEmpty);
      expect(saved.fileName, matches(RegExp(r'^status_\d{8}_\d{6}\.png$')));
    });

    test('blank text is rejected and nothing is stored', () async {
      await expectLater(service.export(const StatusDraft(templateId: 'peach', text: '  ')), throwsA(isA<AppError>()));
      expect(await db.select(db.savedMediaTable).get(), isEmpty);
    });

    test('every template exports successfully', () async {
      for (final t in kStatusTemplates) {
        final saved = await service.export(StatusDraft(templateId: t.id, text: sampleFor(t, StatusLanguage.hindi)));
        expect((saved.width, saved.height), (1080, 1920), reason: t.id);
      }
      expect(await db.select(db.savedMediaTable).get(), hasLength(kStatusTemplates.length));
    }, timeout: const Timeout(Duration(seconds: 120)));
  });
}
