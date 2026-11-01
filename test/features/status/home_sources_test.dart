import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wazapp/features/status/domain/status_models.dart';
import 'package:wazapp/features/status/presentation/home_screen.dart';
import 'package:wazapp/features/status/presentation/source_screen.dart';

import '../../support/fakes.dart';
import '../../support/harness.dart';

/// Scenarios A-D for which WhatsApp source cards Home shows, plus access/permission changes.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<Harness> pumpHome(WidgetTester tester, FakeStatusAccess access) async {
    tester.view.physicalSize = const Size(900, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final h = await Harness.create(tester, access: access);
    await tester.pumpWidget(h.wrapRouter([
      GoRoute(path: '/', builder: (_, _) => const HomeScreen()),
      GoRoute(path: '/source/:key', builder: (_, s) => SourceScreen(app: StatusApp.fromKey(s.pathParameters['key'])!)),
    ]));
    await h.settle(tester);
    return h;
  }

  FakeStatusAccess only(StatusApp app, {bool granted = true}) => FakeStatusAccess(
    installed: {StatusApp.whatsapp: app == StatusApp.whatsapp, StatusApp.business: app == StatusApp.business},
    access: {app: granted},
  );

  testWidgets('A: only WhatsApp installed -> exactly one card, no Business card or selector', (tester) async {
    final h = await pumpHome(tester, only(StatusApp.whatsapp));
    expect(find.bySemanticsLabel(RegExp('^WhatsApp,')), findsOneWidget);
    expect(find.textContaining('WhatsApp Business'), findsNothing);
    expect(find.byType(SegmentedButton<StatusApp>), findsNothing);
    await h.dispose(tester);
  });

  testWidgets('B: only WhatsApp Business installed -> exactly one Business card', (tester) async {
    final h = await pumpHome(tester, only(StatusApp.business));
    expect(find.bySemanticsLabel(RegExp('^WhatsApp Business,')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('^WhatsApp,')), findsNothing);
    await h.dispose(tester);
  });

  testWidgets('C: both installed -> two separate cards with their own counts', (tester) async {
    final access = FakeStatusAccess(
      installed: {StatusApp.whatsapp: true, StatusApp.business: true},
      access: {StatusApp.whatsapp: true, StatusApp.business: true},
    );
    final h = await Harness.create(tester, access: access);
    tester.view.physicalSize = const Size(900, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    access.addStatus(h.sourceDir, 'wa.jpg');
    access.addStatus(h.sourceDir, 'b1.jpg', app: StatusApp.business);
    access.addStatus(h.sourceDir, 'b2.jpg', app: StatusApp.business);
    await tester.pumpWidget(h.wrapRouter([GoRoute(path: '/', builder: (_, _) => const HomeScreen())]));
    await h.settle(tester);
    expect(find.bySemanticsLabel(RegExp(r'^WhatsApp, 1 status available')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(r'^WhatsApp Business, 2 statuses available')), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets('D: neither installed -> no source cards, a clear explanation, other features reachable', (tester) async {
    final h = await pumpHome(tester, FakeStatusAccess(installed: {StatusApp.whatsapp: false, StatusApp.business: false}));
    expect(find.text('No WhatsApp app found'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('^WhatsApp(, | Business,)')), findsNothing);
    expect(find.text('Make a status'), findsOneWidget);
    expect(find.text('Import from device'), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets('installed is not the same as accessible: the card asks for access and a tap opens the picker',
      (tester) async {
    final access = only(StatusApp.business, granted: false);
    final h = await pumpHome(tester, access);
    expect(find.text('Not set up'), findsOneWidget);
    expect(find.text('Allow access'), findsOneWidget);
    expect(access.requestCount, 0); // detection alone never opens a picker
    await tester.tap(find.text('Allow access'));
    await h.settle(tester);
    expect(access.requestCount, 1);
    expect(find.text('Connected'), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets('revoked access is shown as lost, and recovers after choosing the folder again', (tester) async {
    final access = only(StatusApp.whatsapp, granted: false)..folderStates[StatusApp.whatsapp] = StatusFolderState.revoked;
    final h = await pumpHome(tester, access);
    expect(find.text('Access lost'), findsOneWidget);
    expect(find.text('Choose folder again'), findsOneWidget);
    access.folderStates.clear();
    await tester.tap(find.text('Choose folder again'));
    await h.settle(tester);
    expect(find.text('Connected'), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets('pull-to-refresh / Check again re-detects an app installed meanwhile', (tester) async {
    final access = FakeStatusAccess(installed: {StatusApp.whatsapp: false, StatusApp.business: false});
    final h = await pumpHome(tester, access);
    expect(find.text('No WhatsApp app found'), findsOneWidget);
    access.installed[StatusApp.business] = true;
    access.access[StatusApp.business] = true;
    await tester.tap(find.text('Check again').last);
    await h.settle(tester);
    expect(find.text('No WhatsApp app found'), findsNothing);
    expect(find.bySemanticsLabel(RegExp('^WhatsApp Business,')), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets('returning to the app (resume) re-detects installs and access', (tester) async {
    final access = only(StatusApp.whatsapp);
    final h = await pumpHome(tester, access);
    expect(find.text('Connected'), findsOneWidget);
    access.access[StatusApp.whatsapp] = false; // revoked while in the background
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await h.settle(tester);
    expect(find.text('Connected'), findsNothing);
    expect(find.text('Allow access'), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets('unsupported platform (iOS): import only, never a status feed', (tester) async {
    final h = await pumpHome(tester, FakeStatusAccess(supported: false));
    expect(find.text('Import from Photos'), findsOneWidget);
    expect(find.textContaining('cannot look inside WhatsApp'), findsOneWidget);
    expect(find.text('Allow access'), findsNothing);
    await h.dispose(tester);
  });
}
