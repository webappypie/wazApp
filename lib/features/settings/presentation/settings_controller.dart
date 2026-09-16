// lib/features/settings/presentation/settings_controller.dart
//
// Notifier and providers for settings state and theme switching (REQ-SET-01..06).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../data/settings_repository.dart';
import '../domain/settings_state.dart';

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return SettingsRepository(database: db);
});

class SettingsNotifier extends Notifier<SettingsState> {
  @override
  SettingsState build() {
    _load();
    return const SettingsState();
  }

  SettingsRepository get _repo => ref.read(settingsRepositoryProvider);

  Future<void> _load() async {
    final settings = await _repo.loadSettings();
    state = settings;
  }

  Future<void> setThemePreference(AppThemePreference theme) async {
    state = state.copyWith(themePreference: theme);
    await _repo.saveTheme(theme);
  }

  Future<void> setScanFrequency(ScanFrequency freq) async {
    state = state.copyWith(scanFrequency: freq);
    await _repo.saveScanFrequency(freq);
  }

  Future<void> setScanChargingOnly(bool chargingOnly) async {
    state = state.copyWith(scanChargingOnly: chargingOnly);
    await _repo.saveScanChargingOnly(chargingOnly);
  }

  Future<void> setDuplicateKeepRule(DuplicateKeepRule rule) async {
    state = state.copyWith(duplicateKeepRule: rule);
    await _repo.saveDuplicateKeepRule(rule);
  }

  Future<void> setConfirmBeforeDelete(bool confirm) async {
    state = state.copyWith(confirmBeforeDelete: confirm);
    await _repo.saveConfirmBeforeDelete(confirm);
  }

  Future<void> setNotificationToggle({
    bool? notifyScan,
    bool? notifyStorage,
    bool? notifyTips,
  }) async {
    final updated = state.copyWith(
      notifyScanReminders: notifyScan,
      notifyStorageAlerts: notifyStorage,
      notifyWeeklyTips: notifyTips,
    );
    state = updated;
    await _repo.saveNotificationToggles(
      notifyScan: updated.notifyScanReminders,
      notifyStorage: updated.notifyStorageAlerts,
      notifyTips: updated.notifyWeeklyTips,
    );
  }

  Future<void> clearAnalysisHistory() async {
    await _repo.clearAnalysisHistory();
  }
}

final settingsNotifierProvider =
    NotifierProvider<SettingsNotifier, SettingsState>(SettingsNotifier.new);

/// Provider for dynamic ThemeMode (System, Light, Dark) used in MaterialApp (REQ-SET-02).
final appThemeModeProvider = Provider<ThemeMode>((ref) {
  final settings = ref.watch(settingsNotifierProvider);
  return settings.themePreference.toThemeMode();
});
