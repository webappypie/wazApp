// lib/features/private_folder/presentation/private_screen.dart
//
// The Private Folder tab. Honest about what it is: a hidden, optionally
// device-locked area of WazApp's private storage - NOT encrypted.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/database/app_database.dart';
import '../../../core/design/tokens.dart';
import '../../../core/di/providers.dart';
import '../../../core/router/app_router.dart';
import '../../../core/widgets/media_tile.dart';
import '../../../core/widgets/state_widgets.dart';
import '../../library/domain/library_models.dart';
import '../../library/presentation/library_actions.dart';
import '../../library/presentation/saved_screen.dart' show SavedThumb, ViewerArgs;
import 'private_providers.dart';

class PrivateScreen extends ConsumerStatefulWidget {
  const PrivateScreen({super.key});

  @override
  ConsumerState<PrivateScreen> createState() => _PrivateScreenState();
}

class _PrivateScreenState extends ConsumerState<PrivateScreen> {
  final Set<String> _selected = {};
  bool _unlocking = false;
  String? _message;
  bool _protectionUnavailable = false;
  bool _autoPrompted = false;

  bool get _selecting => _selected.isNotEmpty;

  Future<void> _unlock() async {
    if (_unlocking) return;
    setState(() {
      _unlocking = true;
      _message = null;
    });
    final r = await ref.read(privateSessionProvider.notifier).unlock();
    if (!mounted) return;
    setState(() {
      _unlocking = false;
      _protectionUnavailable = r == UnlockResult.protectionUnavailable;
      if (r == UnlockResult.cancelled) _message = 'Not unlocked. Try again when you are ready.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final access = ref.watch(privateSessionProvider);
    if (access == PrivateAccess.locked) {
      if (!_autoPrompted) {
        _autoPrompted = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _unlock();
        });
      }
      _selected.clear();
      return _lockedScaffold();
    }
    return _unlockedScaffold();
  }

