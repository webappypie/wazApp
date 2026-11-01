import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wazapp/features/permissions/data/permission_gateway.dart';
import 'package:wazapp/features/permissions/domain/access_models.dart';
import 'package:wazapp/features/permissions/presentation/permission_setup_screen.dart';
import 'package:wazapp/features/status/domain/status_models.dart';
import 'package:wazapp/features/private_folder/data/device_auth_service.dart';

import '../../support/fakes.dart';
import '../../support/harness.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<Harness> pumpSetup(
    WidgetTester tester, {
    FakeStatusAccess? access,
    FakeAuth? auth,
    void Function(Harness)? before,
  }) async {
    // Tall surface so every card is built (ListView builds lazily).
    tester.view.physicalSize = const Size(900, 3600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final h = await Harness.create(tester, access: access, auth: auth, onboarded: false);
    before?.call(h);
    await tester.pumpWidget(h.wrapRouter([
      GoRoute(path: '/', builder: (_, _) => const Scaffold(body: Text('HOME'))),
      GoRoute(path: '/setup', builder: (_, _) => const PermissionSetupScreen()),
    ], initial: '/setup'));
    await h.settle(tester);
    return h;
  }

  testWidgets('shows both WhatsApp apps separately with their real states and requests nothing by itself',
      (tester) async {
    final access = FakeStatusAccess(
      installed: {StatusApp.whatsapp: true, StatusApp.business: true},
      access: {StatusApp.whatsapp: true, StatusApp.business: false},
    );
    final h = await pumpSetup(tester, access: access);

    expect(find.text('WhatsApp'), findsOneWidget);
    expect(find.text('WhatsApp Business'), findsOneWidget);
    // WhatsApp granted, Business not set up: one grant never implies the other.
    expect(find.text('Allowed'), findsOneWidget);
    expect(find.text('Not set up'), findsOneWidget);
    expect(find.text('Choose folder'), findsOneWidget);
    // No prompt and no folder picker was opened just by showing the screen.
    expect(h.gateway.requestCount, 0);
    expect(access.requestCount, 0);
    await h.dispose(tester);
  });

  testWidgets('a source that is not installed is shown as such and offers no fake action', (tester) async {
    final access = FakeStatusAccess(
      installed: {StatusApp.whatsapp: false, StatusApp.business: true},
      access: {StatusApp.business: true},
    );
    final h = await pumpSetup(tester, access: access);
    expect(find.text('Not installed'), findsOneWidget);
    expect(find.text('Allowed'), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets('choosing a folder connects only that app and reports a wrong folder honestly', (tester) async {
    final access = FakeStatusAccess(
      installed: {StatusApp.whatsapp: true, StatusApp.business: true},
      access: {StatusApp.whatsapp: false, StatusApp.business: false},
    );
    final h = await pumpSetup(tester, access: access);

    access.nextRequestResult = AccessRequestResult.wrongFolder;
    await tester.tap(find.text('Choose folder').first);
    await h.settle(tester);
    expect(find.textContaining('does not contain WhatsApp statuses'), findsOneWidget);
    expect(access.access[StatusApp.whatsapp], isFalse);

    access.nextRequestResult = AccessRequestResult.granted;
    await tester.pump(const Duration(seconds: 5));
    await tester.tap(find.text('Choose folder').first);
    await h.settle(tester);
    expect(access.access[StatusApp.whatsapp], isTrue);
    expect(access.access[StatusApp.business], isFalse);
    expect(find.text('Allowed'), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets('a revoked folder grant is reported as lost, not as granted', (tester) async {
    final access = FakeStatusAccess(
      installed: {StatusApp.whatsapp: true, StatusApp.business: false},
      access: {StatusApp.whatsapp: false},
    )..folderStates[StatusApp.whatsapp] = StatusFolderState.revoked;
    final h = await pumpSetup(tester, access: access);
    expect(find.text('Access lost'), findsOneWidget);
    expect(find.text('Choose folder again'), findsOneWidget);
    expect(find.text('Allowed'), findsNothing);
    await h.dispose(tester);
  });

  testWidgets('notifications: allow, deny, retry once more, then only system settings', (tester) async {
    final h = await pumpSetup(tester, before: (h) => h.gateway.promptResult = AccessStatus.denied);

    expect(find.text('Allow'), findsOneWidget);
    await tester.tap(find.text('Allow'));
    await h.settle(tester);
    expect(h.gateway.requestCount, 1);
    expect(find.text('Denied'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);

    // The OS has now blocked further prompts: the button must open settings, not prompt again.
    h.gateway.notifications = AccessStatus.permanentlyDenied;
    await tester.pump(const Duration(seconds: 5));
    await tester.tap(find.byTooltip('Check again'));
    await h.settle(tester);
    expect(find.text('Blocked'), findsOneWidget);
    await tester.tap(find.text('Open settings'));
    await h.settle(tester);
    expect(h.gateway.requestCount, 1);
    expect(h.gateway.openedSettings, [SettingsPage.notifications]);
    await h.dispose(tester);
  });

  testWidgets('notifications granted in system settings show as allowed after a re-check', (tester) async {
    final h = await pumpSetup(tester, before: (h) => h.gateway.notifications = AccessStatus.permanentlyDenied);
    expect(find.text('Blocked'), findsOneWidget);
    h.gateway.notifications = AccessStatus.granted;
    await tester.tap(find.byTooltip('Check again'));
    await h.settle(tester);
    expect(find.text('Blocked'), findsNothing);
    // WhatsApp (default fake: connected) and Notifications.
    expect(find.text('Allowed'), findsNWidgets(2));
    await h.dispose(tester);
  });

  testWidgets('locker: no screen lock -> guided to system settings; with one -> turns on after authentication',
      (tester) async {
    final auth = FakeAuth(availabilityValue: AuthAvailability.notEnrolled);
    final h = await pumpSetup(tester, auth: auth);
    expect(find.text('Needs screen lock'), findsOneWidget);
    await tester.ensureVisible(find.text('Open security settings'));
    await tester.tap(find.text('Open security settings'));
    await h.settle(tester);
    expect(h.gateway.openedSettings, [SettingsPage.security]);

    auth.availabilityValue = AuthAvailability.available;
    await tester.tap(find.byTooltip('Check again'));
    await h.settle(tester);
    expect(find.text('Off'), findsOneWidget);
    await tester.ensureVisible(find.text('Turn on'));
    await tester.tap(find.text('Turn on'));
    await h.settle(tester);
    expect(auth.prompts, hasLength(1));
    expect(find.text('On'), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets('photos & files honestly need no permission', (tester) async {
    final h = await pumpSetup(tester);
    await tester.scrollUntilVisible(find.text('No permission needed'), 200,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('No permission needed'), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets('Continue and Skip both finish setup and open Home', (tester) async {
    final h = await pumpSetup(tester);
    expect(h.onboarding.completed, isFalse);
    await tester.tap(find.text('Skip for now'));
    await h.settle(tester);
    expect(h.onboarding.completed, isTrue);
    expect(find.text('HOME'), findsOneWidget);
    await h.dispose(tester);

    final h2 = await pumpSetup(tester);
    await tester.tap(find.text('Continue'));
    await h2.settle(tester);
    expect(h2.onboarding.completed, isTrue);
    expect(find.text('HOME'), findsOneWidget);
    await h2.dispose(tester);
  });
}
