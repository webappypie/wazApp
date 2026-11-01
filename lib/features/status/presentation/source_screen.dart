// lib/features/status/presentation/source_screen.dart
//
// One WhatsApp source (WhatsApp or WhatsApp Business): its statuses grouped by day, with a media-type
// filter, multi-select save, pull-to-refresh and the "Missing a status?" help. The two sources never
// share a screen state: everything here is keyed by [StatusApp].
//
// Statuses are grouped by day, not by contact, because the status folder carries no contact data
// (see status_grouping.dart).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/tokens.dart';
import '../../../core/design/waz_theme.dart';
import '../../../core/di/providers.dart';
import '../../../core/error/app_error.dart';
import '../../../core/router/app_router.dart';
import '../../../core/widgets/design_components.dart';
import '../../../core/widgets/media_tile.dart';
import '../../../core/widgets/state_widgets.dart';
import '../../library/domain/library_models.dart';
import '../../library/presentation/library_actions.dart';
import '../../permissions/domain/access_models.dart';
import '../../permissions/presentation/widgets/access_card.dart';
import '../domain/status_grouping.dart';
import '../domain/status_models.dart';
import 'status_providers.dart';
import 'widgets/missing_status_help.dart';

class SourceScreen extends ConsumerStatefulWidget {
  const SourceScreen({super.key, required this.app});

  final StatusApp app;

  @override
  ConsumerState<SourceScreen> createState() => _SourceScreenState();
}

class _SourceScreenState extends ConsumerState<SourceScreen> with WidgetsBindingObserver {
  final Set<String> _selected = {};
  bool get _selecting => _selected.isNotEmpty;
  StatusApp get app => widget.app;

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

  /// Re-detect the app and re-check its folder when the user returns (from WhatsApp, Settings, ...).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _recheck();
  }

  void _recheck() {
    ref.invalidate(installedAppsProvider);
    ref.invalidate(statusAccessProvider(app));
    ref.invalidate(statusFolderStateProvider(app));
    ref.invalidate(statusListProvider(app));
  }

  List<StatusItem> get _items => ref.read(statusListProvider(app)).value ?? const [];

  Future<void> _saveSelected() async {
    final items = _items.where((e) => _selected.contains(e.uri)).toList();
    setState(_selected.clear);
    await saveStatusesFlow(context, ref, items, onViewSaved: () => context.go(AppRoutes.saved));
  }

  Future<void> _openWhatsApp() async {
    final opened = await ref.read(statusAccessServiceProvider).openApp(app);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('Could not open ${app.label}.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final installed = ref.watch(installedAppsProvider).value;
    final folder = ref.watch(statusFolderStateProvider(app));
    return PopScope(
      canPop: !_selecting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _selecting) setState(_selected.clear);
      },
      child: Scaffold(
        appBar: _selecting ? _selectionBar() : _bar(installed?[app] == true),
        body: installed != null && installed[app] != true
            ? _NotInstalled(app: app)
            : folder.when(
                loading: () => const SkeletonGridLoader(),
                error: (_, _) => ErrorState(message: 'Could not check folder access.', onRetry: _recheck),
                data: (state) => state == StatusFolderState.granted ? _body() : _AccessProblem(app: app, state: state),
              ),
      ),
    );
  }

  PreferredSizeWidget _bar(bool installed) => AppBar(
    title: Text(app.label),
    actions: [
      IconButton(tooltip: 'Check again', icon: const Icon(Icons.refresh), onPressed: _recheck),
      if (installed)
        IconButton(tooltip: 'Open ${app.label}', icon: const Icon(Icons.open_in_new), onPressed: _openWhatsApp),
    ],
  );

  PreferredSizeWidget _selectionBar() => AppBar(
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
        onPressed: () => setState(() => _selected.addAll(_visibleItems().map((e) => e.uri))),
      ),
      IconButton(tooltip: 'Save selected', icon: const Icon(Icons.download_rounded), onPressed: _saveSelected),
    ],
  );

  List<StatusItem> _visibleItems() {
    final kind = ref.read(statusKindFilterProvider);
    return [
      for (final i in _items)
        if (kind == null || i.kind == kind) i,
    ];
  }

  Widget _body() {
    final list = ref.watch(statusListProvider(app));
    final kind = ref.watch(statusKindFilterProvider);
    return list.when(
      loading: () => const SkeletonGridLoader(),
      error: (e, _) {
        final noAccess = e is MediaAccessError && e.failure == MediaFailure.noAccess;
        return ErrorState(
          message: e is AppError ? e.message : 'Could not load statuses.',
          onRetry: _recheck,
          retryLabel: noAccess ? 'Check access' : 'Retry',
        );
      },
      data: (items) {
        final groups = groupStatusesByDay(items, DateTime.now(), kind: kind);
        final savedKeys = ref.watch(savedSourceKeysProvider).value ?? const <String>{};
        final photos = items.where((i) => i.kind == MediaKind.image).length;
        final videos = items.length - photos;
        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(statusListProvider(app));
            await ref.read(statusListProvider(app).future);
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _FilterRow(app: app, all: items.length, photos: photos, videos: videos)),
              if (groups.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.xl, AppSpacing.lg, AppSpacing.md),
                    child: Column(
                      children: [
                        Icon(Icons.hourglass_empty, size: 48, color: Theme.of(context).colorScheme.outline),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          items.isEmpty ? 'No statuses available yet' : 'No ${kind == MediaKind.video ? 'videos' : 'photos'}',
                          style: AppTextStyles.titleMedium,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          items.isEmpty
                              ? '${app.label} has not saved any status media to its folder right now.'
                              : 'Try another filter.',
                          style: AppTextStyles.bodyMedium.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              for (final g in groups) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.sm),
                    child: SectionTitle(g.label, subtitle: g.items.length == 1 ? '1 status' : '${g.items.length} statuses'),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  sliver: SliverGrid.builder(
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 140,
                      mainAxisSpacing: AppSpacing.sm,
                      crossAxisSpacing: AppSpacing.sm,
                    ),
                    itemCount: g.items.length,
                    itemBuilder: (context, i) => _tile(g.items[i], savedKeys),
                  ),
                ),
              ],
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: MissingStatusHelp(app: app, onCheckAgain: _recheck, onOpenApp: _openWhatsApp),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _tile(StatusItem item, Set<String> savedKeys) {
    final isSaved = savedKeys.contains(item.sourceKey);
    return MediaTile(
      semanticLabel: '${item.kind.name} status, ${isSaved ? 'already saved' : 'not saved'}',
      isVideo: item.kind == MediaKind.video,
      selectionMode: _selecting,
      selected: _selected.contains(item.uri),
      saved: isSaved,
      onTap: () {
        if (_selecting) {
          setState(() => _selected.contains(item.uri) ? _selected.remove(item.uri) : _selected.add(item.uri));
        } else {
          context.push(AppRoutes.statusPreview, extra: item);
        }
      },
      onLongPress: () => setState(() => _selected.add(item.uri)),
      trailingAction: isSaved
          ? null
          : IconButton.filledTonal(
              tooltip: 'Save',
              iconSize: 20,
              icon: const Icon(Icons.download_rounded),
              onPressed: () => saveStatusesFlow(context, ref, [item], onViewSaved: () => context.go(AppRoutes.saved)),
            ),
      child: StatusThumb(item: item),
    );
  }
}

