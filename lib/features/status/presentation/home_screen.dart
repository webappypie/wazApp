// lib/features/status/presentation/home_screen.dart
//
// Home: browse statuses the user has authorised (Android) or import media
// (all platforms). Never shows a fake feed: Android lists only what the granted
// folder really contains; iOS offers Photos/Files import and says why.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/tokens.dart';
import '../../../core/di/providers.dart';
import '../../../core/error/app_error.dart';
import '../../../core/router/app_router.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/media_tile.dart';
import '../../../core/widgets/state_widgets.dart';
import '../../library/domain/library_models.dart';
import '../../library/presentation/library_actions.dart';
import '../domain/status_models.dart';
import 'status_providers.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with WidgetsBindingObserver {
  final Set<String> _selected = {}; // StatusItem.uri
  bool get _selecting => _selected.isNotEmpty;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // New statuses appear while the user is in WhatsApp: rescan on return.
    if (state == AppLifecycleState.resumed) {
      final app = ref.read(selectedStatusAppProvider);
      ref.invalidate(statusAccessProvider(app));
      ref.invalidate(statusListProvider(app));
    }
  }

  @override
  Widget build(BuildContext context) {
    final access = ref.watch(statusAccessServiceProvider);
    return Scaffold(
      appBar: _selecting ? _selectionBar() : _normalBar(access.isSupported),
      body: access.isSupported ? _androidBody() : const _ImportOnlyBody(),
    );
  }

  PreferredSizeWidget _normalBar(bool supported) {
    return AppBar(
      title: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('WazApp', style: AppTextStyles.titleLarge),
          Text('Save. Style. Share.', style: AppTextStyles.labelSmall),
        ],
      ),
      actions: [
        if (supported)
          IconButton(
            tooltip: 'Rescan statuses',
            icon: const Icon(Icons.refresh),
            onPressed: () {
              final app = ref.read(selectedStatusAppProvider);
              ref.invalidate(statusAccessProvider(app));
              ref.invalidate(statusListProvider(app));
            },
          ),
        IconButton(
          tooltip: 'Import photos or videos',
          icon: const Icon(Icons.add_photo_alternate_outlined),
          onPressed: () => showImportSheet(context, ref),
        ),
      ],
    );
  }

  PreferredSizeWidget _selectionBar() {
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
          onPressed: _selectAll,
        ),
        IconButton(
          tooltip: 'Save selected',
          icon: const Icon(Icons.download_rounded),
          onPressed: _saveSelected,
        ),
      ],
    );
  }

  List<StatusItem> _currentItems() {
    final app = ref.read(selectedStatusAppProvider);
    return ref.read(statusListProvider(app)).value ?? const [];
  }

  void _selectAll() {
    setState(() => _selected
      ..clear()
      ..addAll(_currentItems().map((e) => e.uri)));
  }

  Future<void> _saveSelected() async {
    final items = _currentItems().where((e) => _selected.contains(e.uri)).toList();
    setState(_selected.clear);
    await saveStatusesFlow(context, ref, items, onViewSaved: () => context.go(AppRoutes.saved));
  }

  Widget _androidBody() {
    final installed = ref.watch(installedAppsProvider);
    return installed.when(
      loading: () => const SkeletonGridLoader(),
      error: (e, _) => ErrorState(
        message: 'Could not check which apps are installed.',
        onRetry: () => ref.invalidate(installedAppsProvider),
      ),
      data: (apps) {
        final available = [for (final a in StatusApp.values) if (apps[a] == true) a];
        if (available.isEmpty) return const _NoWhatsAppBody();
        var selected = ref.watch(selectedStatusAppProvider);
        if (!available.contains(selected)) {
          selected = available.first;
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => ref.read(selectedStatusAppProvider.notifier).set(selected),
          );
        }
        return Column(
          children: [
            if (available.length > 1)
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.sm),
                child: SegmentedButton<StatusApp>(
                  segments: [for (final a in available) ButtonSegment(value: a, label: Text(a.label))],
                  selected: {selected},
                  onSelectionChanged: (s) {
                    setState(_selected.clear);
                    ref.read(selectedStatusAppProvider.notifier).set(s.first);
                  },
                ),
              ),
            Expanded(child: _StatusSection(app: selected, selected: _selected, onChanged: () => setState(() {}))),
          ],
        );
      },
    );
  }
}

