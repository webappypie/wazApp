// lib/features/settings/presentation/settings_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/tokens.dart';
import '../../../core/di/providers.dart';
import '../../../core/format.dart';
import '../../../core/router/app_router.dart';
import '../../library/presentation/library_providers.dart';
import '../../private_folder/data/device_auth_service.dart';
import '../../private_folder/presentation/private_providers.dart';
import '../../../integrations/wapcentral/ads/ads_controller.dart';
import '../../../integrations/wapcentral/ads/full_screen_ads.dart';
import '../../permissions/presentation/access_controller.dart';
import '../../permissions/presentation/widgets/access_card.dart';

/// Bytes used by WazApp's own library (media + thumbnails).
final libraryUsedBytesProvider = FutureProvider.autoDispose<int>((ref) async {
  ref.watch(libraryItemsProvider); // recompute when the library changes
  return ref.watch(libraryStorageProvider).usedBytes();
});

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(themeModeProvider);
    final used = ref.watch(libraryUsedBytesProvider);
    final count = ref.watch(libraryItemsProvider).value?.length;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: AppSpacing.xl),
        children: [
          const _Header('Appearance'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(
                  value: ThemeMode.system,
                  label: Text('System'),
                  icon: Icon(Icons.brightness_auto),
                ),
                ButtonSegment(
                  value: ThemeMode.light,
                  label: Text('Light'),
                  icon: Icon(Icons.light_mode_outlined),
                ),
                ButtonSegment(
                  value: ThemeMode.dark,
                  label: Text('Dark'),
                  icon: Icon(Icons.dark_mode_outlined),
                ),
              ],
              selected: {theme},
              onSelectionChanged: (s) =>
                  ref.read(themeModeProvider.notifier).set(s.first),
            ),
          ),
          const _Header('Permissions & Access'),
          const _PermissionsSection(),
          const _Header('Notifications'),
          ListTile(
            leading: const Icon(Icons.notifications_outlined),
            title: const Text('Notification inbox'),
            subtitle: const Text('Messages from WazApp'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(AppRoutes.notifications),
          ),
          ListTile(
            leading: const Icon(Icons.tune),
            title: const Text('Notification preferences'),
            subtitle: const Text('Choose which kinds of messages you receive'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(AppRoutes.notificationPreferences),
          ),
          const _SupportTile(),
          const _Header('Private Folder'),
          const _PrivateLockTile(),
          const _Header('Storage'),
          ListTile(
            leading: const Icon(Icons.cleaning_services_outlined),
            title: const Text('Storage Manager'),
            subtitle: const Text(
              'See what WazApp stores, find large files and duplicates',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(AppRoutes.storage),
          ),
          ListTile(
            leading: const Icon(Icons.sd_storage_outlined),
            title: const Text('WazApp library'),
            subtitle: Text(
              used.when(
                data: (b) => '${count ?? 0} items · ${formatBytes(b)}',
                loading: () => 'Calculating…',
                error: (_, _) => 'Unavailable',
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Text(
              'Saved items live in WazApp\'s private storage. They are removed if you uninstall the app '
              'or clear its data. Use "Save to gallery" or Share to keep a copy elsewhere.',
              style: AppTextStyles.bodySmall,
            ),
          ),
          const _Header('Privacy'),
          const ListTile(
            leading: Icon(Icons.lock_outline),
            title: Text('Your media stays on this device'),
            subtitle: Text(
              'WazApp never uploads your photos or videos and has no account or cloud backup. '
              'Files are only read from folders you choose or pick yourself.',
            ),
          ),
          const ListTile(
            leading: Icon(Icons.cloud_sync_outlined),
            title: Text('Service connection'),
            subtitle: Text(
              'WazApp talks to wapcentral.webappypie.com to check that the service is running, to load ad '
              'settings and promotions, and (only if you allow notifications) to register this device for '
              'messages. Requests carry the app identifier, a push token and, like any web request, your IP '
              'address. No photos, videos, file names or personal data are sent. If the network is unavailable, '
              'every media feature keeps working offline.',
            ),
          ),
          const _Header('About'),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text('Open-source licences'),
            subtitle: const Text(
              'Includes the fonts used by the editor and status maker.',
            ),
            onTap: () =>
                showLicensePage(context: context, applicationName: 'WazApp'),
          ),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('WazApp · Save. Style. Share.'),
            subtitle: Text(
              'WazApp is an independent app. It is not affiliated with, endorsed by or '
              'sponsored by WhatsApp or Meta.',
            ),
          ),
        ],
      ),
    );
  }
}

