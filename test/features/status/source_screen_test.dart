import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wazapp/core/error/app_error.dart';
import 'package:wazapp/features/library/domain/library_models.dart';
import 'package:wazapp/features/status/domain/status_models.dart';
import 'package:wazapp/features/status/presentation/source_screen.dart';

import '../../support/fakes.dart';
import '../../support/harness.dart';

void main() {
  Future<Harness> pump(WidgetTester tester, FakeStatusAccess access, {StatusApp app = StatusApp.whatsapp}) async {
    tester.view.physicalSize = const Size(900, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final h = await Harness.create(tester, access: access);
    return h;
  }

  Future<void> show(WidgetTester tester, Harness h, {StatusApp app = StatusApp.whatsapp}) async {
    await tester.pumpWidget(h.wrap(SourceScreen(app: app)));
    await h.settle(tester);
  }

  testWidgets('statuses are grouped by day (not by contact) with Today / Yesterday headings', (tester) async {
    final access = FakeStatusAccess();
    final h = await pump(tester, access);
    final now = DateTime.now();
    access.addStatus(h.sourceDir, 'a.jpg', modified: now);
    access.addStatus(h.sourceDir, 'b.jpg', modified: now.subtract(const Duration(days: 1)));
    await show(tester, h);
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Yesterday'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('image status')), findsNWidgets(2));
    await h.dispose(tester);
  });

  testWidgets('filter chips show real counts and change the grid', (tester) async {
    final access = FakeStatusAccess();
    final h = await pump(tester, access);
    access.addStatus(h.sourceDir, 'a.jpg');
    access.addStatus(h.sourceDir, 'b.jpg');
    access.addStatus(h.sourceDir, 'v.mp4', kind: MediaKind.video);
    await show(tester, h);
    expect(find.text('All · 3'), findsOneWidget);
    expect(find.text('Photos · 2'), findsOneWidget);
    expect(find.text('Videos · 1'), findsOneWidget);
    await tester.tap(find.text('Videos · 1'));
    await h.settle(tester);
    expect(find.bySemanticsLabel(RegExp('video status')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('image status')), findsNothing);
    await h.dispose(tester);
  });

  testWidgets('empty folder: honest empty state plus the small "Missing a status?" help with Check again',
      (tester) async {
    final access = FakeStatusAccess();
    final h = await pump(tester, access);
    await show(tester, h);
    expect(find.text('No statuses available yet'), findsOneWidget);
    expect(find.text('Missing a status?'), findsOneWidget);
    // Collapsed by default: small and unobtrusive.
    expect(find.textContaining('may appear here only after'), findsNothing);
    await tester.tap(find.text('Missing a status?'));
    await h.settle(tester);
    expect(find.textContaining('may appear here only after'), findsOneWidget);
    expect(find.textContaining('not guaranteed'), findsOneWidget);

    access.addStatus(h.sourceDir, 'late.jpg'); // WhatsApp downloaded it meanwhile
    await tester.tap(find.text('Check again').last);
    await h.settle(tester);
    expect(find.bySemanticsLabel(RegExp('image status')), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets('"Open WhatsApp" only launches the app, and is named after the right source', (tester) async {
    final access = FakeStatusAccess(
      installed: {StatusApp.whatsapp: true, StatusApp.business: true},
      access: {StatusApp.whatsapp: true, StatusApp.business: true},
    );
    final h = await pump(tester, access);
    await show(tester, h, app: StatusApp.business);
    await tester.tap(find.text('Missing a status?'));
    await h.settle(tester);
    await tester.tap(find.text('Open WhatsApp Business'));
    await h.settle(tester);
    expect(access.openedApps, [StatusApp.business]);
    await h.dispose(tester);
  });

  testWidgets('access problem is explained separately from not-yet-downloaded statuses', (tester) async {
    final access = FakeStatusAccess(access: {StatusApp.whatsapp: false})
      ..folderStates[StatusApp.whatsapp] = StatusFolderState.revoked;
    final h = await pump(tester, access);
    await show(tester, h);
    expect(find.text('Access lost'), findsOneWidget);
    expect(find.textContaining('permission to read'), findsOneWidget);
    expect(find.text('Missing a status?'), findsNothing);
    await h.dispose(tester);
  });

  testWidgets('a source that is no longer installed says so instead of showing stale statuses', (tester) async {
    final access = FakeStatusAccess(installed: {StatusApp.whatsapp: false, StatusApp.business: false});
    final h = await pump(tester, access);
    await show(tester, h);
    expect(find.text('WhatsApp is not installed'), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets('the two sources never mix their lists', (tester) async {
    final access = FakeStatusAccess(
      installed: {StatusApp.whatsapp: true, StatusApp.business: true},
      access: {StatusApp.whatsapp: true, StatusApp.business: true},
    );
    final h = await pump(tester, access);
    access.addStatus(h.sourceDir, 'wa.jpg');
    access.addStatus(h.sourceDir, 'b1.jpg', app: StatusApp.business);
    access.addStatus(h.sourceDir, 'b2.jpg', app: StatusApp.business);
    await show(tester, h, app: StatusApp.business);
    expect(find.bySemanticsLabel(RegExp('image status')), findsNWidgets(2));
    await h.dispose(tester);
  });

  testWidgets('listing error shows the message and a working retry', (tester) async {
    final access = FakeStatusAccess()..listFailure = MediaFailure.sourceUnavailable;
    final h = await pump(tester, access);
    access.addStatus(h.sourceDir, 'one.jpg');
    await show(tester, h);
    expect(find.text('The status folder cannot be read.'), findsOneWidget);
    access.listFailure = null;
    await tester.tap(find.text('Retry'));
    await h.settle(tester);
    expect(find.bySemanticsLabel(RegExp('image status')), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets('saving a status writes it to the library and marks it saved', (tester) async {
    final access = FakeStatusAccess();
    final h = await pump(tester, access);
    access.addStatus(h.sourceDir, 'one.jpg');
    await show(tester, h);
    await tester.tap(find.byTooltip('Save'));
    await h.pumpUntil(tester, () => find.textContaining('Saved 1').evaluate().isNotEmpty);
    final rows = await tester.runAsync(() => h.db.select(h.db.savedMediaTable).get());
    expect(rows, hasLength(1));
    expect(rows!.single.sourceType, 'status');
    expect(find.byTooltip('Save'), findsNothing);
    await tester.pump(const Duration(seconds: 5));
    await h.dispose(tester);
  });

  testWidgets('saving re-checks access first: a revoked grant stops the save with an explanation', (tester) async {
    final access = FakeStatusAccess();
    final h = await pump(tester, access);
    access.addStatus(h.sourceDir, 'one.jpg');
    await show(tester, h);
    access.folderStates[StatusApp.whatsapp] = StatusFolderState.revoked; // revoked after the list was shown
    await tester.tap(find.byTooltip('Save'));
    await h.settle(tester);
    expect(find.textContaining('Access to WhatsApp statuses was lost'), findsOneWidget);
    final rows = await tester.runAsync(() => h.db.select(h.db.savedMediaTable).get());
    expect(rows, isEmpty);
    await tester.pump(const Duration(seconds: 5));
    await h.dispose(tester);
  });

  testWidgets('long-press multi-select then Save stores all selected', (tester) async {
    final access = FakeStatusAccess();
    final h = await pump(tester, access);
    access.addStatus(h.sourceDir, 'a.jpg', modified: DateTime.now());
    access.addStatus(h.sourceDir, 'b.jpg', modified: DateTime.now());
    await show(tester, h);
    await tester.longPress(find.bySemanticsLabel(RegExp('image status')).first);
    await tester.pump();
    expect(find.text('1 selected'), findsOneWidget);
    await tester.tap(find.byTooltip('Select all'));
    await tester.pump();
    expect(find.text('2 selected'), findsOneWidget);
    await tester.tap(find.byTooltip('Save selected'));
    await h.pumpUntil(tester, () => find.textContaining('Saved 2').evaluate().isNotEmpty);
    final rows = await tester.runAsync(() => h.db.select(h.db.savedMediaTable).get());
    expect(rows, hasLength(2));
    await tester.pump(const Duration(seconds: 5));
    await h.dispose(tester);
  });

  testWidgets('a failed item is reported with a retry dialog and nothing is stored for it', (tester) async {
    final access = FakeStatusAccess();
    final h = await pump(tester, access);
    final bad = access.addStatus(h.sourceDir, 'bad.jpg');
    access.copyFailures[bad.uri] = MediaFailure.lowStorage;
    await show(tester, h);
    await tester.tap(find.byTooltip('Save'));
    await h.pumpUntil(tester, () => find.text('Some items could not be saved').evaluate().isNotEmpty);
    expect(find.text('Retry'), findsOneWidget);
    final rows = await tester.runAsync(() => h.db.select(h.db.savedMediaTable).get());
    expect(rows, isEmpty);
    await tester.tap(find.text('Close'));
    await tester.pump(const Duration(seconds: 5));
    await h.dispose(tester);
  });
}
