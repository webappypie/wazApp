// lib/features/bin/presentation/bin_screen.dart
//
// Recycle Bin screen (REQ-BIN-01 to REQ-BIN-05):
//   - Lists MediaStore-trashed items grouped: Today / Yesterday / This week / Older.
//   - Shows thumbnail, original location (bucket), size, deletion date.
//   - Multi-select and single-select Restore & Permanent-Delete (REQ-BIN-02).
//   - Restore NEVER requires an ad, purchase, or network (P-05, REQ-BIN-03).
//   - Honest system retention notice (~30 days) (REQ-BIN-05).
//   - Android <= 10 permanent warning (REQ-BIN-04).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/tokens.dart';
import '../../../core/di/providers.dart';
import '../../../core/services/media_access/media_item.dart';
import '../../../core/widgets/action_widgets.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/media_tiles.dart';
import '../../../core/widgets/source_filter_bar.dart';
import '../../../core/widgets/state_widgets.dart';
import '../../clean/domain/category_models.dart';

class BinScreen extends ConsumerStatefulWidget {
  const BinScreen({
    super.key,
    this.initialItemsOverride,
    this.apiLevelOverride,
  });

  final List<MediaItem>? initialItemsOverride;
  final int? apiLevelOverride;

  @override
  ConsumerState<BinScreen> createState() => _BinScreenState();
}

