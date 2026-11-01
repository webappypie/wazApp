// Accessibility audit of the real app (WazApp + router) on its main screens.
//
// What is checked automatically:
//  - Android tap-target size (48 x 48 dp) and labelled tap targets (TalkBack announces something)
//  - text contrast (WCAG AA) in light and dark themes
//  - no layout overflow at 2.0x system text size, and a phone-narrow width
// What is NOT covered here (needs a person with TalkBack): reading order, announcements of changes,
// gesture alternatives on a real device. See docs/audit/ACCESSIBILITY_AUDIT.md.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wazapp/app.dart';
import 'package:wazapp/core/database/app_database.dart';
import 'package:wazapp/features/library/domain/library_models.dart';
import 'package:wazapp/features/create/presentation/create_screen.dart';
import 'package:wazapp/features/settings/presentation/settings_screen.dart';
import 'package:wazapp/features/status_maker/presentation/status_maker_screen.dart';

import '../support/fakes.dart';
import '../support/harness.dart';

var _tick = 0;

Future<void> addRow(WidgetTester tester, Harness h, String name, {String kind = 'image'}) async {
  await tester.runAsync(() async {
    final id = h.storage.newId();
    final ext = name.split('.').last;
    final path = h.storage.mediaPath(id, ext);
    await File(path).writeAsBytes(List.filled(2048, _tick));
    await h.db.insertMedia(SavedMediaTableCompanion.insert(
      id: id,
      path: path,
      kind: kind,
      mimeType: kind == 'video' ? 'video/mp4' : 'image/png',
      fileName: name,
      sizeBytes: 2048,
      savedAt: DateTime(2026, 10, 25).add(Duration(minutes: _tick++)),
      sourceType: 'imported',
    ));
  });
}

class Scenario {
  Scenario(this.tester, this.h);
  final WidgetTester tester;
  final Harness h;

  Future<void> tab(String label) async {
    await tester.tap(find.bySemanticsLabel(RegExp('^$label')).last);
    await h.settle(tester, 8);
  }
}

Future<Scenario> launch(WidgetTester tester, {Brightness brightness = Brightness.light, double textScale = 1.0}) async {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3.0; // 360 x 780 dp: a common small phone
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  tester.platformDispatcher.platformBrightnessTestValue = brightness;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    tester.platformDispatcher.clearAllTestValues();
  });
  final access = FakeStatusAccess();
  final h = await Harness.create(tester, access: access);
  access.addStatus(h.sourceDir, 'a.jpg');
  access.addStatus(h.sourceDir, 'b.mp4', kind: MediaKind.video);
  await addRow(tester, h, 'one.jpg');
  await addRow(tester, h, 'two.mp4', kind: 'video');
  await tester.pumpWidget(ProviderScope(retry: (_, _) => null, overrides: h.overrides, child: const WazApp()));
  await h.settle(tester, 12);
  return Scenario(tester, h);
}

/// Screens reachable from the shell by taps. Each entry opens the screen starting from the Home tab.
final Map<String, Future<void> Function(Scenario)> screens = {
  'Home': (s) async {},
  'Saved': (s) => s.tab('Saved'),
  'Create': (s) => s.tab('Create'),
  'Private': (s) => s.tab('Private'),
  'Settings': (s) => s.tab('Settings'),
  'Storage Manager': (s) async {
    await s.tab('Settings');
    await s.tester.scrollUntilVisible(find.text('Storage Manager'), 200,
        scrollable: find.descendant(of: find.byType(SettingsScreen), matching: find.byType(Scrollable)).first);
    await s.tester.ensureVisible(find.text('Storage Manager'));
    await s.tester.pump(const Duration(milliseconds: 100));
    await s.tester.tap(find.text('Storage Manager'));
    await s.h.settle(s.tester, 15);
  },
  'Status maker': (s) async {
    await s.tab('Create');
    await s.tester.scrollUntilVisible(find.text('Text status'), 200,
        scrollable: find.descendant(of: find.byType(CreateScreen), matching: find.byType(Scrollable)).first);
    await s.tester.tap(find.text('Text status'));
    await s.h.settle(s.tester, 15);
  },
  'Status maker (scrolled to styling controls)': (s) async {
    await screens['Status maker']!(s);
    await s.tester.scrollUntilVisible(find.text('Modern'), 150,
        scrollable: find.descendant(of: find.byType(StatusMakerScreen), matching: find.byType(Scrollable)).first);
    await s.tester.ensureVisible(find.text('Modern'));
    await s.h.settle(s.tester, 6);
  },
};

void main() {
  for (final entry in screens.entries) {
    for (final brightness in Brightness.values) {
      testWidgets('${entry.key} (${brightness.name}): tap targets, labels and contrast', (tester) async {
        final handle = tester.ensureSemantics();
        final s = await launch(tester, brightness: brightness);
        await entry.value(s);
        await s.h.settle(tester, 6);
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        await s.h.dispose(tester);
        handle.dispose();
      });
    }

    testWidgets('${entry.key}: no overflow at 2.0x text size', (tester) async {
      final errors = <String>[];
      final previous = FlutterError.onError;
      FlutterError.onError = (details) {
        final where = RegExp(r'lib/[a-z_/]+\.dart:\d+').allMatches(details.toString()).map((m) => m.group(0)).toSet();
        final first = details.exceptionAsString().trim().split(RegExp(r'[\r\n]+')).first;
        errors.add('$first @ ${where.join(', ')}');
      };
      final s = await launch(tester, textScale: 2.0);
      try {
        await entry.value(s);
        await s.h.settle(tester, 6);
      } catch (e) {
        errors.add('scenario failed: ${e.toString().split(RegExp(r'[\r\n]+')).first}');
      } finally {
        FlutterError.onError = previous; // must be restored before the test ends
      }
      await s.h.dispose(tester);
      expect(errors.toSet(), isEmpty, reason: '${entry.key} overflows or throws at 2.0x text');
    });
  }
}
