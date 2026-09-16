// lib/features/clean/presentation/large_videos_screen.dart
//
// Large Videos category screen (REQ-VID-01).
// Configures CategoryScreen with size filters (50MB/100MB/250MB/500MB/1GB+) and duration sorting.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
