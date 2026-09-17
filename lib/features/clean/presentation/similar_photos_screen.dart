// lib/features/clean/presentation/similar_photos_screen.dart
//
// Similar Photos category screen (REQ-SIM-01, REQ-SIM-02, REQ-DUP-04).
//
// RULES:
//   - REQ-SIM-01: Thumbnail-based perceptual similarity clustering.
//   - REQ-SIM-02: Best shot labeled "Suggested", never "Safe to delete".
//   - REQ-DUP-04: Distinct screen and experience, never merged with Exact Duplicates.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/tokens.dart';
import '../../../core/di/providers.dart';
import '../data/similar_photos_data_source.dart';
import '../domain/category_data_source.dart';
import '../domain/category_models.dart';
import 'category_screen.dart';

final similarPhotosDataSourceProvider = Provider<SimilarPhotosDataSource>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return SimilarPhotosDataSource(db: db);
});

class SimilarPhotosScreen extends ConsumerWidget {
  const SimilarPhotosScreen({
    super.key,
    this.customDataSource,
  });

  final CategoryDataSource? customDataSource;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final CategoryDataSource dataSource =
        customDataSource ?? ref.watch(similarPhotosDataSourceProvider);

    return CategoryScreen(
      title: 'Similar Photos',
      dataSource: dataSource,
      initialViewMode: CategoryViewMode.list,
      initialSelectedIdsBuilder: (items) {
        if (dataSource is SimilarPhotosDataSource) {
          return dataSource.defaultPreselectedIds;
        }
        // Pre-select non-suggested items
        return items
            .where((item) => item.badgeLabel != 'Suggested')
            .map((e) => e.id)
            .toSet();
      },
      headerBannerBuilder: (ctx, allItems, visibleItems) {
        final scheme = Theme.of(ctx).colorScheme;
        final nonSuggestedCopies = allItems.where((it) => it.badgeLabel != 'Suggested').toList();
        final int totalSavings = (dataSource is SimilarPhotosDataSource)
            ? dataSource.totalPotentialSavings
            : nonSuggestedCopies.fold<int>(0, (sum, it) => sum + it.sizeBytes);

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
                Icons.auto_awesome_motion_outlined,
                color: scheme.primary,
                size: 24,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Visually Similar Photos',
                      style: AppTextStyles.titleSmall.copyWith(
                        color: scheme.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Groups photos with similar framing or burst shots. The best shot is marked "Suggested" based on sharpness and resolution (REQ-SIM-02).',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    if (totalSavings > 0) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Potential savings: ${formatBytes(totalSavings)}',
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
