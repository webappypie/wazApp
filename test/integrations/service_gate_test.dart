import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:wazapp/app.dart';
import 'package:wazapp/core/design/tokens.dart';
import 'package:wazapp/integrations/wapcentral/presentation/service_gate.dart';

import '../support/harness.dart';

Widget gateApp(Harness h, ValueNotifier<int> taps) => ProviderScope(
      retry: (_, _) => null,
      overrides: h.overrides,
      child: MaterialApp(
        theme: AppTheme.light(),
        builder: (context, child) => ServiceGate(child: child!),
        home: Scaffold(
          body: Center(
            child: FilledButton(onPressed: () => taps.value++, child: const Text('app button')),
          ),
        ),
      ),
    );

Future<void> resume(WidgetTester tester, Harness h) async {
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  await h.settle(tester, 4);
}

void main() {
  testWidgets('cold start: the app is usable at once; the notice appears only when WAPCentral says disabled', (tester) async {
    final answer = Completer<http.Response>();
    final service = ScriptedService()..responder = () => answer.future;
    final h = await Harness.create(tester, service: service);
    final taps = ValueNotifier(0);
    await tester.pumpWidget(gateApp(h, taps));
    await h.settle(tester, 3);

    expect(service.requests, 1, reason: 'asked once at start');
    expect(find.text('app button'), findsOneWidget);
    await tester.tap(find.text('app button'));
    expect(taps.value, 1, reason: 'a slow server never blocks local features');
    expect(find.text('Service Notice'), findsNothing);

    answer.complete(http.Response(
      '{"success":true,"data":{"enabled":false,"title":"Maintenance","message":"Back soon.","buttonText":"Learn More","destinationUrl":"https://webappypie.com"}}',
      200,
    ));
    await h.settle(tester, 4);
    expect(find.text('Maintenance'), findsOneWidget);
    expect(find.text('Back soon.'), findsOneWidget);
    expect(find.text('Learn More'), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets('enabled service never shows a notice', (tester) async {
    final service = ScriptedService();
    final h = await Harness.create(tester, service: service);
    await tester.pumpWidget(gateApp(h, ValueNotifier(0)));
    await h.settle(tester, 4);
    expect(find.text('Service Notice'), findsNothing);
    expect(find.text('app button'), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets('offline at launch: fails open, nothing is blocked', (tester) async {
    final service = ScriptedService()..offline();
    final h = await Harness.create(tester, service: service);
    final taps = ValueNotifier(0);
    await tester.pumpWidget(gateApp(h, taps));
    await h.settle(tester, 4);
    expect(find.text('Service Notice'), findsNothing);
    await tester.tap(find.text('app button'));
    expect(taps.value, 1);
    await h.dispose(tester);
  });

  testWidgets('while blocked the app is inert (taps do nothing)', (tester) async {
    final service = ScriptedService()..disable();
    final h = await Harness.create(tester, service: service);
    final taps = ValueNotifier(0);
    await tester.pumpWidget(gateApp(h, taps));
    await h.settle(tester, 4);
    expect(find.text('Service Notice'), findsOneWidget);

    await tester.tap(find.text('app button'), warnIfMissed: false);
    expect(taps.value, 0, reason: 'underlying screen cannot be used');
    await h.dispose(tester);
  });

  testWidgets('the button opens the configured link in the external browser', (tester) async {
    final opener = FakeUrlOpener();
    final service = ScriptedService()..disable(url: 'https://example.com/status');
    final h = await Harness.create(tester, service: service, opener: opener);
    await tester.pumpWidget(gateApp(h, ValueNotifier(0)));
    await h.settle(tester, 4);
    await tester.tap(find.text('Learn More'));
    await h.settle(tester, 3);
    expect(opener.opened.map((u) => u.toString()), ['https://example.com/status']);
    expect(find.text('The link could not be opened.'), findsNothing);

    opener.succeed = false;
    await tester.tap(find.text('Learn More'));
    await h.settle(tester, 3);
    expect(find.text('The link could not be opened.'), findsOneWidget);
    expect(find.text('Service Notice'), findsOneWidget, reason: 'still blocked');
    await h.dispose(tester);
  });

  testWidgets('an unsafe destination URL is not offered at all (no button)', (tester) async {
    final opener = FakeUrlOpener();
    final service = ScriptedService()..disable(url: 'intent://evil#Intent;scheme=x;end');
    final h = await Harness.create(tester, service: service, opener: opener);
    await tester.pumpWidget(gateApp(h, ValueNotifier(0)));
    await h.settle(tester, 4);
    expect(find.text('Service Notice'), findsOneWidget);
    expect(find.text('Learn More'), findsNothing);
    expect(opener.opened, isEmpty);
    await h.dispose(tester);
  });

  testWidgets('returning to the foreground re-checks: blocks when paused remotely, unblocks when restored', (tester) async {
    final service = ScriptedService();
    final h = await Harness.create(tester, service: service);
    await tester.pumpWidget(gateApp(h, ValueNotifier(0)));
    await h.settle(tester, 4);
    expect(service.requests, 1);
    expect(find.text('Service Notice'), findsNothing);

    service.disable();
    await resume(tester, h);
    expect(service.requests, 2);
    expect(find.text('Service Notice'), findsOneWidget);

    service.enable();
    await resume(tester, h);
    expect(service.requests, 3);
    expect(find.text('Service Notice'), findsNothing, reason: 'restored service dismisses the notice automatically');
    await h.dispose(tester);
  });

  testWidgets('if a later check cannot be completed it fails open and the notice goes away', (tester) async {
    final service = ScriptedService()..disable();
    final h = await Harness.create(tester, service: service);
    await tester.pumpWidget(gateApp(h, ValueNotifier(0)));
    await h.settle(tester, 4);
    expect(find.text('Service Notice'), findsOneWidget);

    service.offline();
    await resume(tester, h);
    expect(find.text('Service Notice'), findsNothing, reason: 'guide: unreachable endpoint must never lock the app');
    await h.dispose(tester);
  });

  testWidgets('overlapping checks collapse into one request', (tester) async {
    final answer = Completer<http.Response>();
    final service = ScriptedService();
    final h = await Harness.create(tester, service: service);
    await tester.pumpWidget(gateApp(h, ValueNotifier(0)));
    await h.settle(tester, 4);
    final before = service.requests;

    service.responder = () => answer.future;
    final container = ProviderScope.containerOf(tester.element(find.byType(ServiceGate)));
    unawaited(container.read(serviceStatusProvider.notifier).check());
    unawaited(container.read(serviceStatusProvider.notifier).check());
    unawaited(container.read(serviceStatusProvider.notifier).check());
    await h.settle(tester, 2);
    expect(service.requests - before, 1);
    answer.complete(http.Response('{"success":true,"data":{"enabled":true}}', 200));
    await h.settle(tester, 3);
    await h.dispose(tester);
  });

  testWidgets('the real app: a paused service covers every screen including the onboarding flow', (tester) async {
    final service = ScriptedService()..disable(title: 'Paused', message: 'Please check back shortly.');
    final h = await Harness.create(tester, service: service, onboarded: false);
    await tester.pumpWidget(ProviderScope(retry: (_, _) => null, overrides: h.overrides, child: const WazApp()));
    await h.settle(tester, 8);
    expect(find.text('Paused'), findsOneWidget);
    expect(find.text('Please check back shortly.'), findsOneWidget);
    // The onboarding button underneath cannot be used.
    await tester.tap(find.text('Next'), warnIfMissed: false);
    await h.settle(tester, 3);
    expect(h.onboarding.completed, isFalse);
    await h.dispose(tester);
  });

  testWidgets('real app: Android back is consumed while paused (no exit, no navigation underneath) and works again after restore', (tester) async {
    final service = ScriptedService();
    final h = await Harness.create(tester, service: service, onboarded: true);
    await tester.pumpWidget(ProviderScope(retry: (_, _) => null, overrides: h.overrides, child: const WazApp()));
    await h.settle(tester, 8);
    // Go somewhere with a back stack: Settings tab then a pushed screen is not needed; the root route suffices:
    // while enabled, back at the root is NOT consumed (the system may leave the app).
    expect(await tester.binding.handlePopRoute(), isFalse);

    service.disable();
    await resume(tester, h);
    expect(find.text('Service Notice'), findsOneWidget);
    expect(await tester.binding.handlePopRoute(), isTrue, reason: 'consumed: the app does not exit');
    await h.settle(tester, 2);
    expect(find.text('Service Notice'), findsOneWidget, reason: 'back never dismisses the notice');

    service.enable();
    await resume(tester, h);
    expect(find.text('Service Notice'), findsNothing);
    expect(await tester.binding.handlePopRoute(), isFalse, reason: 'normal back behaviour is restored');
    await h.dispose(tester);
  });
}
