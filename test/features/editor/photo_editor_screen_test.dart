import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:wazapp/features/editor/presentation/photo_editor_screen.dart';
import 'package:wazapp/features/library/data/library_service.dart';

import '../../support/harness.dart';
import '../../support/images.dart';

/// Imports a real 120x80 PNG and returns its library id.
Future<String> seedPhoto(WidgetTester tester, Harness h) async {
  final id = await tester.runAsync(() async {
    final bytes = await encodePng(await quadrantImage(120, 80));
    final f = File('${h.sourceDir.path}/photo.png')..writeAsBytesSync(bytes);
    final service = LibraryService(db: h.db, storage: h.storage, status: h.access, tools: h.access);
    final r = await service.importFiles([ImportCandidate(path: f.path, name: 'photo.png', mimeType: 'image/png')]);
    return r.imported.single.id;
  });
  return id!;
}

Widget host(Harness h, String id) => h.wrapRouter([
      GoRoute(
        path: '/',
        builder: (c, _) => Scaffold(
          body: Center(child: FilledButton(onPressed: () => c.push('/editor'), child: const Text('open'))),
        ),
      ),
      GoRoute(path: '/saved', builder: (_, _) => const Scaffold(body: Text('saved tab'))),
      GoRoute(path: '/editor', builder: (_, _) => PhotoEditorScreen(mediaId: id)),
    ]);

Future<void> openEditor(WidgetTester tester, Harness h, String id) async {
  await tester.pumpWidget(host(h, id));
  await h.settle(tester, 3);
  await tester.tap(find.text('open'));
  await h.pumpUntil(tester, () => find.byTooltip('Undo').evaluate().isNotEmpty);
  await h.settle(tester, 3);
}

bool enabled(WidgetTester tester, Finder f) => tester.widget<IconButton>(f).onPressed != null;

bool canSave(WidgetTester tester) =>
    tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Save')).onPressed != null;

