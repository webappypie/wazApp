// lib/features/settings/presentation/settings_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/tokens.dart';
import '../../../core/di/providers.dart';
import '../../../core/error/app_error.dart';
import '../../../core/format.dart';
import '../../library/presentation/library_providers.dart';
import '../../status/domain/status_models.dart';
import '../../status/presentation/status_providers.dart';

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
    final supported = ref.watch(statusAccessServiceProvider).isSupported;
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
                ButtonSegment(value: ThemeMode.system, label: Text('System'), icon: Icon(Icons.brightness_auto)),
                ButtonSegment(value: ThemeMode.light, label: Text('Light'), icon: Icon(Icons.light_mode_outlined)),
                ButtonSegment(value: ThemeMode.dark, label: Text('Dark'), icon: Icon(Icons.dark_mode_outlined)),
              ],
              selected: {theme},
              onSelectionChanged: (s) => ref.read(themeModeProvider.notifier).set(s.first),
            ),
          ),
          if (supported) ...[
            const _Header('Status folders'),
            const _StatusFolders(),
          ],
          const _Header('Storage'),
          ListTile(
            leading: const Icon(Icons.sd_storage_outlined),
            title: const Text('WazApp library'),
            subtitle: Text(used.when(
              data: (b) => '${count ?? 0} items · ${formatBytes(b)}',
              loading: () => 'Calculating…',
              error: (_, _) => 'Unavailable',
            )),
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
            subtitle: Text('WazApp never uploads your photos or videos and has no account or cloud backup. '
                'Files are only read from folders you choose or pick yourself.'),
          ),
          const _Header('About'),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('WazApp · Save. Style. Share.'),
            subtitle: Text('WazApp is an independent app. It is not affiliated with, endorsed by or '
                'sponsored by WhatsApp or Meta.'),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.lg, AppSpacing.md, AppSpacing.sm),
      child: Text(text, style: AppTextStyles.titleSmall.copyWith(color: Theme.of(context).colorScheme.primary)),
    );
  }
}

class _StatusFolders extends ConsumerWidget {
  const _StatusFolders();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final installed = ref.watch(installedAppsProvider);
    return installed.when(
      loading: () => const ListTile(title: Text('Checking installed apps…')),
      error: (_, _) => const ListTile(title: Text('Could not check installed apps.')),
      data: (apps) {
        final list = [for (final a in StatusApp.values) if (apps[a] == true) a];
        if (list.isEmpty) {
          return const ListTile(
            leading: Icon(Icons.chat_outlined),
            title: Text('WhatsApp not installed'),
            subtitle: Text('Install WhatsApp or WhatsApp Business to browse statuses.'),
          );
        }
        return Column(children: [for (final a in list) _FolderTile(app: a)]);
      },
    );
  }
}

class _FolderTile extends ConsumerWidget {
  const _FolderTile({required this.app});
  final StatusApp app;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final access = ref.watch(statusAccessProvider(app));
    final granted = access.value == true;
    final service = ref.read(statusAccessServiceProvider);

    Future<void> choose() async {
      try {
        final r = await service.requestAccess(app);
        ref.invalidate(statusAccessProvider(app));
        ref.invalidate(statusListProvider(app));
        if (!context.mounted) return;
        final msg = switch (r) {
          AccessRequestResult.granted => '${app.label} folder connected',
          AccessRequestResult.cancelled => 'No folder was chosen',
          AccessRequestResult.wrongFolder => 'That is not the ${app.label} status folder',
        };
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      } on AppError catch (e) {
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }

    return ListTile(
      leading: Icon(granted ? Icons.folder_open : Icons.folder_off_outlined),
      title: Text(app.label),
      subtitle: Text(access.isLoading ? 'Checking…' : granted ? 'Folder access granted' : 'Folder not chosen'),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        TextButton(onPressed: choose, child: Text(granted ? 'Change' : 'Choose')),
        if (granted)
          TextButton(
            onPressed: () async {
              await service.revokeAccess(app);
              ref.invalidate(statusAccessProvider(app));
              ref.invalidate(statusListProvider(app));
            },
            child: const Text('Remove'),
          ),
      ]),
    );
  }
}
