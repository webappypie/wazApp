// lib/features/clean/presentation/category_screen.dart
//
// Generic CategoryScreen widget (REQ-CLN-01).
// Configurable for any category: data source, sort options, filter options,
// grid/list toggle, multi-select, live running total, preview, and BottomActionBar.

import 'package:flutter/material.dart';

import '../../../core/design/tokens.dart';
import '../../../core/widgets/action_widgets.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/filter_chip.dart';
import '../../../core/widgets/media_tiles.dart';
import '../../../core/widgets/partial_access_banner.dart';
import '../../../core/widgets/state_widgets.dart';
import '../domain/category_data_source.dart';
import '../domain/category_models.dart';
import 'media_preview_sheet.dart';

class CategoryScreen extends StatefulWidget {
  const CategoryScreen({
    super.key,
    required this.title,
    required this.dataSource,
    this.sortOptions = CategorySortOption.defaultOptions,
    this.filterOptions,
    this.initialViewMode = CategoryViewMode.grid,
    this.onMove,
    this.onCopy,
    this.onProtect,
    this.onDelete,
    this.emptyTitle = 'No media found',
    this.emptyBody = 'Your library in this category is clean.',
  });

  final String title;
  final CategoryDataSource dataSource;
  final List<CategorySortOption> sortOptions;
  final List<CategoryFilterOption>? filterOptions;
  final CategoryViewMode initialViewMode;
  final void Function(List<CategoryItem> items)? onMove;
  final void Function(List<CategoryItem> items)? onCopy;
  final void Function(List<CategoryItem> items)? onProtect;
  final void Function(List<CategoryItem> items)? onDelete;
  final String emptyTitle;
  final String emptyBody;

  @override
  State<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen> {
  late CategoryViewMode _viewMode;
  late CategorySortOption _activeSort;
  late List<CategoryFilterOption> _filters;
  int _selectedFilterIndex = 0;

  bool _isLoading = true;
  String? _errorMessage;
  List<CategoryItem> _allItems = [];
  final Set<String> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    _viewMode = widget.initialViewMode;
    _activeSort = widget.sortOptions.isNotEmpty
        ? widget.sortOptions.first
        : CategorySortOption.defaultOptions.first;

    _filters = widget.filterOptions ?? _createDefaultFilters();
    _loadItems();
  }

  List<CategoryFilterOption> _createDefaultFilters() {
    return [
      CategoryFilterOption(
        label: 'All',
        predicate: (_) => true,
      ),
      CategoryFilterOption(
        label: 'Images',
        predicate: (item) => item.isImage,
      ),
      CategoryFilterOption(
        label: 'Videos',
        predicate: (item) => item.isVideo,
      ),
      CategoryFilterOption(
        label: 'Audio',
        predicate: (item) => item.isAudio,
      ),
    ];
  }

