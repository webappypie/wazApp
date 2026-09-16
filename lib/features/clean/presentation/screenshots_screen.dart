// lib/features/clean/presentation/screenshots_screen.dart
//
// Screenshots category screen (REQ-SCR-01).
// Configures CategoryScreen with date filters: Today, 7 days, 30 days, 6 months, 1 year+.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../data/screenshots_data_source.dart';
import '../domain/category_models.dart';
import 'category_screen.dart';

class ScreenshotsScreen extends ConsumerWidget {
  const ScreenshotsScreen({
    super.key,
    this.dataSourceOverride,
  });

  final ScreenshotsDataSource? dataSourceOverride;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataSource = dataSourceOverride ??
        ScreenshotsDataSource(db: ref.watch(appDatabaseProvider));
    final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    return CategoryScreen(
      title: 'Screenshots',
      dataSource: dataSource,
      initialViewMode: CategoryViewMode.grid,
      emptyTitle: 'No screenshots found',
      emptyBody: 'There are no screenshots detected in your chat media.',
      // REQ-SCR-01: Date filters (all / today / 7d / 30d / 6m / 1y+)
      filterOptions: [
        CategoryFilterOption(
          label: 'All',
          predicate: (_) => true,
        ),
        CategoryFilterOption(
          label: 'Today',
          predicate: (item) => (nowSec - item.dateAddedSec) <= 86400,
        ),
        CategoryFilterOption(
          label: '7 days',
          predicate: (item) => (nowSec - item.dateAddedSec) <= 7 * 86400,
        ),
        CategoryFilterOption(
          label: '30 days',
          predicate: (item) => (nowSec - item.dateAddedSec) <= 30 * 86400,
        ),
        CategoryFilterOption(
          label: '6 months',
          predicate: (item) => (nowSec - item.dateAddedSec) <= 180 * 86400,
        ),
        CategoryFilterOption(
          label: '1 year+',
          predicate: (item) => (nowSec - item.dateAddedSec) >= 365 * 86400,
        ),
      ],
    );
  }
}