// -----------------------------------------------------------------------------

class _StatusSection extends ConsumerStatefulWidget {
  const _StatusSection({required this.app, required this.selected, required this.onChanged});
  final StatusApp app;
  final Set<String> selected;
  final VoidCallback onChanged;

  @override
  ConsumerState<_StatusSection> createState() => _StatusSectionState();
}

class _StatusSectionState extends ConsumerState<_StatusSection> {
  bool _requesting = false;
  String? _accessMessage;

  Future<void> _requestAccess() async {
    setState(() {
      _requesting = true;
      _accessMessage = null;
    });
    try {
      final r = await ref.read(statusAccessServiceProvider).requestAccess(widget.app);
      switch (r) {
        case AccessRequestResult.granted:
          ref.invalidate(statusAccessProvider(widget.app));
          ref.invalidate(statusListProvider(widget.app));
        case AccessRequestResult.cancelled:
          _accessMessage = 'No folder was chosen.';
        case AccessRequestResult.wrongFolder:
          _accessMessage =
              'That folder does not contain ${widget.app.label} statuses. Open the ${widget.app.label} folder and choose it again.';
      }
    } on AppError catch (e) {
      _accessMessage = e.message;
    } finally {
      if (mounted) setState(() => _requesting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasAccess = ref.watch(statusAccessProvider(widget.app));
    return hasAccess.when(
      loading: () => const SkeletonGridLoader(),
      error: (e, _) => ErrorState(
        message: 'Could not check folder access.',
        onRetry: () => ref.invalidate(statusAccessProvider(widget.app)),
      ),
      data: (granted) {
        if (!granted) {
          return _AccessSetup(
            app: widget.app,
            busy: _requesting,
            message: _accessMessage,
            onChoose: _requestAccess,
          );
        }
        return _StatusGrid(app: widget.app, selected: widget.selected, onChanged: widget.onChanged);
      },
    );
  }
}

class _AccessSetup extends StatelessWidget {
  const _AccessSetup({required this.app, required this.busy, required this.onChoose, this.message});
  final StatusApp app;
  final bool busy;
  final String? message;
  final VoidCallback onChoose;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        Icon(Icons.folder_special_outlined, size: 64, color: scheme.primary),
        const SizedBox(height: AppSpacing.md),
        Text('Allow access to ${app.label} statuses',
            style: AppTextStyles.headlineSmall, textAlign: TextAlign.center),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Android keeps statuses in a private folder. To save them, you choose that folder once and '
          'WazApp only reads it. Nothing is uploaded.',
          style: AppTextStyles.bodyMedium.copyWith(color: scheme.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.lg),
        _Step(n: 1, text: 'Tap "Choose status folder".'),
        _Step(n: 2, text: 'The picker opens on the ${app.label} ".Statuses" folder. If not, open Android › media › '
            '${app == StatusApp.business ? 'com.whatsapp.w4b' : 'com.whatsapp'} › ${app.label} › Media › .Statuses.'),
        _Step(n: 3, text: 'Tap "Use this folder", then "Allow".'),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Statuses only appear after you have viewed them in ${app.label}.',
          style: AppTextStyles.bodySmall.copyWith(color: scheme.onSurfaceVariant),
        ),
        if (message != null) ...[
          const SizedBox(height: AppSpacing.md),
          Text(message!, style: AppTextStyles.bodyMedium.copyWith(color: scheme.error)),
        ],
        const SizedBox(height: AppSpacing.lg),
        PrimaryButton(
          label: 'Choose status folder',
          icon: const Icon(Icons.folder_open),
          isLoading: busy,
          onPressed: onChoose,
        ),
      ],
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.n, required this.text});
  final int n;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: scheme.primaryContainer,
            child: Text('$n', style: AppTextStyles.labelMedium.copyWith(color: scheme.onPrimaryContainer)),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(text, style: AppTextStyles.bodyMedium)),
        ],
      ),
    );
  }
}

