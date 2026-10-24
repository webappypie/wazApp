// test/features/settings/media_sources_settings_test.dart
//
// Verification for Media Sources settings section (REQ-21):
// - Shows installed status for WhatsApp and WhatsApp Business.
// - Toggling a source off prompts confirmation (Keep Indexed vs Remove from Index).
// - Auto-scan source preference dropdown is displayed when both are installed.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wapptidy/core/design/tokens.dart';
import 'package:wapptidy/core/di/providers.dart';
import 'package:wapptidy/core/services/installed_apps/installed_apps_service.dart';
import 'package:wapptidy/features/settings/presentation/settings_screen.dart';

Widget _buildSettingsApp({
  InstalledSources installedSources = InstalledSources.both,
}) {
  return ProviderScope(
    overrides: [
      installedAppsServiceProvider.overrideWithValue(
        FakeInstalledAppsService(installedSources: installedSources),
      ),
    ],
    child: MaterialApp(
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      home: const SettingsScreen(),
    ),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Media Sources Settings (REQ-21)', () {
    testWidgets('Displays Media Sources section and switches when both apps installed', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_buildSettingsApp(installedSources: InstalledSources.both));
      await tester.pumpAndSettle();

      expect(find.text('Media Sources'), findsOneWidget);
      expect(find.text('WhatsApp'), findsOneWidget);
      expect(find.text('WhatsApp Business'), findsOneWidget);

      // Auto-scan source dropdown is visible when both installed
      expect(find.text('Auto-scan media sources'), findsOneWidget);
    });

    testWidgets('Disables WhatsApp Business switch when not installed', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_buildSettingsApp(installedSources: InstalledSources.whatsAppOnly));
      await tester.pumpAndSettle();

      expect(find.text('Media Sources'), findsOneWidget);
      expect(find.text('Installed'), findsOneWidget); // For WhatsApp
      expect(find.text('Not installed on this device'), findsOneWidget); // For Business

      // Auto-scan source dropdown should NOT be visible when not both installed
      expect(find.text('Auto-scan media sources'), findsNothing);
    });

    testWidgets('Toggling off WhatsApp opens confirmation dialog with Keep and Remove options', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_buildSettingsApp(installedSources: InstalledSources.both));
      await tester.pumpAndSettle();

      // Find the WhatsApp switch and tap it
      final waSwitch = find.widgetWithText(SwitchListTile, 'WhatsApp');
      expect(waSwitch, findsOneWidget);

      await tester.tap(waSwitch);
      await tester.pumpAndSettle();

      // Verify dialog is shown
      expect(find.text('Disable scans for WhatsApp?'), findsOneWidget);
      expect(find.text('Keep Indexed'), findsOneWidget);
      expect(find.text('Remove from Index'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);

      // Tap Keep Indexed
      await tester.tap(find.text('Keep Indexed'));
      await tester.pumpAndSettle();

      // Dialog is dismissed
      expect(find.text('Disable scans for WhatsApp?'), findsNothing);
    });
  });
}
