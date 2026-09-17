// lib/features/clean/presentation/voice_notes_screen.dart
//
// Voice Notes & Audio cleaner screen (REQ-CLN-01, P-01).
// Configured with list view by default, duration & PTT filters,
// and audio playback preview integration.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/tokens.dart';
import '../../../core/di/providers.dart';
import '../data/voice_notes_data_source.dart';
import '../domain/category_models.dart';
import 'category_screen.dart';

class VoiceNotesScreen extends ConsumerWidget {
  const VoiceNotesScreen({
    super.key,
    this.dataSourceOverride,
  });

  final VoiceNotesDataSource? dataSourceOverride;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataSource = dataSourceOverride ??
        VoiceNotesDataSource(db: ref.watch(appDatabaseProvider));
    final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    return CategoryScreen(
      title: 'Voice Notes & Audio',
      dataSource: dataSource,
      initialViewMode: CategoryViewMode.list,
      emptyTitle: 'No audio files found',
      emptyBody: 'There are no voice notes or audio recordings in your library.',
      // Sort options including duration sorting
      sortOptions: const [
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
        CategorySortOption(
          label: 'Largest first',
          key: CategorySortKey.size,
          direction: SortDirection.descending,
        ),
        CategorySortOption(
          label: 'Smallest first',
          key: CategorySortKey.size,
          direction: SortDirection.ascending,
        ),
        CategorySortOption(
          label: 'Longest first',
          key: CategorySortKey.duration,
          direction: SortDirection.descending,
        ),
      ],
      // Filter options: All, Voice Notes (PTT), Audio Clips, Old (>6m), Large (>5 MB)
      filterOptions: [
        CategoryFilterOption(
          label: 'All',
          predicate: (_) => true,
        ),
        CategoryFilterOption(
          label: 'Voice Notes',
          predicate: (item) => VoiceNotesDataSource.isVoiceNote(item),
        ),
        CategoryFilterOption(
          label: 'Audio Clips',
          predicate: (item) => VoiceNotesDataSource.isAudioClip(item),
        ),
        CategoryFilterOption(
          label: 'Old (>6m)',
          predicate: (item) => (nowSec - item.dateModifiedSec) >= 180 * 86400,
        ),
        CategoryFilterOption(
          label: 'Large (>5 MB)',
          predicate: (item) => item.sizeBytes >= 5 * 1024 * 1024,
        ),
      ],
      // Header banner showing total volume and safe preview guidance
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
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: Colors.deepOrange.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.mic_none_rounded, size: 22, color: Colors.deepOrange),
              ),
              const SizedBox(width: AppSpacing.md),
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
                      '${visibleItems.length} audio recordings. Tap any item to listen before deleting.',
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
