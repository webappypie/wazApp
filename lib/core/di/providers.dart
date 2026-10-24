// lib/core/di/providers.dart
//
// Root Riverpod providers. Interfaces are exposed (not concrete types) so tests
// can override platform adapters with fakes via ProviderScope/ProviderContainer.

import 'dart:io' show Platform;

import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/library/data/library_service.dart';
import '../../features/library/data/library_storage.dart';
import '../../features/library/data/media_probe.dart';
import '../../features/status/data/status_access_service.dart';
import '../database/app_database.dart';
import '../services/onboarding/onboarding_service.dart';
import '../services/onboarding/real_onboarding_service.dart';

// ---------------------------------------------------------------------------
// Storage
// ---------------------------------------------------------------------------

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

/// Opened once in `main()` and injected through a ProviderScope override.
final libraryStorageProvider = Provider<LibraryStorage>(
  (ref) => throw UnimplementedError('libraryStorageProvider must be overridden in main()'),
);

// ---------------------------------------------------------------------------
// Platform adapters
// ---------------------------------------------------------------------------

final _androidBridgeProvider = Provider<ChannelStatusAccessService?>(
  (ref) => Platform.isAndroid ? ChannelStatusAccessService() : null,
);

final statusAccessServiceProvider = Provider<StatusAccessService>(
  (ref) => ref.watch(_androidBridgeProvider) ?? const UnsupportedStatusAccessService(),
);

final mediaToolsProvider = Provider<MediaTools>(
  (ref) => ref.watch(_androidBridgeProvider) ?? const UnsupportedMediaTools(),
);

final mediaProbeProvider = Provider<MediaProbe>((ref) => const FlutterMediaProbe());

// ---------------------------------------------------------------------------
// Application services
// ---------------------------------------------------------------------------

final libraryServiceProvider = Provider<LibraryService>((ref) {
  return LibraryService(
    db: ref.watch(appDatabaseProvider),
    storage: ref.watch(libraryStorageProvider),
    status: ref.watch(statusAccessServiceProvider),
    tools: ref.watch(mediaToolsProvider),
    probe: ref.watch(mediaProbeProvider),
  );
});

final onboardingServiceProvider = Provider<OnboardingService>((ref) => RealOnboardingService());

// ---------------------------------------------------------------------------
// Theme
// ---------------------------------------------------------------------------

const _kThemeKey = 'theme_mode_v1';

class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    _load();
    return ThemeMode.system;
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kThemeKey);
      final mode = ThemeMode.values.where((m) => m.name == raw);
      if (mode.isNotEmpty) state = mode.first;
    } catch (_) {
      // Preferences unavailable: keep following the system theme.
    }
  }

  Future<void> set(ThemeMode mode) async {
    state = mode;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kThemeKey, mode.name);
    } catch (_) {
      // Non-fatal: the choice still applies for this session.
    }
  }
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);
