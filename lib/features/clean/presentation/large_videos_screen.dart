// lib/features/clean/presentation/large_videos_screen.dart
//
// Large Videos category screen (REQ-VID-01).
// Configures CategoryScreen with size filters (50MB/100MB/250MB/500MB/1GB+) and duration sorting.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/tokens.dart';
import '../../../core/di/providers.dart';
import '../data/large_videos_data_source.dart';
import '../domain/category_models.dart';
import 'category_screen.dart';

class LargeVideosScreen extends ConsumerWidget {
  const LargeVideosScreen({
    super.key,
    this.dataSourceOverride,
  });

  final LargeVideosDataSource? dataSourceOverride;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataSource = dataSourceOverride ??
        LargeVideosDataSource(db: ref.watch(appDatabaseProvider));

    return CategoryScreen(
      title: 'Large Videos',
      dataSource: dataSource,
      initialViewMode: CategoryViewMode.list,
      emptyTitle: 'No large videos found',
      emptyBody: 'There are no videos larger than 50 MB in your WhatsApp chats.',
      headerBannerBuilder: (ctx, allItems, visibleItems) {
        final scheme = Theme.of(ctx).colorScheme;
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
            color: scheme.primaryContainer.withValues(alpha: 0.4),
            borderRadius: AppRadius.cardRadius,
            border: Border.all(color: scheme.primary.withValues(alpha: 0.2)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.video_settings_rounded, size: 22, color: scheme.primary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Video Compression Available',
                      style: AppTextStyles.titleSmall.copyWith(
                        color: scheme.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Reduce file sizes by up to 70% with on-device compression (REQ-ACT-09). Originals are preserved until verified.',
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
      // REQ-VID-01: Size filters (50MB / 100MB / 250MB / 500MB / 1GB+)
      filterOptions: [
        CategoryFilterOption(
          label: '50 MB+',
          predicate: (item) => item.sizeBytes >= 50 * 1024 * 1024,
        ),
        CategoryFilterOption(
          label: '100 MB+',
          predicate: (item) => item.sizeBytes >= 100 * 1024 * 1024,
        ),
        CategoryFilterOption(
          label: '250 MB+',
          predicate: (item) => item.sizeBytes >= 250 * 1024 * 1024,
        ),
        CategoryFilterOption(
          label: '500 MB+',
          predicate: (item) => item.sizeBytes >= 500 * 1024 * 1024,
        ),
        CategoryFilterOption(
          label: '1 GB+',
          predicate: (item) => item.sizeBytes >= 1024 * 1024 * 1024,
        ),
      ],
      // REQ-VID-01: Sort by size, date, duration
      sortOptions: const [
        CategorySortOption(
          label: 'Largest first',
          key: CategorySortKey.size,
          direction: SortDirection.descending,
        ),
        CategorySortOption(
          label: 'Longest first',
          key: CategorySortKey.duration,
          direction: SortDirection.descending,
        ),
        CategorySortOption(
          label: 'Newest first',
          key: CategorySortKey.dateModified,
          direction: SortDirection.descending,
        ),
        CategorySortOption(
          label: 'Oldest first',
          key: CategorySortKey.dateModified,
          direction: SortDirection.ascending,
        ),
      ],
    );
  }
}