  Future<void> _loadItems() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final items = await widget.dataSource.getItems();
      if (!mounted) return;
      setState(() {
        _allItems = List<CategoryItem>.from(items);
        _isLoading = false;
        // Clean up any stale selections
        final validIds = items.map((e) => e.id).toSet();
        _selectedIds.removeWhere((id) => !validIds.contains(id));
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  // ---------------------------------------------------------------------------
  // Sorting and Filtering
  // ---------------------------------------------------------------------------

  List<CategoryItem> get _filteredAndSortedItems {
    final activeFilter = _filters[_selectedFilterIndex];
    final filtered = _allItems.where(activeFilter.predicate).toList();

    filtered.sort((a, b) {
      int cmp;
      switch (_activeSort.key) {
        case CategorySortKey.dateModified:
          cmp = a.dateModifiedSec.compareTo(b.dateModifiedSec);
        case CategorySortKey.size:
          cmp = a.sizeBytes.compareTo(b.sizeBytes);
        case CategorySortKey.name:
          cmp = a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
      }
      return _activeSort.direction == SortDirection.ascending ? cmp : -cmp;
    });

    return filtered;
  }

  List<CategoryItem> get _selectedItems {
    return _allItems.where((item) => _selectedIds.contains(item.id)).toList();
  }

  int get _selectedBytes {
    return _selectedItems.fold(0, (sum, item) => sum + item.sizeBytes);
  }

  // ---------------------------------------------------------------------------
  // Multi-select actions
  // ---------------------------------------------------------------------------

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _toggleSelectAll() {
    final visibleItems = _filteredAndSortedItems;
    final visibleIds = visibleItems.map((e) => e.id).toSet();

    setState(() {
      final allVisibleSelected = visibleIds.every(_selectedIds.contains);
      if (allVisibleSelected) {
        _selectedIds.removeAll(visibleIds);
      } else {
        _selectedIds.addAll(visibleIds);
      }
    });
  }

  void _handleItemTap(CategoryItem item) {
    if (_selectedIds.contains(item.id)) {
      // Tapping a selected item deselects it
      _toggleSelection(item.id);
    } else {
      // REQ-CLN-01 / Task 3: Tapping an unselected item opens full preview
      _openPreview(item);
    }
  }

  void _openPreview(CategoryItem item) {
    MediaPreviewSheet.show(
      context,
      item: item,
      isSelected: _selectedIds.contains(item.id),
      onToggleSelection: () => _toggleSelection(item.id),
    );
  }

  // ---------------------------------------------------------------------------
  // Bottom action bar handlers
  // ---------------------------------------------------------------------------

  void _handleMove() {
    final selected = _selectedItems;
    if (selected.isEmpty) return;
    widget.onMove?.call(selected);
  }

  void _handleCopy() {
    final selected = _selectedItems;
    if (selected.isEmpty) return;
    widget.onCopy?.call(selected);
  }

  void _handleProtect() {
    final selected = _selectedItems;
    if (selected.isEmpty) return;
    widget.onProtect?.call(selected);
  }

  Future<void> _handleDelete() async {
    final selected = _selectedItems;
    if (selected.isEmpty) return;

    final confirmed = await ConfirmationSheet.show(
      context,
      title: 'Delete ${selected.length} items?',
      body: 'These files will be moved to the Recycle Bin.',
      confirmLabel: 'Delete',
      isDestructive: true,
    );

    if (confirmed == true && mounted) {
      widget.onDelete?.call(selected);
      setState(() {
        final deletedIds = selected.map((e) => e.id).toSet();
        _allItems.removeWhere((item) => deletedIds.contains(item.id));
        _selectedIds.removeAll(deletedIds);
      });
    }
  }

  void _showSortSheet() {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.bottomSheetRadius),
      builder: (ctx) {
        final scheme = Theme.of(ctx).colorScheme;
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.pagePadding,
                    vertical: AppSpacing.xs,
                  ),
                  child: Text(
                    'Sort by',
                    style: AppTextStyles.titleMedium.copyWith(color: scheme.onSurface),
                  ),
                ),
                const Divider(),
                for (final option in widget.sortOptions)
                  ListTile(
                    title: Text(option.label, style: AppTextStyles.bodyMedium),
                    trailing: _activeSort == option
                        ? Icon(Icons.check, color: scheme.primary)
                        : null,
                    onTap: () {
                      setState(() => _activeSort = option);
                      Navigator.of(ctx).pop();
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final visibleItems = _filteredAndSortedItems;
    final hasVisible = visibleItems.isNotEmpty;
    final allVisibleSelected = hasVisible && visibleItems.every((e) => _selectedIds.contains(e.id));
    final count = _selectedIds.length;
    final runningSizeLabel = count > 0 ? '$count items • ${formatBytes(_selectedBytes)}' : '';
    final allSelectedProtected =
        _selectedItems.isNotEmpty && _selectedItems.every((e) => e.isProtected);

    return AppScaffold(
      appBar: AppBar(
        title: Text(widget.title),
        centerTitle: false,
        actions: [
          // Sort button
          IconButton(
            icon: const Icon(Icons.sort_rounded),
            tooltip: 'Sort items',
            onPressed: _showSortSheet,
          ),
          // View mode toggle
          IconButton(
            icon: Icon(
              _viewMode == CategoryViewMode.grid
                  ? Icons.view_list_rounded
                  : Icons.grid_view_rounded,
            ),
            tooltip: _viewMode == CategoryViewMode.grid ? 'List view' : 'Grid view',
            onPressed: () {
              setState(() {
                _viewMode = _viewMode == CategoryViewMode.grid
                    ? CategoryViewMode.list
                    : CategoryViewMode.grid;
              });
            },
          ),
          // Select all / Deselect all
          IconButton(
            icon: Icon(
              allVisibleSelected ? Icons.deselect_rounded : Icons.select_all_rounded,
            ),
            tooltip: allVisibleSelected ? 'Deselect all' : 'Select all',
            onPressed: hasVisible ? _toggleSelectAll : null,
          ),
        ],
      ),
      bottomNavigationBar: BottomActionBar(
        selectionCount: count,
        selectionSizeLabel: runningSizeLabel,
        onMove: _handleMove,
        onCopy: _handleCopy,
        onProtect: _handleProtect,
        onDelete: _handleDelete,
        isProtected: allSelectedProtected,
      ),
      body: Column(
        children: [
          const PartialAccessBanner(),
          // Filter chip row
          if (_filters.length > 1)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs, bottom: AppSpacing.xs),
              child: FilterChipRow(
                options: _filters.map((f) => f.label).toList(),
                selectedIndex: _selectedFilterIndex,
                onSelected: (index) {
                  setState(() => _selectedFilterIndex = index);
                },
              ),
            ),
          // Content
          Expanded(
            child: _buildContent(visibleItems, scheme),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(List<CategoryItem> items, ColorScheme scheme) {
    if (_isLoading) {
      return _viewMode == CategoryViewMode.grid
          ? const SkeletonGridLoader()
          : const SkeletonListLoader();
    }

    if (_errorMessage != null) {
      return ErrorState(
        message: 'Failed to load items.\n$_errorMessage',
        onRetry: _loadItems,
      );
    }

    if (items.isEmpty) {
      return EmptyState(
        title: widget.emptyTitle,
        body: widget.emptyBody,
        icon: Icons.photo_library_outlined,
      );
    }

    return _viewMode == CategoryViewMode.grid
        ? _buildGridView(items)
        : _buildListView(items);
  }

  Widget _buildGridView(List<CategoryItem> items) {
    return GridView.builder(
      padding: const EdgeInsets.all(AppSpacing.pagePadding),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: AppSpacing.sm,
        mainAxisSpacing: AppSpacing.sm,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final isSelected = _selectedIds.contains(item.id);

        return MediaTile(
          thumbnailProvider: item.safeThumbnail,
          isSelected: isSelected,
          isVideo: item.isVideo,
          durationLabel: item.formattedDuration,
          isProtected: item.isProtected,
          onTap: () => _handleItemTap(item),
          onLongPress: () => _toggleSelection(item.id),
        );
      },
    );
  }

  Widget _buildListView(List<CategoryItem> items) {
    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final isSelected = _selectedIds.contains(item.id);
        final subtitle = '${item.formattedSize} • ${item.bucketName}';

        return MediaListRow(
          thumbnailProvider: item.safeThumbnail,
          title: item.displayName,
          subtitle: subtitle,
          isSelected: isSelected,
          isProtected: item.isProtected,
          onTap: () => _handleItemTap(item),
          onLongPress: () => _toggleSelection(item.id),
        );
      },
    );
  }
}
