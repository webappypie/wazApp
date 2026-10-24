// lib/features/settings/domain/settings_state.dart
//
// Settings domain models and states (REQ-SET-01 to REQ-SET-06).

import 'package:flutter/material.dart';

/// App theme preference (REQ-SET-02).
enum AppThemePreference {
  system,
  light,
  dark;

  ThemeMode toThemeMode() {
    switch (this) {
      case AppThemePreference.system:
        return ThemeMode.system;
      case AppThemePreference.light:
        return ThemeMode.light;
      case AppThemePreference.dark:
        return ThemeMode.dark;
    }
  }

  String get displayName {
    switch (this) {
      case AppThemePreference.system:
        return 'System default';
      case AppThemePreference.light:
        return 'Light';
      case AppThemePreference.dark:
        return 'Dark';
    }
  }
}

/// Auto-scan frequency option (REQ-SET-04).
enum ScanFrequency {
  daily('Daily'),
  every3Days('Every 3 days'),
  weekly('Weekly'),
  off('Manual only');

  const ScanFrequency(this.label);
  final String label;
}

/// Duplicate retention rule (REQ-DUP-03).
enum DuplicateKeepRule {
  keepOldest('Keep oldest (original)'),
  keepNewest('Keep newest');

  const DuplicateKeepRule(this.label);
  final String label;
}

/// Auto-scan media source options (REQ-17).
enum AutoScanSourceOption {
  both('Both Apps'),
  whatsAppOnly('WhatsApp Only'),
  businessOnly('WhatsApp Business Only');

  const AutoScanSourceOption(this.label);
  final String label;
}

/// Settings state representing all user-configurable preferences.
class SettingsState {
  const SettingsState({
    this.themePreference = AppThemePreference.system,
    this.scanFrequency = ScanFrequency.weekly,
    this.scanChargingOnly = true,
    this.autoScanSourceOption = AutoScanSourceOption.both,
    this.whatsAppEnabled = true,
    this.whatsAppBusinessEnabled = true,
    this.duplicateKeepRule = DuplicateKeepRule.keepOldest,
    this.confirmBeforeDelete = true,
    this.notifyScanReminders = false,
    this.notifyStorageAlerts = true,
    this.notifyWeeklyTips = false,
    this.quietHoursEnabled = true,
    this.quietHoursStartHour = 22,
    this.quietHoursEndHour = 8,
  });

  final AppThemePreference themePreference;
  final ScanFrequency scanFrequency;
  final bool scanChargingOnly;
  final AutoScanSourceOption autoScanSourceOption;
  final bool whatsAppEnabled;
  final bool whatsAppBusinessEnabled;
  final DuplicateKeepRule duplicateKeepRule;
  final bool confirmBeforeDelete;
  final bool notifyScanReminders;
  final bool notifyStorageAlerts;
  final bool notifyWeeklyTips;
  final bool quietHoursEnabled;
  final int quietHoursStartHour;
  final int quietHoursEndHour;

  SettingsState copyWith({
    AppThemePreference? themePreference,
    ScanFrequency? scanFrequency,
    bool? scanChargingOnly,
    AutoScanSourceOption? autoScanSourceOption,
    bool? whatsAppEnabled,
    bool? whatsAppBusinessEnabled,
    DuplicateKeepRule? duplicateKeepRule,
    bool? confirmBeforeDelete,
    bool? notifyScanReminders,
    bool? notifyStorageAlerts,
    bool? notifyWeeklyTips,
    bool? quietHoursEnabled,
    int? quietHoursStartHour,
    int? quietHoursEndHour,
  }) {
    return SettingsState(
      themePreference: themePreference ?? this.themePreference,
      scanFrequency: scanFrequency ?? this.scanFrequency,
      scanChargingOnly: scanChargingOnly ?? this.scanChargingOnly,
      autoScanSourceOption: autoScanSourceOption ?? this.autoScanSourceOption,
      whatsAppEnabled: whatsAppEnabled ?? this.whatsAppEnabled,
      whatsAppBusinessEnabled: whatsAppBusinessEnabled ?? this.whatsAppBusinessEnabled,
      duplicateKeepRule: duplicateKeepRule ?? this.duplicateKeepRule,
      confirmBeforeDelete: confirmBeforeDelete ?? this.confirmBeforeDelete,
      notifyScanReminders: notifyScanReminders ?? this.notifyScanReminders,
      notifyStorageAlerts: notifyStorageAlerts ?? this.notifyStorageAlerts,
      notifyWeeklyTips: notifyWeeklyTips ?? this.notifyWeeklyTips,
      quietHoursEnabled: quietHoursEnabled ?? this.quietHoursEnabled,
      quietHoursStartHour: quietHoursStartHour ?? this.quietHoursStartHour,
      quietHoursEndHour: quietHoursEndHour ?? this.quietHoursEndHour,
    );
  }
}
