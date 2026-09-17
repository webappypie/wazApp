// lib/features/clean/presentation/blurry_photos_screen.dart
//
// Blurry Photos category screen (REQ-BLR-01).
//
// RULES:
//   - REQ-BLR-01: Two confidence tiers: "Very Blurry" and "Possibly Blurry".
//   - Shallow depth of field (DoF) / intentional bokeh is preserved.
//   - Only "Very Blurry" is pre-selected by default; "Possibly Blurry" is unselected.
//   - Items are labeled by confidence tier, NEVER "Safe to delete".

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/tokens.dart';
import '../../../core/di/providers.dart';
import '../data/blurry_photos_data_source.dart';
import '../domain/category_data_source.dart';
import '../domain/category_models.dart';
import 'category_screen.dart';

final blurryPhotosDataSourceProvider = Provider<BlurryPhotosDataSource>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return BlurryPhotosDataSource(db: db);
});

class BlurryPhotosScreen extends ConsumerWidget {
  const BlurryPhotosScreen({
    super.key,
    this.customDataSource,
  });

  final CategoryDataSource? customDataSource;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final CategoryDataSource dataSource =
        customDataSource ?? ref.watch(blurryPhotosDataSourceProvider);

    return CategoryScreen(
      title: 'Blurry Photos',
      dataSource: dataSource,
      initialViewMode: CategoryViewMode.list,
      filterOptions: [
        CategoryFilterOption(
          label: 'All',
          predicate: (_) => true,
        ),
        CategoryFilterOption(
          label: 'Very Blurry',
          predicate: (item) => item.badgeLabel == 'Very Blurry',
        ),
        CategoryFilterOption(
          label: 'Possibly Blurry',
          predicate: (item) => item.badgeLabel == 'Possibly Blurry',
        ),
      ],
      initialSelectedIdsBuilder: (items) {
        if (dataSource is BlurryPhotosDataSource) {
          return dataSource.defaultPreselectedIds;
        }
        return items
            .where((item) => item.badgeLabel == 'Very Blurry')
            .map((e) => e.id)
            .toSet();
      },
      headerBannerBuilder: (ctx, allItems, visibleItems) {
        final scheme = Theme.of(ctx).colorScheme;
        final veryBlurryItems =
            allItems.where((it) => it.badgeLabel == 'Very Blurry').toList();
        final int totalSavings = (dataSource is BlurryPhotosDataSource)
            ? dataSource.totalPotentialSavings
            : veryBlurryItems.fold<int>(0, (sum, it) => sum + it.sizeBytes);

        return Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.md),
          padding: const EdgeInsets.all(AppSpacing.cardPadding),
          decoration: BoxDecoration(
            color: scheme.primaryContainer.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: scheme.primaryContainer),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.blur_on_rounded,
                color: scheme.primary,
                size: 24,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Blur Detection',
                      style: AppTextStyles.titleSmall.copyWith(
                        color: scheme.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Identifies photos degraded by camera shake, out-of-focus capture, or motion. Photos with intentional background bokeh (portrait/macro) are protected.',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    if (totalSavings > 0) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'High-confidence savings: ${formatBytes(totalSavings)}',
                        style: AppTextStyles.labelMedium.copyWith(
                          color: scheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
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
