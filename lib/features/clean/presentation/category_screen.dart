// lib/features/clean/presentation/category_screen.dart
//
// Generic CategoryScreen widget (REQ-CLN-01).
// Configurable for any category: data source, sort options, filter options,
// grid/list toggle, multi-select, live running total, preview, and BottomActionBar.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/tokens.dart';
import '../../../core/di/providers.dart';
import '../../../core/widgets/action_widgets.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/filter_chip.dart';
import '../../../core/widgets/media_tiles.dart';
import '../../../core/widgets/partial_access_banner.dart';
import '../../../core/widgets/state_widgets.dart';
import '../domain/category_data_source.dart';
import '../domain/category_models.dart';
import 'cleanup_success_screen.dart';
import 'media_preview_sheet.dart';

class CategoryScreen extends ConsumerStatefulWidget {
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
    this.initialSelectedIdsBuilder,
    this.headerBannerBuilder,
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
  final Set<String> Function(List<CategoryItem> items)? initialSelectedIdsBuilder;
  final Widget Function(BuildContext context, List<CategoryItem> allItems, List<CategoryItem> visibleItems)? headerBannerBuilder;
  final String emptyTitle;
  final String emptyBody;

  @override
  ConsumerState<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends ConsumerState<CategoryScreen> {
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
        if (widget.initialSelectedIdsBuilder != null) {
          _selectedIds.addAll(widget.initialSelectedIdsBuilder!(_allItems));
        }
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
        case CategorySortKey.duration:
          cmp = a.durationMs.compareTo(b.durationMs);
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

  Future<void> _handleMove() async {
    final selected = _selectedItems;
    if (selected.isEmpty) return;

    if (widget.onMove != null) {
      widget.onMove!(selected);
      return;
    }

    final action = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.bottomSheetRadius),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.archive_outlined),
                title: const Text('Archive Media'),
                subtitle: const Text('Organize into Media Archive/<year>/<type>'),
                onTap: () => Navigator.of(ctx).pop('archive'),
              ),
              ListTile(
                leading: const Icon(Icons.drive_file_move_outlined),
                title: const Text('Move to Organized Folder'),
                subtitle: const Text('Move to Pictures/WappTidy Organized'),
                onTap: () => Navigator.of(ctx).pop('move'),
              ),
            ],
          ),
        );
      },
    );

    if (action == null || !mounted) return;

    final coordinator = ref.read(mediaActionCoordinatorProvider);
    final result = await coordinator.moveOrCopySelected(
      items: selected,
      isMove: true,
      isArchive: action == 'archive',
    );

    if (!mounted) return;
    if (result.succeededCount > 0) {
      setState(() {
        final movedIds = result.succeededIds.toSet();
        _allItems.removeWhere((item) => movedIds.contains(item.id));
        _selectedIds.removeAll(movedIds);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Moved ${result.succeededCount} items successfully.')),
      );
    }
    if (result.failedCount > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${result.failedCount} items failed to move.'),
          backgroundColor: kColorDestructive,
        ),
      );
    }
  }

  Future<void> _handleCopy() async {
    final selected = _selectedItems;
    if (selected.isEmpty) return;

    if (widget.onCopy != null) {
      widget.onCopy!(selected);
      return;
    }

    final coordinator = ref.read(mediaActionCoordinatorProvider);
    final result = await coordinator.moveOrCopySelected(
      items: selected,
      isMove: false,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.isSuccess
              ? 'Copied ${result.succeededCount} items to Pictures/WappTidy Organized.'
              : 'Copied ${result.succeededCount} items (${result.failedCount} failed).',
        ),
      ),
    );
  }

  Future<void> _handleProtect() async {
    final selected = _selectedItems;
    if (selected.isEmpty) return;

    if (widget.onProtect != null) {
      widget.onProtect!(selected);
      return;
    }

    final coordinator = ref.read(mediaActionCoordinatorProvider);
    final allProtected = selected.every((item) => item.isProtected);
    final newProtection = !allProtected;

    try {
      await coordinator.setProtection(selected, newProtection);
      if (!mounted) return;
      setState(() {
        final targetIds = selected.map((e) => e.id).toSet();
        _allItems = _allItems.map((item) {
          if (targetIds.contains(item.id)) {
            return CategoryItem(
              id: item.id,
              contentUri: item.contentUri,
              displayName: item.displayName,
              mimeType: item.mimeType,
              sizeBytes: item.sizeBytes,
              dateAddedSec: item.dateAddedSec,
              dateModifiedSec: item.dateModifiedSec,
              bucketName: item.bucketName,
              sourceApp: item.sourceApp,
              width: item.width,
              height: item.height,
              durationMs: item.durationMs,
              isProtected: newProtection,
              badgeLabel: item.badgeLabel,
              groupTitle: item.groupTitle,
              isOriginal: item.isOriginal,
            );
          }
          return item;
        }).toList();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${selected.length} items ${newProtection ? "marked as protected" : "unprotected"}',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating protection: $e')),
      );
    }
  }

  Future<void> _handleDelete() async {
    final selected = _selectedItems;
    if (selected.isEmpty) return;

    // REQ-ACT-05: Protected items require explicit unprotect before deletion
    final hasProtected = selected.any((item) => item.isProtected);
    if (hasProtected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Protected items cannot be deleted. Unprotect first.'),
          backgroundColor: kColorDestructive,
        ),
      );
      return;
    }

    final String title;
    final String body;
    if (widget.onDelete != null) {
      title = 'Delete ${selected.length} items?';
      body = 'These files will be moved to the Recycle Bin.';
    } else {
      int apiLevel = 33;
      final coordinator = ref.read(mediaActionCoordinatorProvider);
      try {
        apiLevel = await coordinator.getAndroidVersion();
      } catch (_) {}

      if (!mounted) return;

      if (apiLevel >= 30) {
        title = 'Move ${selected.length} items to Recycle Bin?';
        body = 'Items in the Recycle Bin are permanently deleted by Android after ~30 days.';
      } else {
        title = 'Permanently delete ${selected.length} items?';
        body = '⚠️ This deletion is permanent! Your device version does not support a Recycle Bin.';
      }
    }

    final confirmed = await ConfirmationSheet.show(
      context,
      title: title,
      body: body,
      confirmLabel: 'Delete',
      isDestructive: true,
    );

    if (confirmed == true && mounted) {
      if (widget.onDelete != null) {
        widget.onDelete!(selected);
        setState(() {
          final deletedIds = selected.map((e) => e.id).toSet();
          _allItems.removeWhere((item) => deletedIds.contains(item.id));
          _selectedIds.removeAll(deletedIds);
        });
      } else {
        try {
          final coordinator = ref.read(mediaActionCoordinatorProvider);
          final summary = await coordinator.trashSelected(selected);
          if (!mounted) return;
          setState(() {
            final deletedIds = selected.map((e) => e.id).toSet();
            _allItems.removeWhere((item) => deletedIds.contains(item.id));
            _selectedIds.removeAll(deletedIds);
          });
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => CleanupSuccessScreen(summary: summary),
            ),
          );
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete items: $e'),
              backgroundColor: kColorDestructive,
            ),
          );
        }
      }
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
          // Header summary banner (if provided by category)
          if (widget.headerBannerBuilder != null)
            widget.headerBannerBuilder!(context, _allItems, visibleItems),
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
        : _buildListView(items, scheme);
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
          badgeLabel: item.badgeLabel,
          onTap: () => _handleItemTap(item),
          onLongPress: () => _toggleSelection(item.id),
        );
      },
    );
  }

  Widget _buildListView(List<CategoryItem> items, ColorScheme scheme) {
    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final isSelected = _selectedIds.contains(item.id);
        final subtitle = '${item.formattedSize} • ${item.bucketName}';
        final isFirstInGroup = item.groupTitle != null &&
            (index == 0 || items[index - 1].groupTitle != item.groupTitle);

        final badge = item.badgeLabel != null
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: item.isOriginal
                      ? kColorSuccess.withValues(alpha: 0.15)
                      : scheme.surfaceContainerHighest,
                  borderRadius: const BorderRadius.all(Radius.circular(4)),
                ),
                child: Text(
                  item.badgeLabel!,
                  style: AppTextStyles.labelSmall.copyWith(
                    color: item.isOriginal ? kColorSuccess : scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              )
            : null;

        final row = MediaListRow(
          thumbnailProvider: item.safeThumbnail,
          title: item.displayName,
          subtitle: subtitle,
          isSelected: isSelected,
          isProtected: item.isProtected,
          trailing: badge,
          onTap: () => _handleItemTap(item),
          onLongPress: () => _toggleSelection(item.id),
        );

        if (isFirstInGroup) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.pagePadding,
                  vertical: AppSpacing.xs,
                ),
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                child: Text(
                  item.groupTitle!,
                  style: AppTextStyles.labelMedium.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              row,
            ],
          );
        }

        return row;
      },
    );
  }
}
