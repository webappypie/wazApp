// lib/features/clean/presentation/old_media_screen.dart
//
// Old Media category screen (REQ-OLD-01).
// Age filters: 3m, 6m, 1y, 2y, 3y+, sub-grouped by media type with total recoverable size.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/tokens.dart';
import '../../../core/di/providers.dart';
import '../data/old_media_data_source.dart';
import '../domain/category_models.dart';
import 'category_screen.dart';

class OldMediaScreen extends ConsumerWidget {
  const OldMediaScreen({
    super.key,
    this.dataSourceOverride,
  });

  final OldMediaDataSource? dataSourceOverride;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataSource = dataSourceOverride ??
        OldMediaDataSource(db: ref.watch(appDatabaseProvider));
    final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    return CategoryScreen(
      title: 'Old Media',
      dataSource: dataSource,
      initialViewMode: CategoryViewMode.list,
      emptyTitle: 'No old media found',
      emptyBody: 'There are no files older than 3 months in your library.',
      // REQ-OLD-01: Age filters (3m / 6m / 1y / 2y / 3y+)
      filterOptions: [
        CategoryFilterOption(
          label: '3m+',
          predicate: (item) => (nowSec - item.dateModifiedSec) >= 90 * 86400,
        ),
        CategoryFilterOption(
          label: '6m+',
          predicate: (item) => (nowSec - item.dateModifiedSec) >= 180 * 86400,
        ),
        CategoryFilterOption(
          label: '1y+',
          predicate: (item) => (nowSec - item.dateModifiedSec) >= 365 * 86400,
        ),
        CategoryFilterOption(
          label: '2y+',
          predicate: (item) => (nowSec - item.dateModifiedSec) >= 730 * 86400,
        ),
        CategoryFilterOption(
          label: '3y+',
          predicate: (item) => (nowSec - item.dateModifiedSec) >= 1095 * 86400,
        ),
      ],
      // REQ-OLD-01: Header banner showing total recoverable size
      headerBannerBuilder: (ctx, allItems, visibleItems) {
        final scheme = Theme.of(ctx).colorScheme;
        final totalRecoverableBytes = visibleItems.fold(0, (sum, it) => sum + it.sizeBytes);

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
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: AppRadius.cardRadius,
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Row(
            children: [
              Icon(Icons.history_rounded, size: 22, color: scheme.primary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total Space: ${formatBytes(totalRecoverableBytes)}',
                      style: AppTextStyles.titleSmall.copyWith(
                        color: scheme.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '${visibleItems.length} files not modified recently. Sub-grouped by media type.',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
