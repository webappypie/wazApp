// lib/features/analytics/presentation/storage_analytics_screen.dart
//
// Storage Growth Analytics Screen (REQ-ANL-01 to REQ-ANL-04, PRD §7.8, §11.3).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/tokens.dart';
import '../../../core/di/providers.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/source_badge.dart';
import '../../../core/widgets/source_filter_bar.dart';
import '../../../core/widgets/state_widgets.dart';
import '../domain/analytics_models.dart';
import 'analytics_controller.dart';
import 'widgets/storage_growth_chart.dart';

class StorageAnalyticsScreen extends ConsumerWidget {
  const StorageAnalyticsScreen({super.key});

  void _showPremiumDialog(BuildContext context, WidgetRef ref) {
    final purchaseService = ref.read(purchaseServiceProvider);
    final scheme = Theme.of(context).colorScheme;

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(Icons.workspace_premium, color: scheme.primary, size: 36),
        title: const Text('Unlock Extended Trends'),
        content: const Text(
          '6-Month and All-Time storage growth analytics are exclusive to WappTidy Lifetime Premium.\n\n'
          'Upgrade today to track long-term clutter patterns and enjoy an ad-free experience permanently.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await purchaseService.purchase();
            },
            child: const Text('Upgrade'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trendsAsync = ref.watch(analyticsTrendsProvider);
    final currentRange = ref.watch(selectedTimeRangeProvider);
    final isPremium = ref.watch(isPremiumProvider);
    return AppScaffold(
      appBar: AppBar(
        title: const Text('Storage Analytics'),
        centerTitle: false,
      ),
      body: trendsAsync.when(
        data: (trends) => _AnalyticsBody(
          trends: trends,
          currentRange: currentRange,
          isPremium: isPremium,
          onRangeSelected: (range) {
            if (range.isPremiumOnly && !isPremium) {
              _showPremiumDialog(context, ref);
            } else {
              ref.read(selectedTimeRangeProvider.notifier).setRange(range);
            }
          },
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => ErrorState(
          message: 'Could not load analytics.\n$err',
          onRetry: () => ref.invalidate(analyticsTrendsProvider),
        ),
      ),
    );
  }
}

class _AnalyticsBody extends ConsumerWidget {
  const _AnalyticsBody({
    super.key,
    required this.trends,
    required this.currentRange,
    required this.isPremium,
    required this.onRangeSelected,
  });

  final AnalyticsTrends trends;
  final TimeRange currentRange;
  final bool isPremium;
  final ValueChanged<TimeRange> onRangeSelected;

  String _formatBytes(int bytes) {
    if (bytes.abs() >= 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
    return '${(bytes / (1024 * 1024)).round()} MB';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final bizInsights = ref.watch(businessInsightsProvider).asData?.value;

    return ListView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.pagePadding,
        vertical: AppSpacing.lg,
      ),
      children: [
        // 0. Source Filter Bar (auto-hides when single source) (REQ-19)
        const Padding(
          padding: EdgeInsets.only(bottom: AppSpacing.md),
          child: SourceFilterBar(),
        ),

        // 1. Time Range Selector Tabs
        Container(
          padding: const EdgeInsets.all(AppSpacing.xs / 2),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Row(
            children: TimeRange.values.map((range) {
              final isSelected = range == currentRange;
              final showLock = range.isPremiumOnly && !isPremium;

              return Expanded(
                child: GestureDetector(
                  onTap: () => onRangeSelected(range),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: isSelected ? scheme.surface : Colors.transparent,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.08),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              )
                            ]
                          : null,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          range.shortLabel,
                          style: AppTextStyles.labelMedium.copyWith(
                            color: isSelected ? scheme.primary : scheme.onSurfaceVariant,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                        if (showLock) ...[
                          const SizedBox(width: 4),
                          Icon(Icons.lock_outline, size: 13, color: scheme.outline),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),

        const SizedBox(height: AppSpacing.lg),

        // 2. Summary Metric Cards
        Row(
          children: [
            Expanded(
              child: _MetricCard(
                label: 'Current Total',
                value: _formatBytes(trends.currentTotalBytes),
                icon: Icons.storage_outlined,
                color: scheme.primary,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _MetricCard(
                label: 'Net Growth (${currentRange.shortLabel})',
                value: '${trends.netGrowthBytes >= 0 ? '+' : ''}${_formatBytes(trends.netGrowthBytes)}',
                subtitle: '${trends.netGrowthPercentage >= 0 ? '+' : ''}${trends.netGrowthPercentage.toStringAsFixed(1)}%',
                icon: trends.netGrowthBytes >= 0 ? Icons.trending_up : Icons.trending_down,
                color: trends.netGrowthBytes >= 0 ? kColorWarning : kColorSuccess,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _MetricCard(
                label: 'Daily Average',
                value: '${trends.dailyAverageBytes >= 0 ? '+' : ''}${_formatBytes(trends.dailyAverageBytes)}',
                icon: Icons.speed_outlined,
                color: scheme.secondary,
              ),
            ),
          ],
        ),

        const SizedBox(height: AppSpacing.lg),

        // 3. Growth Trajectory Chart Card
        Card(
          elevation: 0,
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.3),
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.cardRadius,
            side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.cardPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Storage Growth Curve',
                      style: AppTextStyles.titleSmall.copyWith(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      currentRange.fullLabel,
                      style: AppTextStyles.labelSmall.copyWith(color: scheme.outline),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                StorageGrowthChart(
                  snapshots: trends.snapshots,
                  primaryColor: scheme.primary,
                  gradientColor: scheme.primaryContainer,
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: AppSpacing.lg),

        // 4. Media Type Proportion Breakdown (REQ-ANL-03)
        Card(
          elevation: 0,
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.3),
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.cardRadius,
            side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.cardPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Media Type Breakdown',
                  style: AppTextStyles.titleSmall.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: AppSpacing.md),

                // Multi-segment color bar
                _ProportionBar(breakdown: trends.breakdown),
                const SizedBox(height: AppSpacing.md),

                // Category List
                ...trends.breakdown.rankedCategories.map((cat) {
                  final isTop = cat == trends.breakdown.largestContributor;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                    child: Row(
                      children: [
                        _CategoryIndicator(categoryName: cat.categoryName),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            cat.categoryName,
                            style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w500),
                          ),
                        ),
                        if (isTop) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: scheme.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Largest Contributor',
                              style: AppTextStyles.labelSmall.copyWith(
                                color: scheme.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                        ],
                        Text(
                          _formatBytes(cat.sizeBytes),
                          style: AppTextStyles.labelMedium,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          '()',
                          style: AppTextStyles.bodySmall.copyWith(color: scheme.outline),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ),

        const SizedBox(height: AppSpacing.lg),

        // 4b. WhatsApp Business Specific Insights (REQ-13)
        if (bizInsights != null && bizInsights.hasData) ...[
          _BusinessInsightsCard(insights: bizInsights),
          const SizedBox(height: AppSpacing.lg),
        ],

        // 5. Cold-Start Historical Reconstruction Banner (REQ-ANL-02)
        Container(
          padding: const EdgeInsets.all(AppSpacing.cardPadding),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
            borderRadius: AppRadius.cardRadius,
            border: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.4)).toBorder(),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.history_edu, color: scheme.primary, size: 22),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Historical Timeline Reconstructed',
                      style: AppTextStyles.titleSmall.copyWith(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'To eliminate the 30-day cold-start delay, WappTidy reconstructed this growth trajectory from original media creation timestamps (REQ-ANL-02).',
                      style: AppTextStyles.bodySmall.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.xxl),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    this.subtitle,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final String? subtitle;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: AppRadius.cardRadius,
        border: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.3)).toBorder(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.labelSmall.copyWith(fontSize: 10, color: scheme.outline),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.titleSmall.copyWith(fontWeight: FontWeight.w700),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle!,
              style: AppTextStyles.bodySmall.copyWith(color: color, fontSize: 10, fontWeight: FontWeight.w600),
            ),
          ],
        ],
      ),
    );
  }
}

class _ProportionBar extends StatelessWidget {
  const _ProportionBar({required this.breakdown});
  final MediaTypeBreakdown breakdown;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        height: 12,
        child: Row(
          children: [
            if (breakdown.videoRatio > 0)
              Expanded(
                flex: (breakdown.videoRatio * 1000).round(),
                child: Container(color: Colors.amber.shade700),
              ),
            if (breakdown.imageRatio > 0)
              Expanded(
                flex: (breakdown.imageRatio * 1000).round(),
                child: Container(color: Colors.blue.shade600),
              ),
            if (breakdown.audioRatio > 0)
              Expanded(
                flex: (breakdown.audioRatio * 1000).round(),
                child: Container(color: Colors.purple.shade500),
              ),
            if (breakdown.documentRatio > 0)
              Expanded(
                flex: (breakdown.documentRatio * 1000).round(),
                child: Container(color: Colors.teal.shade500),
              ),
          ],
        ),
      ),
    );
  }
}

