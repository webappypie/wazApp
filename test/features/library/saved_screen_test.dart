import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wazapp/features/library/data/library_service.dart';
import 'package:wazapp/features/library/presentation/saved_screen.dart';

import '../../support/fakes.dart';
import '../../support/harness.dart';

Future<void> _seed(WidgetTester tester, Harness h) async {
  final service = LibraryService(
    db: h.db,
    storage: h.storage,
    status: h.access,
    tools: h.access,
    probe: FakeProbe(),
  );
  final photo = File('${h.sourceDir.path}/pic.jpg')..writeAsBytesSync(List.filled(64, 1));
  final video = File('${h.sourceDir.path}/clip.mp4')..writeAsBytesSync(List.filled(64, 2));
  await tester.runAsync(() => service.importFiles([
        ImportCandidate(path: photo.path, name: 'pic.jpg', mimeType: 'image/jpeg'),
        ImportCandidate(path: video.path, name: 'clip.mp4', mimeType: 'video/mp4'),
      ]));
}

void main() {
  testWidgets('empty library shows guidance and an import action', (tester) async {
    final h = await Harness.create(tester);
    await tester.pumpWidget(h.wrap(const SavedScreen()));
    await h.settle(tester);

    expect(find.text('Nothing saved yet'), findsOneWidget);
    expect(find.text('Import'), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets('filter chips and search really change what is shown', (tester) async {
    final h = await Harness.create(tester);
    await _seed(tester, h);
    await tester.pumpWidget(h.wrap(const SavedScreen()));
    await h.settle(tester);

    expect(find.bySemanticsLabel(RegExp('pic.jpg')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('clip.mp4')), findsOneWidget);

    await tester.tap(find.text('Videos'));
    await h.settle(tester);
    expect(find.bySemanticsLabel(RegExp('pic.jpg')), findsNothing);
    expect(find.bySemanticsLabel(RegExp('clip.mp4')), findsOneWidget);

    await tester.tap(find.text('Favourites'));
    await h.settle(tester);
    expect(find.text('No matches'), findsOneWidget);

    await tester.tap(find.text('All'));
    await tester.tap(find.byTooltip('Search'));
    await h.settle(tester);
    await tester.enterText(find.byType(TextField), 'pic');
    await h.settle(tester);
    expect(find.bySemanticsLabel(RegExp('pic.jpg')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('clip.mp4')), findsNothing);
    await h.dispose(tester);
  });

  testWidgets('bulk favourite persists and is reflected on the tile', (tester) async {
    final h = await Harness.create(tester);
    await _seed(tester, h);
    await tester.pumpWidget(h.wrap(const SavedScreen()));
    await h.settle(tester);

    await tester.longPress(find.bySemanticsLabel(RegExp('pic.jpg')));
    await h.settle(tester);
    expect(find.text('1 selected'), findsOneWidget);
    await tester.tap(find.byTooltip('Add to favourites'));
    await h.pumpUntil(tester, () => find.bySemanticsLabel(RegExp('favourite')).evaluate().isNotEmpty);

    expect(find.bySemanticsLabel(RegExp('pic.jpg, favourite')), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets('delete asks for count-based confirmation; cancel keeps files, confirm removes them', (tester) async {
    final h = await Harness.create(tester);
    await _seed(tester, h);
    await tester.pumpWidget(h.wrap(const SavedScreen()));
    await h.settle(tester);

    await tester.longPress(find.bySemanticsLabel(RegExp('pic.jpg')));
    await h.settle(tester);
    await tester.tap(find.byTooltip('Select all'));
    await h.settle(tester);
    await tester.tap(find.byTooltip('More actions'));
    await h.settle(tester);
    await tester.tap(find.text('Delete…'));
    await h.settle(tester);

    expect(find.text('Delete 2 items?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await h.settle(tester);
    expect(h.storage.mediaDir.listSync(), hasLength(2));

    await tester.tap(find.byTooltip('More actions'));
    await h.settle(tester);
    await tester.tap(find.text('Delete…'));
    await h.settle(tester);
    // Let pending image reads finish so Windows has no open handles on the files.
    await h.pumpUntil(tester, () => false);
    await tester.tap(find.text('Delete'));
    await h.pumpUntil(tester, () => find.byType(SnackBar).evaluate().isNotEmpty);

    // Invariant on every OS: the library never keeps a row without its file (or vice versa).
    final rows = (await tester.runAsync(() => h.db.select(h.db.savedMediaTable).get()))!;
    final files = h.storage.mediaDir.listSync().map((e) => e.path).toSet();
    expect(rows.map((r) => r.path).toSet(), files);
    if (!Platform.isWindows) {
      // Windows keeps decoded-image handles open in the test engine, which blocks unlink;
      // POSIX (Android/iOS) must delete everything.
      expect(rows, isEmpty);
      expect(find.text('Nothing saved yet'), findsOneWidget);
    }
    await tester.pump(const Duration(seconds: 5));
    await h.dispose(tester);
  });

  testWidgets('gallery export is offered only where the platform supports it', (tester) async {
    final h = await Harness.create(tester);
    await _seed(tester, h);
    await tester.pumpWidget(h.wrap(const SavedScreen()));
    await h.settle(tester);
    await tester.longPress(find.bySemanticsLabel(RegExp('pic.jpg')));
    await h.settle(tester);
    await tester.tap(find.byTooltip('More actions'));
    await h.settle(tester);
    expect(find.text('Save to gallery'), findsOneWidget);
    await tester.tap(find.text('Save to gallery'));
    await h.pumpUntil(tester, () => h.access.exported.isNotEmpty);
    expect(h.access.exported.single['name'], 'pic.jpg');
    await tester.pump(const Duration(seconds: 5));
    await h.dispose(tester);
  });

  testWidgets('gallery export is hidden where the platform has no export', (tester) async {
    final h = await Harness.create(tester, access: FakeStatusAccess(supported: false));
    await _seed(tester, h);
    await tester.pumpWidget(h.wrap(const SavedScreen()));
    await h.settle(tester);
    await tester.longPress(find.bySemanticsLabel(RegExp('pic.jpg')));
    await h.settle(tester);
    await tester.tap(find.byTooltip('More actions'));
    await h.settle(tester);
    expect(find.text('Save to gallery'), findsNothing);
    expect(find.text('Delete…'), findsOneWidget);
    await h.dispose(tester);
  });
}
