import 'package:flutter_test/flutter_test.dart';
import 'package:wazapp/core/error/app_error.dart';
import 'package:wazapp/features/status/domain/status_models.dart';
import 'package:wazapp/features/status/presentation/home_screen.dart';

import '../../support/fakes.dart';
import '../../support/harness.dart';

void main() {
  testWidgets('unsupported platform (iOS): offers import and never shows a status feed', (tester) async {
    final h = await Harness.create(tester, access: FakeStatusAccess(supported: false));
    await tester.pumpWidget(h.wrap(const HomeScreen()));
    await h.settle(tester);

    expect(find.text('Import from Photos'), findsOneWidget);
    expect(find.text('Import from Files'), findsOneWidget);
    expect(find.textContaining('cannot look inside WhatsApp'), findsOneWidget);
    expect(find.text('Choose status folder'), findsNothing);
    await h.dispose(tester);
  });

  testWidgets('Android without WhatsApp installed explains and offers import', (tester) async {
    final h = await Harness.create(tester, 
      access: FakeStatusAccess(installed: {StatusApp.whatsapp: false, StatusApp.business: false}),
    );
    await tester.pumpWidget(h.wrap(const HomeScreen()));
    await h.settle(tester);

    expect(find.text('WhatsApp not found'), findsOneWidget);
    expect(find.text('Import from device'), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets('no folder grant yet: shows setup steps; choosing a folder loads the grid', (tester) async {
    final access = FakeStatusAccess(access: {StatusApp.whatsapp: false, StatusApp.business: false});
    final h = await Harness.create(tester, access: access);
    access.addStatus(h.sourceDir, 'one.jpg');
    await tester.pumpWidget(h.wrap(const HomeScreen()));
    await h.settle(tester);

    expect(find.text('Allow access to WhatsApp statuses'), findsOneWidget);
    await tester.tap(find.text('Choose status folder'));
    await h.settle(tester);

    expect(access.requestCount, 1);
    expect(find.text('Allow access to WhatsApp statuses'), findsNothing);
    expect(find.bySemanticsLabel(RegExp('image status')), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets('wrong folder keeps the setup screen and explains', (tester) async {
    final access = FakeStatusAccess(access: {StatusApp.whatsapp: false, StatusApp.business: false})
      ..nextRequestResult = AccessRequestResult.wrongFolder;
    final h = await Harness.create(tester, access: access);
    await tester.pumpWidget(h.wrap(const HomeScreen()));
    await h.settle(tester);

    await tester.tap(find.text('Choose status folder'));
    await h.settle(tester);

    expect(find.textContaining('does not contain WhatsApp statuses'), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets('empty status folder shows an honest empty state', (tester) async {
    final h = await Harness.create(tester);
    await tester.pumpWidget(h.wrap(const HomeScreen()));
    await h.settle(tester);

    expect(find.text('No statuses found'), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets('listing error shows the message and a working retry, not a fake grid', (tester) async {
    final access = FakeStatusAccess()..listFailure = MediaFailure.sourceUnavailable;
    final h = await Harness.create(tester, access: access);
    access.addStatus(h.sourceDir, 'one.jpg');
    await tester.pumpWidget(h.wrap(const HomeScreen()));
    await h.settle(tester);

    expect(find.text('The status folder cannot be read.'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('image status')), findsNothing);

    access.listFailure = null;
    await tester.tap(find.text('Retry'));
    await h.settle(tester);
    expect(find.bySemanticsLabel(RegExp('image status')), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets('saving a status from the grid writes it to the library and marks it saved', (tester) async {
    final access = FakeStatusAccess();
    final h = await Harness.create(tester, access: access);
    access.addStatus(h.sourceDir, 'one.jpg');
    await tester.pumpWidget(h.wrap(const HomeScreen()));
    await h.settle(tester);

    await tester.tap(find.byTooltip('Save'));
    // Real file copy + drift insert need real async time.
    await h.pumpUntil(tester, () => find.textContaining('Saved 1').evaluate().isNotEmpty);

    final rows = await tester.runAsync(() => h.db.select(h.db.savedMediaTable).get());
    expect(rows, hasLength(1));
    expect(rows!.single.sourceType, 'status');
    expect(find.textContaining('Saved 1'), findsOneWidget);
    expect(find.text('Saved'), findsOneWidget); // marker on tile
    expect(find.byTooltip('Save'), findsNothing);
    await tester.pump(const Duration(seconds: 5)); // let the snackbar finish
    await h.dispose(tester);
  });

  testWidgets('long-press multi-select then Save stores all selected', (tester) async {
    final access = FakeStatusAccess();
    final h = await Harness.create(tester, access: access);
    access.addStatus(h.sourceDir, 'a.jpg', modified: DateTime(2026, 10, 24, 10));
    access.addStatus(h.sourceDir, 'b.jpg', modified: DateTime(2026, 10, 24, 11));
    await tester.pumpWidget(h.wrap(const HomeScreen()));
    await h.settle(tester);

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

  testWidgets('failed item is reported with a retry dialog and nothing is stored for it', (tester) async {
    final access = FakeStatusAccess();
    final h = await Harness.create(tester, access: access);
    final bad = access.addStatus(h.sourceDir, 'bad.jpg');
    access.copyFailures[bad.uri] = MediaFailure.lowStorage;
    await tester.pumpWidget(h.wrap(const HomeScreen()));
    await h.settle(tester);

    await tester.tap(find.byTooltip('Save'));
    await h.pumpUntil(tester, () => find.text('Some items could not be saved').evaluate().isNotEmpty);

    expect(find.text('Some items could not be saved'), findsOneWidget);
    expect(find.textContaining('Not enough free storage'), findsNothing); // fake message differs
    expect(find.text('Retry'), findsOneWidget);
    final rows = await tester.runAsync(() => h.db.select(h.db.savedMediaTable).get());
    expect(rows, isEmpty);
    await tester.tap(find.text('Close'));
    await tester.pump(const Duration(seconds: 5));
    await h.dispose(tester);
  });

  testWidgets('both apps installed: switcher separates WhatsApp and Business lists', (tester) async {
    final access = FakeStatusAccess(
      installed: {StatusApp.whatsapp: true, StatusApp.business: true},
      access: {StatusApp.whatsapp: true, StatusApp.business: true},
    );
    final h = await Harness.create(tester, access: access);
    access.addStatus(h.sourceDir, 'wa.jpg');
    access.addStatus(h.sourceDir, 'biz1.jpg', app: StatusApp.business);
    access.addStatus(h.sourceDir, 'biz2.jpg', app: StatusApp.business);
    await tester.pumpWidget(h.wrap(const HomeScreen()));
    await h.settle(tester);

    expect(find.bySemanticsLabel(RegExp('image status')), findsNWidgets(1));
    await tester.tap(find.text('WhatsApp Business'));
    await h.settle(tester);
    expect(find.bySemanticsLabel(RegExp('image status')), findsNWidgets(2));
    await h.dispose(tester);
  });
}