class _CategoryIndicator extends StatelessWidget {
  const _CategoryIndicator({required this.categoryName});
  final String categoryName;

  Color get _color {
    switch (categoryName) {
      case 'Videos':
        return Colors.amber.shade700;
      case 'Images':
        return Colors.blue.shade600;
      case 'Audio':
        return Colors.purple.shade500;
      default:
        return Colors.teal.shade500;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: _color,
        shape: BoxShape.circle,
      ),
    );
  }
}

extension on BorderSide {
  Border toBorder() => Border.fromBorderSide(this);
}

class _BusinessInsightsCard extends StatelessWidget {
  const _BusinessInsightsCard({required this.insights});
  final BusinessInsights insights;

  String _formatBytes(int bytes) {
    if (bytes.abs() >= 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
    return '${(bytes / (1024 * 1024)).round()} MB';
  }

  String _formatDuration(int sec) {
    final m = sec ~/ 60;
    return '$m min';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.cardRadius,
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF128C7E).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.business_center_rounded, size: 18, color: Color(0xFF128C7E)),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'WhatsApp Business Insights',
                        style: AppTextStyles.titleSmall.copyWith(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        '${insights.totalCount} business media items • ${_formatBytes(insights.totalBytes)}',
                        style: AppTextStyles.bodySmall.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: _MiniMetricTile(
                    label: 'Invoices & Bills',
                    value: '${insights.invoicesCount} files',
                    subtitle: _formatBytes(insights.invoicesBytes),
                    icon: Icons.receipt_long_rounded,
                    color: Colors.teal,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _MiniMetricTile(
                    label: 'Spreadsheets & Docs',
                    value: '${insights.documentsCount + insights.spreadsheetsCount} files',
                    subtitle: _formatBytes(insights.documentsBytes + insights.spreadsheetsBytes),
                    icon: Icons.description_outlined,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: _MiniMetricTile(
                    label: 'Catalog & Videos',
                    value: '${insights.catalogVideosCount} videos',
                    subtitle: _formatBytes(insights.catalogVideosBytes),
                    icon: Icons.video_library_outlined,
                    color: Colors.amber.shade800,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _MiniMetricTile(
                    label: 'Voice Notes',
                    value: '${insights.voiceNotesCount} notes',
                    subtitle: _formatDuration(insights.voiceNotesDurationSec),
                    icon: Icons.mic_none_rounded,
                    color: Colors.purple,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniMetricTile extends StatelessWidget {
  const _MiniMetricTile({
    required this.label,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  style: AppTextStyles.labelSmall.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontSize: 11,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: AppTextStyles.labelMedium.copyWith(fontWeight: FontWeight.w700),
          ),
          Text(
            subtitle,
            style: AppTextStyles.bodySmall.copyWith(
              color: scheme.outline,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}
