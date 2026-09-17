// lib/features/settings/presentation/settings_screen.dart
//
// Grouped Settings Screen (REQ-SET-01 to REQ-SET-06).
//
// Sections:
//   1. Appearance (ThemeMode: Light/Dark/System)
//   2. Scanning (Schedule, Charging-only)
//   3. Cleanup (Duplicate retention rule, confirmation prompt)
//   4. Notifications (Individually controllable categories, conservative defaults)
//   5. Privacy & Data (On-device processing explanation, Clear analysis history)
//   6. Premium (Upgrade card or active status, Restore Purchases)
//   7. Support (Help & FAQ, Contact)
//   8. Legal & About (Privacy Policy, Terms, Licenses, App version)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/tokens.dart';
import '../../../core/di/providers.dart';
import '../../../core/widgets/action_widgets.dart';
import '../../../core/widgets/buttons.dart';
import '../domain/settings_state.dart';
import 'settings_controller.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsNotifierProvider);
    final notifier = ref.read(settingsNotifierProvider.notifier);
    final isPremium = ref.watch(isPremiumProvider);
    final purchaseService = ref.watch(purchaseServiceProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        children: [
          // -------------------------------------------------------------------
          // 1. Appearance (REQ-SET-02)
          // -------------------------------------------------------------------
          _SettingsSectionHeader(title: 'Appearance', icon: Icons.palette_outlined),
          _SettingsCard(
            children: [
              Padding(
                padding: const EdgeInsets.all(AppSpacing.cardPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'App Theme',
                      style: AppTextStyles.titleSmall,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Select preferred light, dark, or system matching theme',
                      style: AppTextStyles.bodySmall.copyWith(color: scheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    SizedBox(
                      width: double.infinity,
                      child: SegmentedButton<AppThemePreference>(
                        segments: const [
                          ButtonSegment(
                            value: AppThemePreference.system,
                            label: Text('System'),
                            icon: Icon(Icons.brightness_auto),
                          ),
                          ButtonSegment(
                            value: AppThemePreference.light,
                            label: Text('Light'),
                            icon: Icon(Icons.light_mode_outlined),
                          ),
                          ButtonSegment(
                            value: AppThemePreference.dark,
                            label: Text('Dark'),
                            icon: Icon(Icons.dark_mode_outlined),
                          ),
                        ],
                        selected: {settings.themePreference},
                        onSelectionChanged: (selected) {
                          notifier.setThemePreference(selected.first);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.lg),

          // -------------------------------------------------------------------
          // 2. Scanning (REQ-SET-04)
          // -------------------------------------------------------------------
          _SettingsSectionHeader(title: 'Scanning', icon: Icons.radar_outlined),
          _SettingsCard(
            children: [
              ListTile(
                title: const Text('Auto-scan frequency'),
                subtitle: Text(settings.scanFrequency.label),
                trailing: DropdownButton<ScanFrequency>(
                  value: settings.scanFrequency,
                  underline: const SizedBox.shrink(),
                  onChanged: (val) {
                    if (val != null) notifier.setScanFrequency(val);
                  },
                  items: ScanFrequency.values.map((freq) {
                    return DropdownMenuItem(
                      value: freq,
                      child: Text(freq.label),
                    );
                  }).toList(),
                ),
              ),
              const Divider(height: 1),
              SwitchListTile.adaptive(
                title: const Text('Scan on charger only'),
                subtitle: const Text('Preserve battery by scanning when connected to power'),
                value: settings.scanChargingOnly,
                onChanged: notifier.setScanChargingOnly,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.cardPadding,
                  AppSpacing.xs,
                  AppSpacing.cardPadding,
                  AppSpacing.cardPadding,
                ),
                child: Text(
                  'ℹ️ Background scans detect cleanup opportunities only. WappTidy NEVER deletes files automatically (P-02).',
                  style: AppTextStyles.bodySmall.copyWith(color: scheme.outline),
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.lg),

          // -------------------------------------------------------------------
          // 3. Cleanup Rules
          // -------------------------------------------------------------------
          _SettingsSectionHeader(title: 'Cleanup Preferences', icon: Icons.auto_delete_outlined),
          _SettingsCard(
            children: [
              ListTile(
                title: const Text('Duplicate selection default'),
                subtitle: Text(settings.duplicateKeepRule.label),
                trailing: DropdownButton<DuplicateKeepRule>(
                  value: settings.duplicateKeepRule,
                  underline: const SizedBox.shrink(),
                  onChanged: (val) {
                    if (val != null) notifier.setDuplicateKeepRule(val);
                  },
                  items: DuplicateKeepRule.values.map((rule) {
                    return DropdownMenuItem(
                      value: rule,
                      child: Text(rule.label),
                    );
                  }).toList(),
                ),
              ),
              const Divider(height: 1),
              SwitchListTile.adaptive(
                title: const Text('Confirm before action'),
                subtitle: const Text('Always show review sheet before moving or trashing items'),
                value: settings.confirmBeforeDelete,
                onChanged: notifier.setConfirmBeforeDelete,
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.lg),

          // -------------------------------------------------------------------
          // 4. Notifications (REQ-SET-05)
          // -------------------------------------------------------------------
          _SettingsSectionHeader(title: 'Notifications', icon: Icons.notifications_none_outlined),
          _SettingsCard(
            children: [
              SwitchListTile.adaptive(
                title: const Text('Storage full alerts'),
                subtitle: const Text('Notify when WhatsApp storage exceeds threshold'),
                value: settings.notifyStorageAlerts,
                onChanged: (val) => notifier.setNotificationToggle(notifyStorage: val),
              ),
              const Divider(height: 1),
              SwitchListTile.adaptive(
                title: const Text('Scan reminders'),
                subtitle: const Text('Remind to run maintenance scan when idle'),
                value: settings.notifyScanReminders,
                onChanged: (val) => notifier.setNotificationToggle(notifyScan: val),
              ),
              const Divider(height: 1),
              SwitchListTile.adaptive(
                title: const Text('Weekly hygiene tips'),
                subtitle: const Text('Occasional suggestions to keep storage clean'),
                value: settings.notifyWeeklyTips,
                onChanged: (val) => notifier.setNotificationToggle(notifyTips: val),
              ),
              const Divider(height: 1),
              SwitchListTile.adaptive(
                title: const Text('Quiet hours (10 PM – 8 AM)'),
                subtitle: const Text('Mute non-urgent notifications late at night'),
                value: settings.quietHoursEnabled,
                onChanged: notifier.setQuietHoursEnabled,
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.lg),

          // -------------------------------------------------------------------
          // 5. Privacy & Data (REQ-SET-06)
          // -------------------------------------------------------------------
          _SettingsSectionHeader(title: 'Privacy & Security', icon: Icons.security_outlined),
          _SettingsCard(
            children: [
              Padding(
                padding: const EdgeInsets.all(AppSpacing.cardPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.verified_user_outlined, color: kColorSuccess, size: 20),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          '100% On-Device Processing',
                          style: AppTextStyles.titleSmall.copyWith(color: kColorSuccess),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'All media indexing, duplicate matching, and categorization take place entirely on your device. '
                      'Your photos, videos, and private files are never transmitted to any external server or cloud.',
                      style: AppTextStyles.bodyMedium.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.delete_sweep_outlined, color: kColorDestructive),
                title: const Text(
                  'Clear Analysis History',
                  style: TextStyle(color: kColorDestructive, fontWeight: FontWeight.w600),
                ),
                subtitle: const Text('Purges local scan cache and reset index stats'),
                onTap: () async {
                  final confirmed = await ConfirmationSheet.show(
                    context,
                    title: 'Clear Analysis History?',
                    body: 'This will purge local index metadata. Your actual media files on disk will NOT be affected. The next scan will perform a fresh re-index.',
                    confirmLabel: 'Clear History',
                    isDestructive: true,
                  );
                  if (confirmed == true && context.mounted) {
                    await notifier.clearAnalysisHistory();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Analysis history cleared successfully'),
                          backgroundColor: kColorSuccess,
                        ),
                      );
                    }
                  }
                },
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.lg),

          // -------------------------------------------------------------------
          // 6. Premium Status / Upgrade (PRD §11)
          // -------------------------------------------------------------------
          _SettingsSectionHeader(title: 'Premium', icon: Icons.workspace_premium_outlined),
          _SettingsCard(
            children: [
              if (isPremium)
                ListTile(
                  leading: const Icon(Icons.check_circle_outline, color: kColorSuccess, size: 28),
                  title: const Text('WappTidy Lifetime Premium Active'),
                  subtitle: const Text('Ad-free experience, unlimited background scans'),
                )
              else ...[
                ListTile(
                  leading: Icon(Icons.stars_outlined, color: scheme.primary, size: 28),
                  title: const Text('Upgrade to Lifetime Premium'),
                  subtitle: const Text('Remove all ads permanently & unlock automatic background scans'),
                  trailing: PrimaryButton(
                    label: 'Upgrade',
                    width: 100,
                    onPressed: () async {
                      await purchaseService.purchase();
                    },
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.restore_outlined),
                  title: const Text('Restore Purchases'),
                  subtitle: const Text('Restore previous Google Play purchases on this device'),
                  onTap: () async {
                    await purchaseService.restorePurchases();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Purchase restore checked')),
                      );
                    }
                  },
                ),
              ],
            ],
          ),

          const SizedBox(height: AppSpacing.lg),

          // -------------------------------------------------------------------
          // 7. Support & Feedback
          // -------------------------------------------------------------------
          _SettingsSectionHeader(title: 'Support', icon: Icons.help_outline),
          _SettingsCard(
            children: [
              ListTile(
                leading: const Icon(Icons.question_answer_outlined),
                title: const Text('Frequently Asked Questions'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  _showInfoDialog(
                    context,
                    title: 'FAQ',
                    body: '• How does WappTidy find duplicates?\nIt compares exact file sizes and cryptographic SHA-256 hashes.\n\n'
                        '• Can deleted files be recovered?\nOn Android 11+, items are moved to the system Recycle Bin for ~30 days. On Android 10 and below, deletion is permanent.\n\n'
                        '• Does WappTidy upload my photos?\nNever. Everything runs 100% locally on your device.',
                  );
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.mail_outline),
                title: const Text('Contact Support'),
                subtitle: const Text('support@wapptidy.app'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Contact: support@wapptidy.app')),
                  );
                },
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.lg),

          // -------------------------------------------------------------------
          // 8. Legal & About
          // -------------------------------------------------------------------
          _SettingsSectionHeader(title: 'About & Legal', icon: Icons.info_outline),
          _SettingsCard(
            children: [
              ListTile(
                leading: const Icon(Icons.policy_outlined),
                title: const Text('Privacy Policy'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  _showInfoDialog(
                    context,
                    title: 'Privacy Policy',
                    body: 'WappTidy values your privacy above all else. We do not collect, store, sell, or transmit any of your media files or metadata. All processing is strictly on-device.',
                  );
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.gavel_outlined),
                title: const Text('Terms of Service'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  _showInfoDialog(
                    context,
                    title: 'Terms of Service',
                    body: 'WappTidy is provided as-is without warranties. You remain responsible for the files you choose to delete or archive.',
                  );
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.code_outlined),
                title: const Text('Open Source Licenses'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  showLicensePage(
                    context: context,
                    applicationName: 'WappTidy',
                    applicationVersion: '1.0.0 (Build 1)',
                  );
                },
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.cardPadding),
                child: Center(
                  child: Column(
                    children: [
                      Text(
                        'WappTidy — Media Cleaner & Organizer',
                        style: AppTextStyles.labelMedium.copyWith(color: scheme.outline),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Version 1.0.0 (Build 1)',
                        style: AppTextStyles.bodySmall.copyWith(color: scheme.outline),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }

  static void _showInfoDialog(BuildContext context, {required String title, required String body}) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(child: Text(body)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class _SettingsSectionHeader extends StatelessWidget {
  const _SettingsSectionHeader({required this.title, required this.icon});

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm, left: AppSpacing.xs),
      child: Row(
        children: [
          Icon(icon, size: 18, color: scheme.primary),
          const SizedBox(width: AppSpacing.sm),
          Text(
            title,
            style: AppTextStyles.titleSmall.copyWith(
              color: scheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}
