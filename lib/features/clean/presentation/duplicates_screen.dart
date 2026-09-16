// lib/features/clean/presentation/duplicates_screen.dart
//
// Exact Duplicates screen (REQ-DUP-01 to REQ-DUP-04).
// Reuses the generic CategoryScreen from Phase 5 without forking.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/tokens.dart';
import '../../../core/di/providers.dart';
import '../data/duplicates_data_source.dart';
import '../domain/category_models.dart';
import 'category_screen.dart';

class DuplicatesScreen extends ConsumerWidget {
  const DuplicatesScreen({
    super.key,
    this.dataSourceOverride,
  });

  final DuplicatesDataSource? dataSourceOverride;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataSource = dataSourceOverride ??
        DuplicatesDataSource(db: ref.watch(appDatabaseProvider));

    return CategoryScreen(
      title: 'Exact Duplicates',
      dataSource: dataSource,
      initialViewMode: CategoryViewMode.list,
      emptyTitle: 'No exact duplicates found',
      emptyBody: 'All files in your library appear to be unique.',
      // REQ-DUP-03: Pre-select non-original copies within a group; Original is never pre-selected
      initialSelectedIdsBuilder: (items) {
        return items.where((item) => !item.isOriginal).map((item) => item.id).toSet();
      },
      // REQ-DUP-02 / REQ-DUP-04: Header showing potential savings and separate feature disclaimer
      headerBannerBuilder: (ctx, allItems, visibleItems) {
        final scheme = Theme.of(ctx).colorScheme;
        final duplicateCopies = allItems.where((it) => !it.isOriginal).toList();
        final savingsBytes = duplicateCopies.fold(0, (sum, it) => sum + it.sizeBytes);

        if (allItems.isEmpty) return const SizedBox.shrink();

        return Container(
          width: double.infinity,
          margin: const EdgeInsets.fromLTRB(
            AppSpacing.pagePadding,
            AppSpacing.xs,
            AppSpacing.pagePadding,
            AppSpacing.xs,
          ),
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: scheme.primaryContainer.withValues(alpha: 0.5),
            borderRadius: AppRadius.cardRadius,
            border: Border.all(color: scheme.primary.withValues(alpha: 0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.copy_all_rounded, size: 20, color: scheme.primary),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    'Potential Saving: ${formatBytes(savingsBytes)}',
                    style: AppTextStyles.titleSmall.copyWith(
                      color: scheme.onPrimaryContainer,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Identical byte-for-byte matches. Oldest copy marked "Original" is preserved by default.',
                style: AppTextStyles.bodySmall.copyWith(
                  color: scheme.onPrimaryContainer.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
