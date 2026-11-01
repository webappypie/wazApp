import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wazapp/app.dart';
import 'package:wazapp/core/di/providers.dart';

import '../../support/harness.dart';

void main() {
  Widget app(Harness h) => ProviderScope(
        retry: (_, _) => null,
        overrides: h.overrides,
        child: const WazApp(),
      );

  testWidgets('first launch: splash -> onboarding -> home, flag stored only after finishing', (tester) async {
    final h = await Harness.create(tester, onboarded: false);
    await tester.pumpWidget(app(h));
    await h.settle(tester);

    expect(find.text('Save'), findsOneWidget);
    expect(h.onboarding.completed, isFalse);
    // No permission is requested during onboarding.
    expect(find.textContaining('Allow'), findsNothing);

    await tester.tap(find.text('Next'));
    await h.settle(tester);
    expect(find.text('Style'), findsOneWidget);
    await tester.tap(find.text('Next'));
    await h.settle(tester);
    expect(find.text('Share'), findsOneWidget);
    await tester.tap(find.text('Get started'));
    await h.settle(tester);

    // The intro leads to the guided permission setup; it counts as done only once that is finished.
    expect(find.text('Set up WazApp'), findsOneWidget);
    expect(h.onboarding.completed, isFalse);
    await tester.tap(find.text('Continue'));
    await h.settle(tester);

    expect(h.onboarding.completed, isTrue);
    expect(find.byType(NavigationBar), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets('Skip jumps to the permission setup, whose Skip finishes onboarding', (tester) async {
    final h = await Harness.create(tester, onboarded: false);
    await tester.pumpWidget(app(h));
    await h.settle(tester);
    await tester.tap(find.text('Skip'));
    await h.settle(tester);
    expect(find.text('Set up WazApp'), findsOneWidget);
    expect(h.onboarding.completed, isFalse);
    await tester.tap(find.text('Skip for now'));
    await h.settle(tester);
    expect(h.onboarding.completed, isTrue);
    expect(find.byType(NavigationBar), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets('returning user goes straight to the home shell with five real tabs', (tester) async {
    final h = await Harness.create(tester, onboarded: true);
    await tester.pumpWidget(app(h));
    await h.settle(tester);

    expect(find.text('Get started'), findsNothing);
    for (final label in ['Home', 'Saved', 'Create', 'Private', 'Settings']) {
      expect(find.descendant(of: find.byType(NavigationBar), matching: find.text(label)), findsOneWidget);
    }
    await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Saved')));
    await h.settle(tester);
    expect(find.text('Nothing saved yet'), findsOneWidget);

    await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Settings')));
    await h.settle(tester);
    expect(find.text('Appearance'), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets('theme choice in Settings changes the app theme mode', (tester) async {
    final h = await Harness.create(tester, onboarded: true);
    await tester.pumpWidget(app(h));
    await h.settle(tester);
    await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Settings')));
    await h.settle(tester);

    final container = ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));
    expect(container.read(themeModeProvider), ThemeMode.system);
    await tester.tap(find.text('Dark'));
    await h.settle(tester);
    expect(container.read(themeModeProvider), ThemeMode.dark);
    expect(tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode, ThemeMode.dark);
    await h.dispose(tester);
  });

  testWidgets('settings states the privacy position and independence disclaimer truthfully', (tester) async {
    final h = await Harness.create(tester, onboarded: true);
    await tester.pumpWidget(app(h));
    await h.settle(tester);
    await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Settings')));
    await h.settle(tester);
    final scroll = find.byType(Scrollable).last;
    await tester.scrollUntilVisible(find.textContaining('never uploads your photos or videos'), 200, scrollable: scroll);
    expect(find.textContaining('never uploads your photos or videos'), findsOneWidget);
    await tester.scrollUntilVisible(find.textContaining('No photos, videos, file names or personal data are sent'), 200, scrollable: scroll);
    expect(find.textContaining('wapcentral.webappypie.com'), findsOneWidget, reason: 'the network use is disclosed');
    await tester.scrollUntilVisible(find.textContaining('not affiliated with'), 200, scrollable: scroll);
    expect(find.textContaining('not affiliated with'), findsOneWidget);
    // Any mention of encryption must be a denial ("not encrypted"); never a claim.
    expect(find.textContaining(RegExp(r'(?<!not )(encrypted|encryption|AES)')), findsNothing);
    await h.dispose(tester);
  });
}