class _FilterRow extends ConsumerWidget {
  const _FilterRow({required this.app, required this.all, required this.photos, required this.videos});
  final StatusApp app;
  final int all;
  final int photos;
  final int videos;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kind = ref.watch(statusKindFilterProvider);
    Widget chip(String label, MediaKind? value, int count) => ChoiceChip(
      label: Text('$label · $count'),
      selected: kind == value,
      onSelected: (_) => ref.read(statusKindFilterProvider.notifier).set(value),
    );
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      child: Row(
        children: [
          chip('All', null, all),
          const SizedBox(width: AppSpacing.sm),
          chip('Photos', MediaKind.image, photos),
          const SizedBox(width: AppSpacing.sm),
          chip('Videos', MediaKind.video, videos),
        ],
      ),
    );
  }
}

/// Thumbnail of a status (cached, decoded natively).
class StatusThumb extends ConsumerWidget {
  const StatusThumb({super.key, required this.item});
  final StatusItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final thumb = ref.watch(statusThumbnailProvider(item));
    return thumb.when(
      data: (bytes) => bytes == null
          ? const Center(child: Icon(Icons.broken_image_outlined))
          : Image.memory(
              bytes,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              excludeFromSemantics: true,
              errorBuilder: (_, _, _) => const Center(child: Icon(Icons.broken_image_outlined)),
            ),
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const Center(child: Icon(Icons.broken_image_outlined)),
    );
  }
}

/// Folder-access problem, explained separately from "status not downloaded yet".
class _AccessProblem extends ConsumerWidget {
  const _AccessProblem({required this.app, required this.state});
  final StatusApp app;
  final StatusFolderState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final item = AccessItem.forStatusApp(app);
    final status = switch (state) {
      StatusFolderState.notConfigured => AccessStatus.notRequested,
      StatusFolderState.revoked => AccessStatus.revoked,
      StatusFolderState.folderMissing => AccessStatus.folderMissing,
      StatusFolderState.granted => AccessStatus.granted,
    };
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      children: [
        Entrance(child: AccessCard(snapshot: AccessSnapshot(item, status))),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Text(
            'This is about permission to read ${app.label}\'s status folder. It is separate from statuses that '
            '${app.label} has not downloaded yet.',
            style: AppTextStyles.bodySmall.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}

class _NotInstalled extends ConsumerWidget {
  const _NotInstalled({required this.app});
  final StatusApp app;

  @override
  Widget build(BuildContext context, WidgetRef ref) => EmptyState(
    icon: Icons.apps_outlined,
    title: '${app.label} is not installed',
    body: 'Install ${app.label} to browse its statuses here.',
    action: FilledButton(onPressed: () => context.go(AppRoutes.home), child: const Text('Back to Home')),
  );
}

/// Hero accent of a source, shared by Home cards and this screen.
Gradient sourceGradient(BuildContext context, StatusApp app) =>
    app == StatusApp.business ? context.waz.heroGradientAlt : context.waz.heroGradient;