class _PrivateLockTile extends ConsumerStatefulWidget {
  const _PrivateLockTile();

  @override
  ConsumerState<_PrivateLockTile> createState() => _PrivateLockTileState();
}

class _PrivateLockTileState extends ConsumerState<_PrivateLockTile> {
  bool _busy = false;

  Future<void> _toggle(bool want) async {
    setState(() => _busy = true);
    final notifier = ref.read(privateLockSettingProvider.notifier);
    final r = want ? await notifier.enable() : await notifier.disable();
    if (!mounted) return;
    setState(() => _busy = false);
    final msg = switch (r) {
      ToggleResult.changed =>
        want ? 'Private Folder lock is on' : 'Private Folder lock is off',
      ToggleResult.notConfirmed =>
        'Not changed. Authentication was not completed.',
      ToggleResult.deviceHasNoLock => 'Set up a screen lock (PIN, pattern, password or biometrics) in your phone settings first.',
    };
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final enabled = ref.watch(privateLockSettingProvider).value ?? false;
    final availability = ref.watch(deviceAuthAvailabilityProvider).value;
    final canUse = availability == AuthAvailability.available;
    return Column(
      children: [
        SwitchListTile(
          secondary: const Icon(Icons.lock_outline),
          title: const Text('Require device authentication'),
          subtitle: Text(
            canUse || enabled
                ? 'Ask for your fingerprint, face, PIN, pattern or password to open the Private Folder, and lock it again when you leave the app.'
                : 'Your phone has no screen lock set up, so the Private Folder cannot be locked yet.',
          ),
          value: enabled,
          onChanged: _busy || (!canUse && !enabled) ? null : _toggle,
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Text(
            'The Private Folder hides items from Saved and storage lists. Files are kept in private app storage, '
            'but they are not encrypted, and they are deleted if you uninstall WazApp or clear its data.',
            style: AppTextStyles.bodySmall,
          ),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: Text(
        text,
        style: AppTextStyles.titleSmall.copyWith(
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}

/// Real state of every permission/access item, with the action that fits it. Re-read whenever the
/// app returns to the foreground (see WazApp.didChangeAppLifecycleState).
class _PermissionsSection extends ConsumerWidget {
  const _PermissionsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overview = ref.watch(accessOverviewProvider);
    return overview.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(AppSpacing.md),
        child: LinearProgressIndicator(),
      ),
      error: (_, _) => ListTile(
        leading: const Icon(Icons.error_outline),
        title: const Text('Could not read permission states'),
        trailing: TextButton(
          onPressed: () => ref.invalidate(accessOverviewProvider),
          child: const Text('Retry'),
        ),
      ),
      data: (data) => Column(
        children: [
          for (final s in data.visible) AccessCard(snapshot: s, compact: true),
          ListTile(
            leading: const Icon(Icons.checklist_rtl),
            title: const Text('Run guided setup again'),
            subtitle: const Text(
              'Walk through WhatsApp, notifications and the Private Folder lock.',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(AppRoutes.setup),
          ),
        ],
      ),
    );
  }
}

/// Optional rewarded ad. Shown only when WAPCentral has rewarded ads on; nothing in WazApp is locked behind it.
class _SupportTile extends ConsumerWidget {
  const _SupportTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(adsControllerProvider); // rebuild when ads become available/unavailable
    final ads = ref.read(fullScreenAdsProvider);
    if (!ads.canOfferRewarded) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Header('Support WazApp'),
        ListTile(
          leading: const Icon(Icons.favorite_border),
          title: const Text('Watch a short ad'),
          subtitle: const Text('Entirely optional. It helps keep WazApp free; no feature is locked behind it.'),
          trailing: const Icon(Icons.play_circle_outline),
          onTap: () async {
            final r = await ads.showSupportRewarded(context);
            if (!context.mounted) return;
            final msg = r == null || !r.success
                ? 'No ad is available right now. Please try again later.'
                : r.rewardGranted
                    ? 'Thank you for supporting WazApp!'
                    : 'The ad was closed early. Thanks for trying!';
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(SnackBar(content: Text(msg)));
          },
        ),
      ],
    );
  }
}
