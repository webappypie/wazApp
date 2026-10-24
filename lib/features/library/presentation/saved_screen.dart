// lib/features/library/presentation/saved_screen.dart
//
// The local library: filter chips, search, multi-select and bulk actions.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/database/app_database.dart';
import '../../../core/design/tokens.dart';
import '../../../core/di/providers.dart';
import '../../../core/router/app_router.dart';
import '../../../core/widgets/media_tile.dart';
import '../../../core/widgets/state_widgets.dart';
import '../domain/library_models.dart';
import 'library_actions.dart';
import 'library_providers.dart';

class SavedScreen extends ConsumerStatefulWidget {
  const SavedScreen({super.key});

  @override
  ConsumerState<SavedScreen> createState() => _SavedScreenState();
}

class _SavedScreenState extends ConsumerState<SavedScreen> {
  final Set<String> _selected = {};
  bool _searching = false;
  final _search = TextEditingController();

  bool get _selecting => _selected.isNotEmpty;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<SavedMedia> _selectedItems() {
    final all = ref.read(libraryItemsProvider).value ?? const <SavedMedia>[];
    return all.where((m) => _selected.contains(m.id)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final visible = ref.watch(visibleLibraryProvider);
    final all = ref.watch(libraryItemsProvider).value ?? const <SavedMedia>[];
    final filter = ref.watch(libraryFilterProvider);

    return PopScope(
      canPop: !_selecting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _selecting) setState(_selected.clear);
      },
      child: Scaffold(
        appBar: _selecting ? _selectionBar() : _normalBar(),
        body: Column(
          children: [
            SizedBox(
              height: 52,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                children: [
                  for (final f in LibraryFilter.values)
                    Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.sm),
                      child: ChoiceChip(
                        label: Text(f.label),
                        selected: filter == f,
                        onSelected: (_) => ref.read(libraryFilterProvider.notifier).set(f),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: visible.when(
                loading: () => const SkeletonGridLoader(),
                error: (e, _) => ErrorState(
                  message: 'Could not load your library.',
                  onRetry: () => ref.invalidate(libraryItemsProvider),
                ),
                data: (items) {
                  if (items.isEmpty) return _empty(all.isEmpty, filter);
                  return GridView.builder(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 140,
                      mainAxisSpacing: AppSpacing.sm,
                      crossAxisSpacing: AppSpacing.sm,
                    ),
                    itemCount: items.length,
                    itemBuilder: (context, i) => _tile(items, i),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _normalBar() {
    return AppBar(
      title: _searching
          ? TextField(
              controller: _search,
              autofocus: true,
              decoration: const InputDecoration(hintText: 'Search saved items', border: InputBorder.none, filled: false),
              onChanged: (q) => ref.read(libraryQueryProvider.notifier).set(q),
            )
          : const Text('Saved'),
      actions: [
        IconButton(
          tooltip: _searching ? 'Close search' : 'Search',
          icon: Icon(_searching ? Icons.close : Icons.search),
          onPressed: () {
            setState(() => _searching = !_searching);
            if (!_searching) {
              _search.clear();
              ref.read(libraryQueryProvider.notifier).set('');
            }
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
    final items = _selectedItems();
    final allFav = items.isNotEmpty && items.every((m) => m.isFavourite);
    final supportsGallery = ref.read(statusAccessServiceProvider).isSupported;
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
          onPressed: () {
            final visible = ref.read(visibleLibraryProvider).value ?? const <SavedMedia>[];
            setState(() => _selected.addAll(visible.map((m) => m.id)));
          },
        ),
        IconButton(
          tooltip: allFav ? 'Remove from favourites' : 'Add to favourites',
          icon: Icon(allFav ? Icons.favorite : Icons.favorite_border),
          onPressed: () async {
            await ref.read(libraryServiceProvider).setFavourite(_selected, !allFav);
            if (mounted) setState(_selected.clear);
          },
        ),
        IconButton(
          tooltip: 'Share',
          icon: const Icon(Icons.share_outlined),
          onPressed: () => shareMedia(context, items),
        ),
        PopupMenuButton<String>(
          tooltip: 'More actions',
          onSelected: (v) async {
            if (v == 'gallery') {
              await exportFlow(context, ref, items);
            } else if (v == 'private') {
              final r = await moveToPrivateFlow(context, ref, _selected.toList());
              if (r != null && mounted) setState(_selected.clear);
            } else if (v == 'delete') {
              final r = await deleteFlow(context, ref, _selected.toList());
              if (r != null && mounted) setState(_selected.clear);
            }
          },
          itemBuilder: (_) => [
            if (supportsGallery) const PopupMenuItem(value: 'gallery', child: Text('Save to gallery')),
            const PopupMenuItem(value: 'private', child: Text('Move to Private Folder')),
            const PopupMenuItem(value: 'delete', child: Text('Delete…')),
          ],
        ),
      ],
    );
  }

  Widget _tile(List<SavedMedia> items, int i) {
    final m = items[i];
    final selecting = _selecting;
    return MediaTile(
      semanticLabel: '${m.kind} ${m.fileName}${m.isFavourite ? ', favourite' : ''}',
      isVideo: m.isVideo,
      duration: m.isVideo ? m.duration : null,
      favourite: m.isFavourite,
      selectionMode: selecting,
      selected: _selected.contains(m.id),
      onTap: () {
        if (selecting) {
          setState(() => _selected.contains(m.id) ? _selected.remove(m.id) : _selected.add(m.id));
        } else {
          context.push(AppRoutes.viewer, extra: ViewerArgs(ids: [for (final x in items) x.id], index: i));
        }
      },
      onLongPress: () => setState(() => _selected.add(m.id)),
      child: SavedThumb(media: m),
    );
  }

  Widget _empty(bool libraryEmpty, LibraryFilter filter) {
    if (libraryEmpty) {
      return EmptyState(
        icon: Icons.photo_library_outlined,
        title: 'Nothing saved yet',
        body: 'Statuses you save and media you import show up here.',
        action: OutlinedButton.icon(
          icon: const Icon(Icons.add_photo_alternate_outlined),
          label: const Text('Import'),
          onPressed: () => showImportSheet(context, ref),
        ),
      );
    }
    return EmptyState(
      icon: Icons.search_off,
      title: 'No matches',
      body: filter == LibraryFilter.all
          ? 'Nothing matches your search.'
          : 'Nothing in "${filter.label}" matches yet.',
    );
  }
}

/// Arguments for the full-screen viewer route.
class ViewerArgs {
  const ViewerArgs({required this.ids, required this.index});
  final List<String> ids;
  final int index;
}

/// Thumbnail for a library item. Images are decoded at a bounded size.
class SavedThumb extends StatelessWidget {
  const SavedThumb({super.key, required this.media});
  final SavedMedia media;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget broken() => Center(child: Icon(Icons.broken_image_outlined, color: scheme.onSurfaceVariant));
    if (media.isVideo) {
      final t = media.thumbnailPath;
      if (t == null) return Center(child: Icon(Icons.videocam_outlined, color: scheme.onSurfaceVariant));
      return Image.file(File(t),
          fit: BoxFit.cover, cacheWidth: 360, excludeFromSemantics: true, errorBuilder: (_, _, _) => broken());
    }
    return Image.file(File(media.path),
        fit: BoxFit.cover, cacheWidth: 360, excludeFromSemantics: true, errorBuilder: (_, _, _) => broken());
  }
}