  Widget _lockedScaffold() {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Private')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_outline, size: 64, color: scheme.primary),
              const SizedBox(height: AppSpacing.md),
              const Text('Private Folder is locked', style: AppTextStyles.titleLarge),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Use your fingerprint, face, PIN, pattern or password to open it.',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyMedium.copyWith(color: scheme.onSurfaceVariant),
              ),
              if (_message != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(_message!, style: AppTextStyles.bodyMedium.copyWith(color: scheme.error), textAlign: TextAlign.center),
              ],
              const SizedBox(height: AppSpacing.lg),
              FilledButton.icon(
                icon: _unlocking
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.lock_open),
                label: const Text('Unlock'),
                onPressed: _unlocking ? null : _unlock,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _unlockedScaffold() {
    final items = ref.watch(privateItemsProvider);
    final lockEnabled = ref.watch(privateLockSettingProvider).value ?? false;
    return PopScope(
      canPop: !_selecting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _selecting) setState(_selected.clear);
      },
      child: Scaffold(
        appBar: _selecting ? _selectionBar(items.value ?? const []) : _normalBar(lockEnabled),
        body: Column(
          children: [
            _InfoBanner(
              lockEnabled: lockEnabled,
              protectionUnavailable: _protectionUnavailable,
              onOpenSettings: () => context.go(AppRoutes.settings),
            ),
            Expanded(
              child: items.when(
                loading: () => const SkeletonGridLoader(),
                error: (e, _) => ErrorState(
                  message: 'Could not load the Private Folder.',
                  onRetry: () => ref.invalidate(privateItemsProvider),
                ),
                data: (list) {
                  if (list.isEmpty) {
                    return EmptyState(
                      icon: Icons.enhanced_encryption_outlined,
                      title: 'Nothing here yet',
                      body: 'In Saved, select photos or videos and choose "Move to Private Folder". '
                          'They will be hidden from Saved and from the Storage Manager lists.',
                      action: OutlinedButton(
                        onPressed: () => context.go(AppRoutes.saved),
                        child: const Text('Go to Saved'),
                      ),
                    );
                  }
                  return GridView.builder(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 140,
                      mainAxisSpacing: AppSpacing.sm,
                      crossAxisSpacing: AppSpacing.sm,
                    ),
                    itemCount: list.length,
                    itemBuilder: (context, i) => _tile(list, i),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _normalBar(bool lockEnabled) => AppBar(
        title: const Text('Private'),
        actions: [
          IconButton(
            tooltip: 'Lock now',
            icon: Icon(lockEnabled ? Icons.lock : Icons.lock_open_outlined),
            onPressed: lockEnabled
                ? () => ref.read(privateSessionProvider.notifier).lock()
                : () => context.go(AppRoutes.settings),
          ),
        ],
      );

  PreferredSizeWidget _selectionBar(List<SavedMedia> all) {
    final chosen = all.where((m) => _selected.contains(m.id)).toList();
    final canExport = ref.read(statusAccessServiceProvider).isSupported;
    return AppBar(
      leading: IconButton(
        tooltip: 'Cancel selection',
        icon: const Icon(Icons.close),
        onPressed: () => setState(_selected.clear),
      ),
      title: Text('${_selected.length} selected'),
      actions: [
        IconButton(
          tooltip: 'Select all',
          icon: const Icon(Icons.select_all),
          onPressed: () => setState(() => _selected.addAll(all.map((m) => m.id))),
        ),
        IconButton(
          tooltip: 'Move back to Saved',
          icon: const Icon(Icons.lock_open),
          onPressed: () async {
            final r = await restoreFromPrivateFlow(context, ref, _selected.toList());
            if (r != null && mounted) setState(_selected.clear);
          },
        ),
        PopupMenuButton<String>(
          tooltip: 'More actions',
          onSelected: (v) async {
            if (v == 'share') {
              await shareMedia(context, chosen);
            } else if (v == 'gallery') {
              await exportFlow(context, ref, chosen);
            } else if (v == 'delete') {
              final r = await deleteFlow(context, ref, _selected.toList());
              if (r != null && mounted) setState(_selected.clear);
            }
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'share', child: Text('Share…')),
            if (canExport) const PopupMenuItem(value: 'gallery', child: Text('Save a copy to gallery')),
            const PopupMenuItem(value: 'delete', child: Text('Delete…')),
          ],
        ),
      ],
    );
  }

  Widget _tile(List<SavedMedia> items, int i) {
    final m = items[i];
    return MediaTile(
      semanticLabel: 'private ${m.kind} ${m.fileName}',
      isVideo: m.isVideo,
      duration: m.isVideo ? m.duration : null,
      selectionMode: _selecting,
      selected: _selected.contains(m.id),
      onTap: () {
        if (_selecting) {
          setState(() => _selected.contains(m.id) ? _selected.remove(m.id) : _selected.add(m.id));
        } else {
          context.push(AppRoutes.viewer, extra: ViewerArgs(ids: [for (final x in items) x.id], index: i));
        }
      },
      onLongPress: () => setState(() => _selected.add(m.id)),
      child: SavedThumb(media: m),
    );
  }
}

/// Always-visible, plain-language statement of what the Private Folder does and does not do.
class _InfoBanner extends StatelessWidget {
  const _InfoBanner({required this.lockEnabled, required this.protectionUnavailable, required this.onOpenSettings});
  final bool lockEnabled;
  final bool protectionUnavailable;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final String headline;
    final String body;
    final bool warn;
    if (protectionUnavailable) {
      headline = 'Not protected right now';
      body = 'The device lock is switched on in WazApp, but this phone has no screen lock set up, so nothing '
          'can ask you to authenticate. Set a PIN, pattern or password in your phone settings.';
      warn = true;
    } else if (lockEnabled) {
      headline = 'Locked with your device authentication';
      body = 'Hidden from Saved and storage lists. Files are stored privately on this phone but are not encrypted, '
          'and they are deleted if you uninstall WazApp.';
      warn = false;
    } else {
      headline = 'Hidden, but not locked';
      body = 'Anyone who opens WazApp can see these items. Turn on the device lock in Settings to require your '
          'fingerprint, face, PIN, pattern or password. Files are not encrypted and are deleted if you uninstall WazApp.';
      warn = true;
    }
    return Material(
      color: warn ? scheme.errorContainer.withValues(alpha: 0.5) : scheme.primaryContainer.withValues(alpha: 0.6),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.sm, AppSpacing.sm),
        child: Row(
          children: [
            Icon(warn ? Icons.info_outline : Icons.lock, color: warn ? scheme.error : scheme.primary),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(headline, style: AppTextStyles.labelLarge),
                  Text(body, style: AppTextStyles.bodySmall),
                ],
              ),
            ),
            if (!lockEnabled || protectionUnavailable)
              TextButton(onPressed: onOpenSettings, child: const Text('Settings')),
          ],
        ),
      ),
    );
  }
}
