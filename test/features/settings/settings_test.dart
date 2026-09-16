// test/features/settings/settings_test.dart
//
// Widget and unit tests for Settings feature (REQ-SET-01 to REQ-SET-06).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wapptidy/core/database/app_database.dart';
import 'package:wapptidy/core/design/tokens.dart';
import 'package:wapptidy/core/di/providers.dart';
import 'package:wapptidy/core/services/purchases/fake_purchase_service.dart';
import 'package:wapptidy/core/services/purchases/purchase_service.dart';
import 'package:wapptidy/core/widgets/action_widgets.dart';
import 'package:wapptidy/features/settings/domain/settings_state.dart';
import 'package:wapptidy/features/settings/presentation/settings_controller.dart';
import 'package:wapptidy/features/settings/presentation/settings_screen.dart';

Widget _buildSettingsApp({
  AppDatabase? db,
  FakePurchaseService? fakePurchase,
}) {
  return ProviderScope(
    overrides: [
      if (db != null) appDatabaseProvider.overrideWithValue(db),
      if (fakePurchase != null)
        purchaseServiceProvider.overrideWithValue(fakePurchase),
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

  group('REQ-SET-01: Grouped Settings Sections', () {
    testWidgets('Renders all grouped sections and headers', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_buildSettingsApp());
      await tester.pumpAndSettle();

      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Appearance'), findsOneWidget);
      expect(find.text('Scanning'), findsOneWidget);
      expect(find.text('Cleanup Preferences'), findsOneWidget);
      expect(find.text('Notifications'), findsOneWidget);
      expect(find.text('Privacy & Security'), findsOneWidget);
      expect(find.text('Premium'), findsOneWidget);
      expect(find.text('Support'), findsOneWidget);
      expect(find.text('About & Legal'), findsOneWidget);
    });
  });

  group('REQ-SET-02: Theme Switching (Light, Dark, System)', () {
    testWidgets('Selecting Dark theme updates appThemeModeProvider to ThemeMode.dark',
        (tester) async {
      await tester.pumpWidget(_buildSettingsApp());
      await tester.pumpAndSettle();

      // Find Dark Segment in SegmentedButton
      final darkSegment = find.text('Dark');
      expect(darkSegment, findsOneWidget);

      await tester.tap(darkSegment);
      await tester.pumpAndSettle();

      final element = tester.element(find.byType(SettingsScreen));
      final container = ProviderScope.containerOf(element);

      expect(container.read(appThemeModeProvider), ThemeMode.dark);
      expect(
        container.read(settingsNotifierProvider).themePreference,
        AppThemePreference.dark,
      );
    });

    testWidgets('Selecting Light theme updates appThemeModeProvider to ThemeMode.light',
        (tester) async {
      await tester.pumpWidget(_buildSettingsApp());
      await tester.pumpAndSettle();

      final lightSegment = find.text('Light');
      expect(lightSegment, findsOneWidget);

      await tester.tap(lightSegment);
      await tester.pumpAndSettle();

      final element = tester.element(find.byType(SettingsScreen));
      final container = ProviderScope.containerOf(element);

      expect(container.read(appThemeModeProvider), ThemeMode.light);
    });
  });

  group('REQ-SET-05: Notification Controls with Conservative Defaults', () {
    testWidgets('Defaults: storage alerts ON, scan reminders OFF, tips OFF',
        (tester) async {
      await tester.pumpWidget(_buildSettingsApp());
      await tester.pumpAndSettle();

      final element = tester.element(find.byType(SettingsScreen));
      final container = ProviderScope.containerOf(element);
      final state = container.read(settingsNotifierProvider);

      expect(state.notifyStorageAlerts, isTrue);
      expect(state.notifyScanReminders, isFalse);
      expect(state.notifyWeeklyTips, isFalse);
    });

    testWidgets('Toggling notification updates state', (tester) async {
      await tester.pumpWidget(_buildSettingsApp());
      await tester.pumpAndSettle();

      final element = tester.element(find.byType(SettingsScreen));
      final notifier =
          ProviderScope.containerOf(element).read(settingsNotifierProvider.notifier);

      await notifier.setNotificationToggle(notifyScan: true);
      await tester.pumpAndSettle();

      final updated =
          ProviderScope.containerOf(element).read(settingsNotifierProvider);
      expect(updated.notifyScanReminders, isTrue);
    });
  });

  group('REQ-SET-06: Privacy Page & Clear Analysis History', () {
    testWidgets('Privacy section displays on-device processing text', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_buildSettingsApp());
      await tester.pumpAndSettle();

      expect(find.text('100% On-Device Processing'), findsOneWidget);
      expect(
        find.textContaining('never transmitted to any external server'),
        findsOneWidget,
      );
    });

    testWidgets('Tapping Clear Analysis History shows ConfirmationSheet',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_buildSettingsApp());
      await tester.pumpAndSettle();

      final clearTile = find.text('Clear Analysis History');
      expect(clearTile, findsOneWidget);

      await tester.tap(clearTile);
      await tester.pumpAndSettle();

      // ConfirmationSheet appears (P-02)
      expect(find.byType(ConfirmationSheet), findsOneWidget);
      expect(find.text('Clear Analysis History?'), findsOneWidget);

      // Tap cancel
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.byType(ConfirmationSheet), findsNothing);
    });
  });

  group('Premium Section & Entitlement display', () {
    testWidgets('Free users see Upgrade and Restore options', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final fakePurchase = FakePurchaseService();
      await tester.pumpWidget(_buildSettingsApp(fakePurchase: fakePurchase));
      await tester.pumpAndSettle();

      expect(find.text('Upgrade to Lifetime Premium'), findsOneWidget);
      expect(find.text('Restore Purchases'), findsOneWidget);
    });

    testWidgets('Premium users see active status indicator', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final fakePurchase = FakePurchaseService()
        ..setEntitlement(PremiumEntitlement.premium);

      await tester.pumpWidget(_buildSettingsApp(fakePurchase: fakePurchase));
      await tester.pumpAndSettle();

      expect(find.text('WappTidy Lifetime Premium Active'), findsOneWidget);
      expect(find.text('Upgrade to Lifetime Premium'), findsNothing);
    });
  });
}
