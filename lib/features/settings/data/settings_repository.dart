// lib/features/settings/data/settings_repository.dart
//
// SharedPreferences-backed repository for application settings (REQ-SET-01..06).

import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/database/app_database.dart';
import '../domain/settings_state.dart';

class SettingsRepository {
  SettingsRepository({
    SharedPreferences? preferences,
    AppDatabase? database,
  })  : _prefs = preferences,
        _db = database;

  SharedPreferences? _prefs;
  final AppDatabase? _db;

  static const _keyTheme = 'settings_theme';
  static const _keyScanFreq = 'settings_scan_freq';
  static const _keyScanCharging = 'settings_scan_charging_only';
  static const _keyDupRule = 'settings_duplicate_rule';
  static const _keyConfirmDelete = 'settings_confirm_delete';
  static const _keyNotifyScan = 'settings_notify_scan_reminders';
  static const _keyNotifyStorage = 'settings_notify_storage_alerts';
  static const _keyNotifyTips = 'settings_notify_weekly_tips';
  static const _keyQuietHoursEnabled = 'settings_quiet_hours_enabled';
  static const _keyQuietHoursStart = 'settings_quiet_hours_start';
  static const _keyQuietHoursEnd = 'settings_quiet_hours_end';

  Future<SharedPreferences> _getPrefs() async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  Future<SettingsState> loadSettings() async {
    final prefs = await _getPrefs();

    final themeStr = prefs.getString(_keyTheme);
    final theme = AppThemePreference.values.firstWhere(
      (e) => e.name == themeStr,
      orElse: () => AppThemePreference.system,
    );

    final freqStr = prefs.getString(_keyScanFreq);
    final freq = ScanFrequency.values.firstWhere(
      (e) => e.name == freqStr,
      orElse: () => ScanFrequency.weekly,
    );

    final chargingOnly = prefs.getBool(_keyScanCharging) ?? true;

    final dupStr = prefs.getString(_keyDupRule);
    final dupRule = DuplicateKeepRule.values.firstWhere(
      (e) => e.name == dupStr,
      orElse: () => DuplicateKeepRule.keepOldest,
    );

    final confirmDelete = prefs.getBool(_keyConfirmDelete) ?? true;
    final notifyScan = prefs.getBool(_keyNotifyScan) ?? false;
    final notifyStorage = prefs.getBool(_keyNotifyStorage) ?? true;
    final notifyTips = prefs.getBool(_keyNotifyTips) ?? false;
    final quietHoursEnabled = prefs.getBool(_keyQuietHoursEnabled) ?? true;
    final quietHoursStart = prefs.getInt(_keyQuietHoursStart) ?? 22;
    final quietHoursEnd = prefs.getInt(_keyQuietHoursEnd) ?? 8;

    return SettingsState(
      themePreference: theme,
      scanFrequency: freq,
      scanChargingOnly: chargingOnly,
      duplicateKeepRule: dupRule,
      confirmBeforeDelete: confirmDelete,
      notifyScanReminders: notifyScan,
      notifyStorageAlerts: notifyStorage,
      notifyWeeklyTips: notifyTips,
      quietHoursEnabled: quietHoursEnabled,
      quietHoursStartHour: quietHoursStart,
      quietHoursEndHour: quietHoursEnd,
    );
  }

  Future<void> saveTheme(AppThemePreference theme) async {
    final prefs = await _getPrefs();
    await prefs.setString(_keyTheme, theme.name);
  }

  Future<void> saveScanFrequency(ScanFrequency freq) async {
    final prefs = await _getPrefs();
    await prefs.setString(_keyScanFreq, freq.name);
  }

  Future<void> saveScanChargingOnly(bool chargingOnly) async {
    final prefs = await _getPrefs();
    await prefs.setBool(_keyScanCharging, chargingOnly);
  }

  Future<void> saveDuplicateKeepRule(DuplicateKeepRule rule) async {
    final prefs = await _getPrefs();
    await prefs.setString(_keyDupRule, rule.name);
  }

  Future<void> saveConfirmBeforeDelete(bool confirm) async {
    final prefs = await _getPrefs();
    await prefs.setBool(_keyConfirmDelete, confirm);
  }

  Future<void> saveNotificationToggles({
    required bool notifyScan,
    required bool notifyStorage,
    required bool notifyTips,
  }) async {
    final prefs = await _getPrefs();
    await prefs.setBool(_keyNotifyScan, notifyScan);
    await prefs.setBool(_keyNotifyStorage, notifyStorage);
    await prefs.setBool(_keyNotifyTips, notifyTips);
  }

  Future<void> saveQuietHours({
    required bool enabled,
    int? startHour,
    int? endHour,
  }) async {
    final prefs = await _getPrefs();
    await prefs.setBool(_keyQuietHoursEnabled, enabled);
    if (startHour != null) {
      await prefs.setInt(_keyQuietHoursStart, startHour);
    }
    if (endHour != null) {
      await prefs.setInt(_keyQuietHoursEnd, endHour);
    }
  }

  /// Clears analysis history per REQ-SET-06.
  /// Resets scan states and cleared media items cache if db is available.
  Future<void> clearAnalysisHistory() async {
    if (_db != null) {
      await _db.clearAnalysisData();
    }
  }
}
