import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wazapp/app.dart';
import 'package:wazapp/core/database/app_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wazapp/features/library/data/library_service.dart';
import 'package:wazapp/features/library/domain/library_models.dart';
import 'package:wazapp/features/library/presentation/saved_screen.dart';
import 'package:wazapp/features/library/presentation/viewer_screen.dart';
import 'package:wazapp/features/private_folder/data/device_auth_service.dart';
import 'package:wazapp/features/private_folder/presentation/private_screen.dart';
import 'package:wazapp/features/settings/presentation/settings_screen.dart';

import '../../support/fakes.dart';
import '../../support/harness.dart';

/// [video] rows open no image file, so Windows cannot hold a lock that would block renaming/deleting them.
Future<SavedMedia> seed(WidgetTester tester, Harness h, String name, {bool private = false, bool video = false}) async {
  return (await tester.runAsync(() async {
    final service = LibraryService(db: h.db, storage: h.storage, status: h.access, tools: h.access, probe: FakeProbe());
    final item = h.access.addStatus(h.sourceDir, name, kind: video ? MediaKind.video : MediaKind.image);
    final saved = (await service.saveStatus(item)).media;
    if (private) await service.moveToPrivate([saved.id]);
    return (await h.db.findById(saved.id))!;
  }))!;
}

void setLock(bool on) => SharedPreferences.setMockInitialValues({'private_lock_enabled_v1': on});

Widget screenHost(Harness h, Widget child) => h.wrapRouter([
      GoRoute(path: '/', builder: (_, _) => child),
      GoRoute(path: '/saved', builder: (_, _) => const Scaffold(body: Text('saved tab'))),
      GoRoute(path: '/settings', builder: (_, _) => const Scaffold(body: Text('settings page'))),
      GoRoute(path: '/viewer', builder: (_, s) => ViewerScreen(args: s.extra! as ViewerArgs)),
    ]);