void main() {
  testWidgets('fresh editor: nothing to save, undo/redo/reset disabled, all five tools present', (tester) async {
    final h = await Harness.create(tester);
    final id = await seedPhoto(tester, h);
    await openEditor(tester, h, id);

    expect(find.text('Edit photo'), findsOneWidget);
    expect(enabled(tester, find.widgetWithIcon(IconButton, Icons.undo)), isFalse);
    expect(enabled(tester, find.widgetWithIcon(IconButton, Icons.redo)), isFalse);
    expect(enabled(tester, find.widgetWithIcon(IconButton, Icons.restart_alt)), isFalse);
    expect(canSave(tester), isFalse);
    for (final t in ['Adjust', 'Crop', 'Filters', 'Text', 'Stickers']) {
      expect(find.text(t), findsWidgets);
    }
    await h.dispose(tester);
  });

  testWidgets('adjust slider, rotate, filter and text all change real state; undo/redo/reset follow', (tester) async {
    final h = await Harness.create(tester);
    final id = await seedPhoto(tester, h);
    await openEditor(tester, h, id);

    // A slider drag is one undo step.
    await tester.drag(find.byType(Slider).first, const Offset(60, 0));
    await h.settle(tester, 3);
    expect(enabled(tester, find.widgetWithIcon(IconButton, Icons.undo)), isTrue);
    expect(canSave(tester), isTrue);
    await tester.tap(find.byTooltip('Undo'));
    await h.settle(tester, 3);
    expect(enabled(tester, find.widgetWithIcon(IconButton, Icons.undo)), isFalse);
    expect(enabled(tester, find.widgetWithIcon(IconButton, Icons.redo)), isTrue);
    await tester.tap(find.byTooltip('Redo'));
    await h.settle(tester, 3);
    expect(enabled(tester, find.widgetWithIcon(IconButton, Icons.undo)), isTrue);

    // Rotate (crop tool), then reset everything; reset itself is undoable.
    await tester.tap(find.text('Crop').last);
    await h.settle(tester, 3);
    await tester.tap(find.text('Rotate right'));
    await h.settle(tester, 3);
    await tester.tap(find.byTooltip('Reset all edits'));
    await h.settle(tester, 3);
    expect(canSave(tester), isFalse);
    await tester.tap(find.byTooltip('Undo'));
    await h.settle(tester, 3);
    expect(canSave(tester), isTrue);
    await h.dispose(tester);
  });

  testWidgets('add Hindi text through the dialog; text controls appear for the selected text', (tester) async {
    final h = await Harness.create(tester);
    final id = await seedPhoto(tester, h);
    await openEditor(tester, h, id);

    await tester.tap(find.text('Text').last);
    await h.settle(tester, 3);
    await tester.tap(find.text('Add text'));
    await h.settle(tester, 3);
    await tester.enterText(find.byType(TextField), 'नमस्ते');
    await tester.tap(find.text('Done'));
    await h.settle(tester, 3);

    expect(find.text('Edit text'), findsOneWidget);
    expect(find.text('Outline'), findsOneWidget);
    expect(find.byTooltip('Delete text'), findsOneWidget);
    expect(enabled(tester, find.widgetWithIcon(IconButton, Icons.undo)), isTrue);

    await tester.tap(find.byTooltip('Delete text'));
    await h.settle(tester, 3);
    expect(find.text('Add text'), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets('closing with unsaved edits asks for confirmation; Keep editing stays', (tester) async {
    final h = await Harness.create(tester);
    final id = await seedPhoto(tester, h);
    await openEditor(tester, h, id);
    await tester.tap(find.text('Filters').last);
    await h.settle(tester, 3);
    await tester.tap(find.text('Sepia'));
    await h.settle(tester, 3);

    await tester.tap(find.byTooltip('Close editor'));
    await h.settle(tester, 3);
    expect(find.text('Discard changes?'), findsOneWidget);
    await tester.tap(find.text('Keep editing'));
    await h.settle(tester, 3);
    expect(find.text('Edit photo'), findsOneWidget);

    await tester.tap(find.byTooltip('Close editor'));
    await h.settle(tester, 3);
    await tester.tap(find.text('Discard'));
    await h.settle(tester, 3);
    expect(find.text('open'), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets('Save exports a NEW edited photo, keeps the original and returns with confirmation', (tester) async {
    final h = await Harness.create(tester, realProbe: true);
    final id = await seedPhoto(tester, h);
    await openEditor(tester, h, id);
    await tester.tap(find.text('Filters').last);
    await h.settle(tester, 3);
    await tester.tap(find.text('Mono'));
    await h.settle(tester, 3);

    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await h.pumpUntil(tester, () => find.textContaining('Saved as a new photo').evaluate().isNotEmpty);

    expect(find.textContaining('Saved as a new photo'), findsWidgets); // shown by both scaffolds during the route transition
    final rows = (await tester.runAsync(() => h.db.select(h.db.savedMediaTable).get()))!;
    expect(rows, hasLength(2));
    final edited = rows.firstWhere((r) => r.isEdited);
    expect(edited.mimeType, 'image/jpeg');
    expect((edited.width, edited.height), (120, 80));
    expect(File(edited.path).readAsBytesSync().sublist(0, 2), [0xFF, 0xD8]);
    expect(rows.firstWhere((r) => !r.isEdited).id, id);
    expect(find.text('open'), findsOneWidget); // editor closed
    await tester.pump(const Duration(seconds: 5));
    await h.dispose(tester);
  });

  testWidgets('crop 1:1 in the UI produces an exported file of exactly that geometry', (tester) async {
    final h = await Harness.create(tester, realProbe: true);
    final id = await seedPhoto(tester, h); // 120x80
    await openEditor(tester, h, id);
    await tester.tap(find.text('Crop').last);
    await h.settle(tester, 3);
    await tester.tap(find.text('1:1'));
    await h.settle(tester, 3);
    expect(canSave(tester), isTrue);

    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await h.pumpUntil(tester, () => find.textContaining('Saved as a new photo').evaluate().isNotEmpty);
    final rows = (await tester.runAsync(() => h.db.select(h.db.savedMediaTable).get()))!;
    final edited = rows.firstWhere((r) => r.isEdited);
    expect((edited.width, edited.height), (80, 80), reason: 'largest centred square of 120x80');
    await tester.pump(const Duration(seconds: 5));
    await h.dispose(tester);
  });

  testWidgets('a photo whose file vanished shows an error instead of an editor', (tester) async {
    final h = await Harness.create(tester);
    final id = await seedPhoto(tester, h);
    final row = (await tester.runAsync(() => h.db.findById(id)))!;
    File(row.path).deleteSync();
    await tester.pumpWidget(host(h, id));
    await h.settle(tester, 3);
    await tester.tap(find.text('open'));
    await h.pumpUntil(tester, () => find.text('This photo is no longer available.').evaluate().isNotEmpty);
    expect(find.text('This photo is no longer available.'), findsOneWidget);
    expect(find.byTooltip('Undo'), findsNothing);
    await h.dispose(tester);
  });
}
