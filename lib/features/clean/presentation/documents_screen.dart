// lib/features/clean/presentation/documents_screen.dart
//
// Documents cleaner screen (REQ-CLN-01, P-01).
// Configured with list view by default, file type filters (PDF, Office, Archives),
// and system viewer launch integration.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/tokens.dart';
import '../../../core/di/providers.dart';
import '../data/documents_data_source.dart';
import '../domain/category_models.dart';
import 'category_screen.dart';

class DocumentsScreen extends ConsumerWidget {
  const DocumentsScreen({
    super.key,
    this.dataSourceOverride,
  });

  final DocumentsDataSource? dataSourceOverride;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataSource = dataSourceOverride ??
        DocumentsDataSource(db: ref.watch(appDatabaseProvider));

    return CategoryScreen(
      title: 'Documents',
      dataSource: dataSource,
      initialViewMode: CategoryViewMode.list,
      emptyTitle: 'No documents found',
      emptyBody: 'There are no PDFs, spreadsheets, or shared archives in your library.',
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
          label: 'Name (A-Z)',
          key: CategorySortKey.name,
          direction: SortDirection.ascending,
        ),
      ],
      filterOptions: [
        CategoryFilterOption(
          label: 'All',
          predicate: (_) => true,
        ),
        CategoryFilterOption(
          label: 'Invoices & Bills',
          predicate: (item) => DocumentsDataSource.isInvoiceOrReceipt(item),
        ),
        CategoryFilterOption(
          label: 'PDFs',
          predicate: (item) => DocumentsDataSource.isPdf(item),
        ),
        CategoryFilterOption(
          label: 'Spreadsheets',
          predicate: (item) => DocumentsDataSource.isSpreadsheet(item),
        ),
        CategoryFilterOption(
          label: 'Office Docs',
          predicate: (item) => DocumentsDataSource.isOfficeDoc(item),
        ),
        CategoryFilterOption(
          label: 'Archives',
          predicate: (item) => DocumentsDataSource.isArchive(item),
        ),
        CategoryFilterOption(
          label: 'Large (>10 MB)',
          predicate: (item) => item.sizeBytes >= 10 * 1024 * 1024,
        ),
      ],
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
                  color: Colors.blue.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.description_outlined, size: 22, color: Colors.blue),
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
                      '${visibleItems.length} documents. Tap any file to view before deciding to clean.',
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
