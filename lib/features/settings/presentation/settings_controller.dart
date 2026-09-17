// lib/features/settings/presentation/settings_controller.dart
//
// Notifier and providers for settings state and theme switching (REQ-SET-01..06).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/services/background_task/background_task_service.dart';
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
    await _syncBackgroundScan();
  }

  Future<void> _syncBackgroundScan() async {
    final bgService = ref.read(backgroundTaskServiceProvider);
    if (state.scanFrequency == ScanFrequency.off) {
      await bgService.cancelBackgroundScan();
    } else {
      final schedule = switch (state.scanFrequency) {
        ScanFrequency.daily => ScanSchedule.daily,
        ScanFrequency.every3Days => ScanSchedule.everyThreeDays,
        ScanFrequency.weekly => ScanSchedule.weekly,
        ScanFrequency.off => ScanSchedule.weekly,
      };
      await bgService.scheduleBackgroundScan(
        schedule: schedule,
        chargingOnly: state.scanChargingOnly,
      );
    }
  }

  Future<void> setThemePreference(AppThemePreference theme) async {
    state = state.copyWith(themePreference: theme);
    await _repo.saveTheme(theme);
  }

  Future<void> setScanFrequency(ScanFrequency freq) async {
    state = state.copyWith(scanFrequency: freq);
    await _repo.saveScanFrequency(freq);
    await _syncBackgroundScan();
  }

  Future<void> setScanChargingOnly(bool chargingOnly) async {
    state = state.copyWith(scanChargingOnly: chargingOnly);
    await _repo.saveScanChargingOnly(chargingOnly);
    await _syncBackgroundScan();
  }

  Future<void> setQuietHoursEnabled(bool enabled) async {
    state = state.copyWith(quietHoursEnabled: enabled);
    await _repo.saveQuietHours(
      enabled: enabled,
      startHour: state.quietHoursStartHour,
      endHour: state.quietHoursEndHour,
    );
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