class _StatusGrid extends ConsumerWidget {
  const _StatusGrid({required this.app, required this.selected, required this.onChanged});
  final StatusApp app;
  final Set<String> selected;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(statusListProvider(app));
    final savedKeys = ref.watch(savedSourceKeysProvider).value ?? const <String>{};
    return list.when(
      loading: () => const SkeletonGridLoader(),
      error: (e, _) {
        final noAccess = e is MediaAccessError && e.failure == MediaFailure.noAccess;
        return ErrorState(
          message: e is AppError ? e.message : 'Could not load statuses.',
          onRetry: () {
            ref.invalidate(statusAccessProvider(app));
            ref.invalidate(statusListProvider(app));
          },
          retryLabel: noAccess ? 'Check access' : 'Retry',
        );
      },
      data: (items) {
        if (items.isEmpty) {
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(statusListProvider(app)),
            child: ListView(children: [
              SizedBox(
                height: 420,
                child: EmptyState(
                  icon: Icons.hourglass_empty,
                  title: 'No statuses found',
                  body: 'Open ${app.label}, view some statuses, then pull down to refresh. '
                      'Statuses expire after 24 hours.',
                ),
              ),
            ]),
          );
        }
        final selecting = selected.isNotEmpty;
        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(statusListProvider(app));
            await ref.read(statusListProvider(app).future);
          },
          child: GridView.builder(
            padding: const EdgeInsets.all(AppSpacing.sm),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 140,
              mainAxisSpacing: AppSpacing.sm,
              crossAxisSpacing: AppSpacing.sm,
            ),
            itemCount: items.length,
            itemBuilder: (context, i) {
              final item = items[i];
              final isSaved = savedKeys.contains(item.sourceKey);
              return MediaTile(
                semanticLabel: '${item.kind.name} status, ${isSaved ? 'already saved' : 'not saved'}',
                isVideo: item.kind == MediaKind.video,
                selectionMode: selecting,
                selected: selected.contains(item.uri),
                saved: isSaved,
                onTap: () {
                  if (selecting) {
                    selected.contains(item.uri) ? selected.remove(item.uri) : selected.add(item.uri);
                    onChanged();
                  } else {
                    context.push(AppRoutes.statusPreview, extra: item);
                  }
                },
                onLongPress: () {
                  selected.add(item.uri);
                  onChanged();
                },
                trailingAction: isSaved
                    ? null
                    : IconButton.filledTonal(
                        tooltip: 'Save',
                        iconSize: 18,
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.download_rounded),
                        onPressed: () => saveStatusesFlow(context, ref, [item],
                            onViewSaved: () => context.go(AppRoutes.saved)),
                      ),
                child: _StatusThumb(item: item),
              );
            },
          ),
        );
      },
    );
  }
}

class _StatusThumb extends ConsumerWidget {
  const _StatusThumb({required this.item});
  final StatusItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final thumb = ref.watch(statusThumbnailProvider(item));
    return thumb.when(
      data: (bytes) => bytes == null
          ? const Center(child: Icon(Icons.broken_image_outlined))
          : Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true, excludeFromSemantics: true),
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const Center(child: Icon(Icons.broken_image_outlined)),
    );
  }
}

// -----------------------------------------------------------------------------

class _NoWhatsAppBody extends StatelessWidget {
  const _NoWhatsAppBody();

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) => EmptyState(
        icon: Icons.chat_outlined,
        title: 'WhatsApp not found',
        body: 'Install WhatsApp or WhatsApp Business to browse its statuses, or import photos and videos '
            'from your device to edit and share them.',
        action: SecondaryButton(
          label: 'Import from device',
          onPressed: () => showImportSheet(context, ref),
        ),
      ),
    );
  }
}

/// iOS / platforms without status access.
class _ImportOnlyBody extends ConsumerWidget {
  const _ImportOnlyBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        Icon(Icons.photo_library_outlined, size: 64, color: scheme.primary),
        const SizedBox(height: AppSpacing.md),
        const Text('Bring in your media', style: AppTextStyles.headlineSmall, textAlign: TextAlign.center),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'On this device WazApp cannot look inside WhatsApp. Save a status to Photos from WhatsApp, '
          'then import it here to keep, edit and share it.',
          style: AppTextStyles.bodyMedium.copyWith(color: scheme.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.lg),
        PrimaryButton(
          label: 'Import from Photos',
          icon: const Icon(Icons.photo_library_outlined),
          onPressed: () => importFlow(context, ref, ImportSource.photos),
        ),
        const SizedBox(height: AppSpacing.sm),
        SecondaryButton(
          label: 'Import from Files',
          onPressed: () => importFlow(context, ref, ImportSource.files),
        ),
      ],
    );
  }
}