class _BinScreenState extends ConsumerState<BinScreen> {
  bool _isLoading = true;
  int _apiLevel = 33;
  List<CategoryItem> _trashedItems = [];
  final Set<String> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    _loadTrashedItems();
  }

  Future<void> _loadTrashedItems() async {
    setState(() => _isLoading = true);

    try {
      final coordinator = ref.read(mediaActionCoordinatorProvider);
      _apiLevel = widget.apiLevelOverride ?? await coordinator.getAndroidVersion();

      if (widget.initialItemsOverride != null) {
        _trashedItems = widget.initialItemsOverride!.map(_toCategoryItem).toList();
      } else {
        final stream = ref.read(mediaAccessServiceProvider).queryTrashedItems();
        final mediaItems = await stream.first;
        _trashedItems = mediaItems.map(_toCategoryItem).toList();
      }
    } catch (_) {
      _trashedItems = [];
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  CategoryItem _toCategoryItem(MediaItem item) {
    return CategoryItem(
      id: item.mediaId.toString(),
      contentUri: item.contentUri,
      displayName: item.contentUri.split('/').last,
      mimeType: item.mimeType,
      sizeBytes: item.sizeBytes,
      dateAddedSec: item.dateAddedEpochSec,
      dateModifiedSec: item.dateModifiedEpochSec,
      bucketName: item.folderBucket,
      sourceApp: item.source.packageName,
      width: item.width ?? 0,
      height: item.height ?? 0,
      durationMs: item.durationMs ?? 0,
      isProtected: false,
    );
  }

  List<CategoryItem> get _selectedItems =>
      _trashedItems.where((it) => _selectedIds.contains(it.id)).toList();

  int get _selectedBytes =>
      _selectedItems.fold(0, (sum, it) => sum + it.sizeBytes);

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
    setState(() {
      if (_selectedIds.length == _trashedItems.length) {
        _selectedIds.clear();
      } else {
        _selectedIds.addAll(_trashedItems.map((e) => e.id));
      }
    });
  }

  /// Restores selected items without any ad, purchase, or network check (P-05, REQ-BIN-03).
  Future<void> _handleRestore() async {
    final selected = _selectedItems;
    if (selected.isEmpty) return;

    final coordinator = ref.read(mediaActionCoordinatorProvider);
    try {
      final restoredUris = await coordinator.restoreSelected(selected);
      if (!mounted) return;

      setState(() {
        final restoredIds = selected.where((it) => restoredUris.contains(it.contentUri)).map((it) => it.id).toSet();
        _trashedItems.removeWhere((it) => restoredIds.contains(it.id));
        _selectedIds.removeAll(restoredIds);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Restored ${restoredUris.length} items to your library.'),
          backgroundColor: kColorSuccess,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to restore: $e'),
          backgroundColor: kColorDestructive,
        ),
      );
    }
  }

  /// Permanently deletes selected items with explicit irreversible warning (REQ-BIN-02).
  Future<void> _handlePermanentDelete() async {
    final selected = _selectedItems;
    if (selected.isEmpty) return;

    final waCount = selected.where((it) => !it.sourceApp.contains('w4b')).length;
    final bizCount = selected.where((it) => it.sourceApp.contains('w4b')).length;
    final breakdown = (waCount > 0 && bizCount > 0)
        ? '\n\nIncludes: $waCount WhatsApp files and $bizCount Business files.'
        : '';

    final confirmed = await ConfirmationSheet.show(
      context,
      title: 'Permanently delete ${selected.length} items?',
      body: '⚠️ These files will be permanently erased from your device. This action cannot be undone.$breakdown',
      confirmLabel: 'Delete Permanently',
      isDestructive: true,
    );

    if (confirmed == true && mounted) {
      final coordinator = ref.read(mediaActionCoordinatorProvider);
      try {
        await coordinator.deletePermanentlySelected(selected);
        if (!mounted) return;

        setState(() {
          final targetIds = selected.map((it) => it.id).toSet();
          _trashedItems.removeWhere((it) => targetIds.contains(it.id));
          _selectedIds.removeAll(targetIds);
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Permanently deleted ${selected.length} items.'),
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete: $e'),
            backgroundColor: kColorDestructive,
          ),
        );
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Date Grouping (REQ-BIN-01): Today / Yesterday / This week / Older
  // ---------------------------------------------------------------------------

  Map<String, List<CategoryItem>> _groupItemsByDate(List<CategoryItem> items) {
    final now = DateTime.now();
    final todayMidnight = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch ~/ 1000;
    final yesterdayMidnight = todayMidnight - 86400;
    final thisWeekCutoff = todayMidnight - (7 * 86400);

    final groups = <String, List<CategoryItem>>{
      'Today': [],
      'Yesterday': [],
      'This Week': [],
      'Older': [],
    };

    for (final item in items) {
      final mod = item.dateModifiedSec;
      if (mod >= todayMidnight) {
        groups['Today']!.add(item);
      } else if (mod >= yesterdayMidnight) {
        groups['Yesterday']!.add(item);
      } else if (mod >= thisWeekCutoff) {
        groups['This Week']!.add(item);
      } else {
        groups['Older']!.add(item);
      }
    }

    groups.removeWhere((_, list) => list.isEmpty);
    return groups;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final allSelected = _trashedItems.isNotEmpty && _selectedIds.length == _trashedItems.length;
    final count = _selectedIds.length;
    final runningSizeLabel = count > 0 ? '$count items • ${formatBytes(_selectedBytes)}' : '';

    return AppScaffold(
      appBar: AppBar(
        title: const Text('Recycle Bin'),
        actions: [
          if (_trashedItems.isNotEmpty) ...[
            TextButton(
              onPressed: () {
                _selectedIds.clear();
                _selectedIds.addAll(_trashedItems.map((e) => e.id));
                _handlePermanentDelete();
              },
              child: const Text('Empty Bin', style: TextStyle(color: kColorDestructive)),
            ),
            IconButton(
              icon: Icon(allSelected ? Icons.deselect_rounded : Icons.select_all_rounded),
              tooltip: allSelected ? 'Deselect all' : 'Select all',
              onPressed: _toggleSelectAll,
            ),
          ],
        ],
      ),
      bottomNavigationBar: count > 0
          ? SafeArea(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.card(context),
                  border: Border(top: BorderSide(color: scheme.outlineVariant)),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.pagePadding,
                  vertical: AppSpacing.sm,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      runningSizeLabel,
                      style: AppTextStyles.labelMedium.copyWith(color: scheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        Expanded(
                          child: SecondaryButton(
                            label: 'Restore',
                            icon: const Icon(Icons.restore_rounded, size: 20),
                            onPressed: _handleRestore,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: SecondaryButton(
                            label: 'Delete Permanently',
                            icon: const Icon(Icons.delete_forever_rounded, size: 20, color: kColorDestructive),
                            isDestructive: true,
                            onPressed: _handlePermanentDelete,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            )
          : null,
      body: _isLoading
          ? const SkeletonListLoader()
          : _buildBody(scheme),
    );
  }

  Widget _buildBody(ColorScheme scheme) {
    // REQ-BIN-04: Android <= 10 warning
    if (_apiLevel < 30) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.pagePadding),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: scheme.errorContainer.withValues(alpha: 0.5),
                borderRadius: AppRadius.cardRadius,
                border: Border.all(color: scheme.error.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: scheme.error),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Your device (Android 10 or earlier) does not support a Recycle Bin. Deletions on this device are permanent.',
                      style: AppTextStyles.bodyMedium.copyWith(color: scheme.onErrorContainer),
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            const EmptyState(
              title: 'No Recycle Bin',
              body: 'Deleted files are removed immediately on Android 10 and below.',
              icon: Icons.delete_outline,
            ),
            const Spacer(),
          ],
        ),
      );
    }

    if (_trashedItems.isEmpty) {
      return Column(
        children: [
          _buildRetentionBanner(scheme),
          const Expanded(
            child: EmptyState(
              title: 'Recycle Bin is empty',
              body: 'Deleted files are kept in the Recycle Bin for approximately 30 days before being permanently purged by Android.',
              icon: Icons.auto_delete_outlined,
            ),
          ),
        ],
      );
    }

    final sourceFilter = ref.watch(activeSourceFilterProvider);
    final filteredTrashed = _trashedItems.where((it) {
      if (sourceFilter == MediaSourceFilter.whatsApp && it.sourceApp.contains('w4b')) {
        return false;
      }
      if (sourceFilter == MediaSourceFilter.whatsAppBusiness && !it.sourceApp.contains('w4b')) {
        return false;
      }
      return true;
    }).toList();

    final grouped = _groupItemsByDate(filteredTrashed);

    return Column(
      children: [
        _buildRetentionBanner(scheme),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.pagePadding),
          child: SourceFilterBar(),
        ),
        Expanded(
          child: filteredTrashed.isEmpty
              ? const EmptyState(
                  title: 'No items matching filter',
                  body: 'Try selecting a different media source.',
                  icon: Icons.filter_list_off_rounded,
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(AppSpacing.pagePadding),
                  itemCount: grouped.entries.length,
                  itemBuilder: (context, groupIdx) {
                    final entry = grouped.entries.elementAt(groupIdx);
                    final groupName = entry.key;
                    final items = entry.value;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                          child: Text(
                            groupName,
                            style: AppTextStyles.titleMedium.copyWith(
                              fontWeight: FontWeight.bold,
                              color: scheme.primary,
                            ),
                          ),
                        ),
                        ...items.map((item) {
                          final isSelected = _selectedIds.contains(item.id);
                          return Padding(
                            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                            child: MediaListRow(
                              thumbnailProvider: item.thumbnailProvider ?? CategoryItem.defaultPlaceholder,
                              title: item.displayName,
                              subtitle: '${item.bucketName} • ${formatBytes(item.sizeBytes)}',
                              sourceApp: item.sourceApp,
                              isSelected: isSelected,
                              onTap: () => _toggleSelection(item.id),
                              onLongPress: () => _toggleSelection(item.id),
                            ),
                          );
                        }),
                        const SizedBox(height: AppSpacing.sm),
                      ],
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildRetentionBanner(ColorScheme scheme) {
    // REQ-BIN-05: Honest system retention notice
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.pagePadding,
        AppSpacing.sm,
        AppSpacing.pagePadding,
        AppSpacing.xs,
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: AppRadius.cardRadius,
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, size: 20, color: scheme.primary),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              'Items in the Recycle Bin are permanently deleted by Android after approximately 30 days.',
              style: AppTextStyles.bodySmall.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
