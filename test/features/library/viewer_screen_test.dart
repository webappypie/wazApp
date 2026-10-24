import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wazapp/features/library/data/library_service.dart';
import 'package:wazapp/features/library/presentation/saved_screen.dart';
import 'package:wazapp/features/library/presentation/viewer_screen.dart';

import '../../support/fakes.dart';
import '../../support/harness.dart';

Future<List<String>> _seed(WidgetTester tester, Harness h) async {
  final service = LibraryService(
    db: h.db,
    storage: h.storage,
    status: h.access,
    tools: h.access,
    probe: FakeProbe(),
  );
  final a = File('${h.sourceDir.path}/a.jpg')..writeAsBytesSync(List.filled(2048, 1));
  final b = File('${h.sourceDir.path}/b.jpg')..writeAsBytesSync(List.filled(64, 2));
  final r = await tester.runAsync(() => service.importFiles([
        ImportCandidate(path: a.path, name: 'a.jpg', mimeType: 'image/jpeg'),
        ImportCandidate(path: b.path, name: 'b.jpg', mimeType: 'image/jpeg'),
      ]));
  return r!.imported.map((m) => m.id).toList();
}

void main() {
  testWidgets('viewer shows position, toggles favourite persistently and lists real details', (tester) async {
    final h = await Harness.create(tester);
    final ids = await _seed(tester, h);
    await tester.pumpWidget(h.wrap(ViewerScreen(args: ViewerArgs(ids: ids, index: 0))));
    await h.settle(tester);

    expect(find.text('1 / 2'), findsOneWidget);
    // Video-only controls must not appear for photos.
    expect(find.byTooltip('Play'), findsNothing);

    await tester.tap(find.byTooltip('Add to favourites'));
    await h.pumpUntil(tester, () => find.byTooltip('Remove from favourites').evaluate().isNotEmpty);
    expect(find.byTooltip('Remove from favourites'), findsOneWidget);
    final row = await tester.runAsync(() => h.db.findById(ids[0]));
    expect(row!.isFavourite, isTrue);

    await tester.tap(find.byTooltip('More actions'));
    await h.settle(tester);
    await tester.tap(find.text('Details'));
    await h.settle(tester);
    expect(find.text('Photo'), findsOneWidget);
    expect(find.text('2.0 KB'), findsOneWidget);
    expect(find.text('100 × 100'), findsOneWidget);
    expect(find.text('Imported'), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets('a missing file shows a recoverable error and can be removed from the library', (tester) async {
    final h = await Harness.create(tester);
    final ids = await _seed(tester, h);
    final row = (await tester.runAsync(() => h.db.findById(ids[0])))!;
    File(row.path).deleteSync();
    await tester.pumpWidget(h.wrap(ViewerScreen(args: ViewerArgs(ids: ids, index: 0))));
    await h.settle(tester);
    await h.pumpUntil(tester, () => find.text('This file is missing or damaged.').evaluate().isNotEmpty);

    expect(find.text('This file is missing or damaged.'), findsOneWidget);
    await tester.tap(find.text('Remove from library'));
    await h.pumpUntil(tester, () => find.text('1 / 1').evaluate().isNotEmpty);
    expect(find.text('1 / 1'), findsOneWidget);
    expect(await tester.runAsync(() => h.db.findById(ids[0])), isNull);
    await h.dispose(tester);
  });

  testWidgets('an item that no longer exists yields a clear empty message', (tester) async {
    final h = await Harness.create(tester);
    await tester.pumpWidget(h.wrap(const ViewerScreen(args: ViewerArgs(ids: ['gone'], index: 0))));
    await h.settle(tester);
    expect(find.text('This item is no longer in your library.'), findsOneWidget);
    await h.dispose(tester);
  });
}