void main() {
  testWidgets('lock off: the folder opens without a prompt and says plainly that it is hidden, not locked', (tester) async {
    setLock(false);
    final auth = FakeAuth();
    final h = await Harness.create(tester, auth: auth);
    await tester.pumpWidget(screenHost(h, const PrivateScreen()));
    await h.settle(tester, 6);

    expect(auth.prompts, isEmpty);
    expect(find.text('Hidden, but not locked'), findsOneWidget);
    expect(find.textContaining('not encrypted'), findsOneWidget);
    expect(find.text('Nothing here yet'), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets('lock on: prompts, then shows only private items; normal items never appear here', (tester) async {
    setLock(true);
    final auth = FakeAuth();
    final h = await Harness.create(tester, auth: auth);
    await seed(tester, h, 'normal.jpg');
    await seed(tester, h, 'secret.jpg', private: true);
    await tester.pumpWidget(screenHost(h, const PrivateScreen()));
    await h.settle(tester, 6);

    expect(auth.prompts, ['Unlock your Private Folder']);
    expect(find.text('Locked with your device authentication'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('private image secret.jpg')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('normal.jpg')), findsNothing);
    await h.dispose(tester);
  });

  testWidgets('cancelled authentication keeps everything hidden; retry unlocks', (tester) async {
    setLock(true);
    final auth = FakeAuth(outcomes: [AuthOutcome.cancelled, AuthOutcome.success]);
    final h = await Harness.create(tester, auth: auth);
    await seed(tester, h, 'secret.jpg', private: true);
    await tester.pumpWidget(screenHost(h, const PrivateScreen()));
    await h.settle(tester, 6);

    expect(find.text('Private Folder is locked'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('secret.jpg')), findsNothing, reason: 'nothing leaks while locked');
    expect(find.textContaining('Not unlocked'), findsOneWidget);

    await tester.tap(find.text('Unlock'));
    await h.settle(tester, 6);
    expect(auth.prompts, hasLength(2));
    expect(find.bySemanticsLabel(RegExp('private image secret.jpg')), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets('lock on but the phone has no screen lock any more: opens with an explicit "not protected" warning', (tester) async {
    setLock(true);
    final auth = FakeAuth(availabilityValue: AuthAvailability.notEnrolled);
    final h = await Harness.create(tester, auth: auth);
    await tester.pumpWidget(screenHost(h, const PrivateScreen()));
    await h.settle(tester, 6);

    expect(auth.prompts, isEmpty);
    expect(find.text('Not protected right now'), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets('moving back to Saved and deleting from the Private Folder', (tester) async {
    setLock(false);
    final h = await Harness.create(tester);
    final a = await seed(tester, h, 'a.mp4', private: true, video: true);
    await seed(tester, h, 'b.mp4', private: true, video: true);
    await tester.pumpWidget(screenHost(h, const PrivateScreen()));
    await h.settle(tester, 6);

    await tester.longPress(find.bySemanticsLabel(RegExp('private video a.mp4')));
    await h.settle(tester, 3);
    await tester.tap(find.byTooltip('Move back to Saved'));
    await h.pumpUntil(tester, () => find.textContaining('Moved back to Saved').evaluate().isNotEmpty);
    expect((await tester.runAsync(() => h.db.findById(a.id)))!.isPrivate, isFalse);
    expect(find.bySemanticsLabel(RegExp('private video a.mp4')), findsNothing);

    await tester.longPress(find.bySemanticsLabel(RegExp('private video b.mp4')));
    await h.settle(tester, 3);
    await tester.tap(find.byTooltip('More actions'));
    await h.settle(tester, 12); // popup menu animation
    await tester.tap(find.text('Delete…'));
    await h.settle(tester, 6);
    expect(find.text('Delete this item?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await h.settle(tester, 3);
    expect(await tester.runAsync(() => h.db.watchPrivate().first), hasLength(1));
    await tester.pump(const Duration(seconds: 5));
    await h.dispose(tester);
  });

  testWidgets('Saved: "Move to Private Folder" hides the item from Saved immediately', (tester) async {
    setLock(false);
    final h = await Harness.create(tester);
    final a = await seed(tester, h, 'a.mp4', video: true);
    await tester.pumpWidget(screenHost(h, const SavedScreen()));
    await h.settle(tester, 6);

    await tester.longPress(find.bySemanticsLabel(RegExp('video a.mp4')));
    await h.settle(tester, 3);
    await tester.tap(find.byTooltip('More actions'));
    await h.settle(tester, 12);
    await tester.tap(find.text('Move to Private Folder'));
    await h.pumpUntil(tester, () => find.textContaining('Moved to your Private Folder').evaluate().isNotEmpty);

    expect((await tester.runAsync(() => h.db.findById(a.id)))!.isPrivate, isTrue);
    expect(find.bySemanticsLabel(RegExp('video a.mp4')), findsNothing);
    expect(find.text('Nothing saved yet'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await h.dispose(tester);
  });

  testWidgets('a private item cannot be viewed while the folder is locked', (tester) async {
    setLock(true);
    final h = await Harness.create(tester, auth: FakeAuth(outcomes: [AuthOutcome.cancelled]));
    final a = await seed(tester, h, 'a.jpg', private: true);
    await tester.pumpWidget(screenHost(h, Consumer(
      builder: (c, ref, _) => Scaffold(
        body: Center(
          child: FilledButton(
            onPressed: () => c.push('/viewer', extra: ViewerArgs(ids: [a.id], index: 0)),
            child: const Text('open viewer'),
          ),
        ),
      ),
    )));
    await h.settle(tester, 4);
    await tester.tap(find.text('open viewer'));
    await h.settle(tester, 6);
    // Locked: the viewer shows no media and closes itself.
    expect(find.text('open viewer'), findsOneWidget);
    expect(find.byTooltip('Share'), findsNothing);
    await h.dispose(tester);
  });

  testWidgets('leaving the app re-locks the Private Folder', (tester) async {
    setLock(true);
    final auth = FakeAuth();
    final h = await Harness.create(tester, auth: auth, onboarded: true);
    await seed(tester, h, 'secret.jpg', private: true);
    await tester.pumpWidget(ProviderScope(retry: (_, _) => null, overrides: h.overrides, child: const WazApp()));
    await h.settle(tester, 6);
    await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Private')));
    await h.settle(tester, 6);
    expect(find.bySemanticsLabel(RegExp('private image secret.jpg')), findsOneWidget);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await h.settle(tester, 3);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await h.settle(tester, 3);
    expect(find.bySemanticsLabel(RegExp('secret.jpg')), findsNothing);
    expect(find.text('Private Folder is locked'), findsOneWidget);
    await h.dispose(tester);
  });

  group('Settings lock switch', () {
    Future<void> openSettings(WidgetTester tester, Harness h) async {
      await tester.pumpWidget(screenHost(h, const SettingsScreen()));
      await h.settle(tester, 6);
      await tester.scrollUntilVisible(find.text('Require device authentication'), 200,
          scrollable: find.byType(Scrollable).first);
      await h.settle(tester, 3);
    }

    bool switchOn(WidgetTester t) => t.widget<SwitchListTile>(find.byType(SwitchListTile)).value;

    testWidgets('turning it on requires passing the prompt and is persisted', (tester) async {
      setLock(false);
      final auth = FakeAuth();
      final h = await Harness.create(tester, auth: auth);
      await openSettings(tester, h);
      expect(switchOn(tester), isFalse);

      await tester.tap(find.byType(SwitchListTile));
      await h.pumpUntil(tester, () => switchOn(tester));
      expect(auth.prompts.single, contains('turn on'));
      expect((await SharedPreferences.getInstance()).getBool('private_lock_enabled_v1'), isTrue);
      await tester.pump(const Duration(seconds: 5));
      await h.dispose(tester);
    });

    testWidgets('a cancelled prompt leaves the lock off; no lock is created that cannot be opened', (tester) async {
      setLock(false);
      final auth = FakeAuth(outcomes: [AuthOutcome.cancelled]);
      final h = await Harness.create(tester, auth: auth);
      await openSettings(tester, h);
      await tester.tap(find.byType(SwitchListTile));
      await h.pumpUntil(tester, () => find.textContaining('Not changed').evaluate().isNotEmpty);
      expect(switchOn(tester), isFalse);
      expect((await SharedPreferences.getInstance()).getBool('private_lock_enabled_v1') ?? false, isFalse);
      await tester.pump(const Duration(seconds: 5));
      await h.dispose(tester);
    });

    testWidgets('turning it off also requires authentication', (tester) async {
      setLock(true);
      final auth = FakeAuth(outcomes: [AuthOutcome.cancelled, AuthOutcome.success]);
      final h = await Harness.create(tester, auth: auth);
      await openSettings(tester, h);
      expect(switchOn(tester), isTrue);

      await tester.tap(find.byType(SwitchListTile));
      await h.pumpUntil(tester, () => find.textContaining('Not changed').evaluate().isNotEmpty);
      expect(switchOn(tester), isTrue, reason: 'someone holding the unlocked phone cannot just switch it off');

      await tester.pump(const Duration(seconds: 5));
      await tester.tap(find.byType(SwitchListTile));
      await h.pumpUntil(tester, () => !switchOn(tester));
      expect(auth.prompts.last, contains('turn off'));
      expect((await SharedPreferences.getInstance()).getBool('private_lock_enabled_v1'), isFalse);
      await tester.pump(const Duration(seconds: 5));
      await h.dispose(tester);
    });

    testWidgets('a phone without a screen lock cannot enable it and is told why', (tester) async {
      setLock(false);
      final h = await Harness.create(tester, auth: FakeAuth(availabilityValue: AuthAvailability.notEnrolled));
      await openSettings(tester, h);
      expect(tester.widget<SwitchListTile>(find.byType(SwitchListTile)).onChanged, isNull);
      expect(find.textContaining('no screen lock set up'), findsOneWidget);
      await h.dispose(tester);
    });

    testWidgets('never claims encryption', (tester) async {
      setLock(false);
      final h = await Harness.create(tester);
      await openSettings(tester, h);
      expect(find.textContaining('not encrypted'), findsOneWidget);
      expect(find.textContaining('AES'), findsNothing);
      expect(find.textContaining('encrypted and'), findsNothing);
      await h.dispose(tester);
    });
  });
}
