// lib/features/search/presentation/search_screen.dart
//
// Global search screen supporting cross-app media discovery (REQ-11).
// Allows search by filename, bucket/chat, MIME type with source and media-type filters.

import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/design/tokens.dart';
import '../../../core/di/providers.dart';
import '../../../core/services/installed_apps/installed_apps_service.dart';
import '../../../core/widgets/action_widgets.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/media_tiles.dart';
import '../../../core/widgets/search_field.dart';
import '../../../core/widgets/source_filter_bar.dart';
import '../../../core/widgets/state_widgets.dart';
import '../../clean/data/media_action_coordinator.dart';
import '../../clean/domain/category_models.dart';

enum MediaTypeFilter {
  all('All'),
  images('Images'),
  videos('Videos'),
  audio('Audio'),
  documents('Documents');

  const MediaTypeFilter(this.label);
  final String label;
}

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _searchController = TextEditingController();
  MediaTypeFilter _typeFilter = MediaTypeFilter.all;
  final Set<String> _selectedIds = {};
  List<CategoryItem> _results = [];
  bool _isLoading = false;
  bool _hasSearched = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _performSearch();
  }

  Future<void> _performSearch() async {
    final query = _searchController.text.trim();
    final sourceFilter = ref.read(activeSourceFilterProvider);
    final db = ref.read(appDatabaseProvider);

    if (query.isEmpty) {
      setState(() {
        _results = [];
        _hasSearched = false;
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _hasSearched = true;
    });

    try {
      var queryExpr = db.mediaItems.displayName.like('%$query%') |
          db.mediaItems.bucketName.like('%$query%') |
          db.mediaItems.mimeType.like('%$query%');

      // Filter by source
      if (sourceFilter == MediaSourceFilter.whatsApp) {
        queryExpr = queryExpr & db.mediaItems.sourceApp.equals('com.whatsapp');
      } else if (sourceFilter == MediaSourceFilter.whatsAppBusiness) {
        queryExpr = queryExpr & db.mediaItems.sourceApp.equals('com.whatsapp.w4b');
      }

      // Filter by media type
      switch (_typeFilter) {
        case MediaTypeFilter.images:
          queryExpr = queryExpr & db.mediaItems.mimeType.like('image/%');
          break;
        case MediaTypeFilter.videos:
          queryExpr = queryExpr & db.mediaItems.mimeType.like('video/%');
          break;
        case MediaTypeFilter.audio:
          queryExpr = queryExpr & db.mediaItems.mimeType.like('audio/%');
          break;
        case MediaTypeFilter.documents:
          queryExpr = queryExpr &
              (db.mediaItems.mimeType.like('application/%') |
                  db.mediaItems.mimeType.like('text/%') |
                  (db.mediaItems.mimeType.like('image/%').not() &
                      db.mediaItems.mimeType.like('video/%').not() &
                      db.mediaItems.mimeType.like('audio/%').not()));
          break;
        case MediaTypeFilter.all:
          break;
      }

      final rows = await (db.select(db.mediaItems)
            ..where((tbl) => queryExpr)
            ..orderBy([(t) => OrderingTerm.desc(t.dateModifiedSec)])
            ..limit(100))
          .get();

      final items = rows
          .map((r) => CategoryItem(
                id: r.id.toString(),
                contentUri: r.contentUri,
                displayName: r.displayName,
                mimeType: r.mimeType,
                sizeBytes: r.sizeBytes,
                dateAddedSec: r.dateAddedSec,
                dateModifiedSec: r.dateModifiedSec,
                bucketName: r.bucketName,
                sourceApp: r.sourceApp,
                width: r.width,
                height: r.height,
                durationMs: r.durationMs,
                isProtected: r.isProtected,
              ))
          .toList();

      if (mounted) {
        setState(() {
          _results = items;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _selectAll() {
    setState(() {
      if (_selectedIds.length == _results.length) {
        _selectedIds.clear();
      } else {
        _selectedIds.addAll(_results.map((e) => e.id));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final installed = ref.watch(installedSourcesProvider).asData?.value ??
        InstalledSources.neither;

    // Listen to source filter changes to re-run search
    ref.listen<MediaSourceFilter>(activeSourceFilterProvider, (_, __) {
      _performSearch();
    });

    final selectedItems =
        _results.where((item) => _selectedIds.contains(item.id)).toList();
    final selectedBytes =
        selectedItems.fold<int>(0, (sum, item) => sum + item.sizeBytes);

    return AppScaffold(
      appBar: AppBar(
        title: const Text('Search Media'),
        actions: [
          if (_results.isNotEmpty)
            TextButton(
              onPressed: _selectAll,
              child: Text(_selectedIds.length == _results.length
                  ? 'Deselect All'
                  : 'Select All'),
            ),
        ],
      ),
      bottomNavigationBar: _selectedIds.isNotEmpty
          ? BottomActionBar(
              selectionCount: _selectedIds.length,
              selectionSizeLabel:
                  '${_selectedIds.length} items • ${formatBytes(selectedBytes)}',
              onDelete: () => _handleDelete(selectedItems),
              onMove: () => _handleMove(selectedItems),
              onProtect: () => _handleProtect(selectedItems),
            )
          : null,
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.pagePadding,
              AppSpacing.sm,
              AppSpacing.pagePadding,
              AppSpacing.xs,
            ),
            child: SearchField(
              controller: _searchController,
              autofocus: true,
              placeholder: 'Search files, chats, document types…',
            ),
          ),

          // Source Filter Bar (auto-hides when only 1 source)
          if (installed.hasBoth)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.pagePadding),
              child: SourceFilterBar(),
            ),

          // Media Type Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.pagePadding,
              vertical: AppSpacing.xs,
            ),
            child: Row(
              children: MediaTypeFilter.values.map((type) {
                final isSelected = _typeFilter == type;
                return Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.xs),
                  child: FilterChip(
                    label: Text(type.label),
                    selected: isSelected,
                    onSelected: (_) {
                      setState(() {
                        _typeFilter = type;
                      });
                      _performSearch();
                    },
                  ),
                );
              }).toList(),
            ),
          ),

          const Divider(height: 1),

          // Results / States
          Expanded(
            child: _buildBody(scheme),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(ColorScheme scheme) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!_hasSearched) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_rounded, size: 64, color: scheme.outlineVariant),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Search your WhatsApp & Business media',
              style: AppTextStyles.titleMedium.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Search by file name, chat/folder, or document extension',
              style: AppTextStyles.bodySmall.copyWith(color: scheme.outline),
            ),
          ],
        ),
      );
    }

    if (_results.isEmpty) {
      return EmptyState(
        title: 'No media matches found',
        body: 'Try searching with different keywords or changing source/type filters.',
        icon: Icons.find_in_page_outlined,
      );
    }

    return ListView.builder(
      itemCount: _results.length,
      itemBuilder: (context, index) {
        final item = _results[index];
        final isSelected = _selectedIds.contains(item.id);

        return MediaListRow(
          thumbnailProvider: item.safeThumbnail,
          title: item.displayName,
          subtitle: '${item.bucketName.isNotEmpty ? "${item.bucketName} • " : ""}${formatBytes(item.sizeBytes)}',
          sourceApp: item.sourceApp,
          isSelected: isSelected,
          isProtected: item.isProtected,
          onTap: () => _toggleSelection(item.id),
          onLongPress: () => _toggleSelection(item.id),
        );
      },
    );
  }

  Future<void> _handleDelete(List<CategoryItem> items) async {
    final confirmed = await ConfirmationSheet.show(
      context,
      title: 'Move to Recycle Bin?',
      body: 'Items can be safely restored to their respective apps within 30 days.',
      confirmLabel: 'Move to Bin',
      isDestructive: true,
    );

    if (confirmed == true && mounted) {
      final coordinator = ref.read(mediaActionCoordinatorProvider);
      await coordinator.trashSelected(items);
      _selectedIds.clear();
      _performSearch();
    }
  }

  Future<void> _handleMove(List<CategoryItem> items) async {
    // Show destination folder / organize flow
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Media relocation ready. Select destination in Organize.')),
    );
  }

  Future<void> _handleProtect(List<CategoryItem> items) async {
    final coordinator = ref.read(mediaActionCoordinatorProvider);
    await coordinator.setProtection(items, true);
    _selectedIds.clear();
    _performSearch();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${items.length} items protected from cleanup.')),
      );
    }
  }
}
