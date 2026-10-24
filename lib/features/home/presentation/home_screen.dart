// lib/features/home/presentation/home_screen.dart
//
// Home dashboard — Phase 4 implementation.
//
// Requirements: REQ-HOM-01 to REQ-HOM-04, REQ-HOM-07
// Rules:
//   - P-03: every number traces to real DB data
//   - P-04: no fear messaging, no red-alert dashboard
//   - REQ-HOM-07: Premium users → no ad container laid out at all
//   - REQ-ADS-05: no ad adjacent to destructive action (not applicable here,
//     but the NativeAdContainer widget already enforces it)
//   - No arbitrary hardcoded sizes — all from design tokens

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/tokens.dart';
import '../../../core/di/providers.dart';
import '../../../core/router/app_router.dart';
import '../../../core/services/media_access/media_access_service.dart';
import '../../indexing/presentation/indexing_providers.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/monetisation_widgets.dart';
import '../../../core/widgets/partial_access_banner.dart';
import '../../../core/widgets/source_badge.dart';
import '../../../core/widgets/source_filter_bar.dart';
import '../../../core/widgets/state_widgets.dart';
import '../domain/home_models.dart';
import 'home_providers.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashAsync = ref.watch(homeDashboardProvider);

    return AppScaffold(
      appBar: AppBar(
        title: const Text('WappTidy'),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded),
            tooltip: 'Search Media',
            onPressed: () => context.go(AppRoutes.search),
          ),
          if (kDebugMode)
            IconButton(
              icon: const Icon(Icons.developer_mode_outlined),
              tooltip: 'Component Gallery',
              onPressed: () => context.go(AppRoutes.devGallery),
            ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () => context.go(AppRoutes.settings),
          ),
        ],
      ),
      body: Column(
        children: [
          const PartialAccessBanner(),
          Expanded(
            child: dashAsync.when(
              data:    (d) => _HomeBody(dashboard: d),
              loading: () => const SkeletonListLoader(itemCount: 5),
              error:   (e, _) => ErrorState(
                message: 'Could not load dashboard.\n$e',
                onRetry: () => ref.invalidate(homeDashboardProvider),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Body — scrollable column of sections
// ---------------------------------------------------------------------------

class _HomeBody extends ConsumerWidget {
  const _HomeBody({required this.dashboard});
  final HomeDashboard dashboard;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPremium = ref.watch(isPremiumProvider);

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(homeDashboardProvider),
      child: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.pagePadding,
          vertical: AppSpacing.lg,
        ),
        children: [
          // 0. Source filter bar (auto-hides if only 1 source installed/indexed)
          const Padding(
            padding: EdgeInsets.only(bottom: AppSpacing.sm),
            child: SourceFilterBar(),
          ),

          // 1. Hero card (REQ-HOM-01)
          _HeroCard(dashboard: dashboard),
          const SizedBox(height: AppSpacing.lg),

          // 1b. Media by App breakdown card (REQ-7)
          if (dashboard.sourceBreakdown != null && dashboard.sourceBreakdown!.hasBothSources) ...[
            _SourceBreakdownCard(breakdown: dashboard.sourceBreakdown!),
            const SizedBox(height: AppSpacing.lg),
          ],

          // 2. Media Health score (REQ-HOM-02)
          _HealthScoreCard(result: dashboard.healthScore),
          const SizedBox(height: AppSpacing.lg),

          // 3. Ad slot — collapses to zero for Premium (REQ-HOM-07)
          if (!isPremium) ...[
            NativeAdContainer(
              minContentItemsAbove: 2,
              minContentItemsRequired: 2,
            ),
            const SizedBox(height: AppSpacing.lg),
          ],

          // 4. Cleanup opportunity cards (REQ-HOM-03)
          if (dashboard.opportunities.isNotEmpty) ...[
            _SectionHeader(title: 'Cleanup Opportunities'),
            const SizedBox(height: AppSpacing.sm),
            ...dashboard.opportunities.map(
              (c) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: _OpportunityCardTile(card: c),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],

          // 5. Recent activity (REQ-HOM-04)
          _RecentActivitySection(entries: dashboard.recentActivity),
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Hero card (REQ-HOM-01)
// ---------------------------------------------------------------------------

class _HeroCard extends ConsumerWidget {
  const _HeroCard({required this.dashboard});
  final HomeDashboard dashboard;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final mom    = dashboard.monthOverMonthDelta;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            scheme.primaryContainer,
            scheme.secondaryContainer.withValues(alpha: 0.6),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: AppRadius.cardRadius,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Chat Media Storage',
                style: AppTextStyles.labelMedium
                    .copyWith(color: scheme.onPrimaryContainer.withValues(alpha: 0.7)),
              ),
              InkWell(
                onTap: () => context.go(AppRoutes.storageAnalytics),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  child: Row(
                    children: [
                      Icon(Icons.show_chart, size: 14, color: scheme.onPrimaryContainer),
                      const SizedBox(width: 4),
                      Text(
                        'Trends',
                        style: AppTextStyles.labelSmall.copyWith(
                          color: scheme.onPrimaryContainer,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),

          // Total size — P-03: real data from DB
          Text(
            dashboard.totalIndexedBytes == 0
                ? 'No media scanned yet'
                : dashboard.formattedTotal,
            style: AppTextStyles.displaySmall
                .copyWith(color: scheme.onPrimaryContainer),
          ),

          const SizedBox(height: AppSpacing.xs),

          // Month-over-month delta
          if (mom != null)
            _MomDelta(bytes: mom, scheme: scheme)
          else
            Text(
              '${dashboard.totalItemCount} files indexed',
              style: AppTextStyles.bodySmall
                  .copyWith(color: scheme.onPrimaryContainer.withValues(alpha: 0.7)),
            ),

          // Per-source breakdown strip (REQ-6)
          if (dashboard.sourceBreakdown != null && dashboard.sourceBreakdown!.hasBothSources) ...[
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: scheme.surface.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'WhatsApp: ${dashboard.sourceBreakdown!.formattedWhatsAppBytes}',
                    style: AppTextStyles.labelSmall.copyWith(
                      color: scheme.onPrimaryContainer,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text('•', style: TextStyle(color: scheme.onPrimaryContainer.withValues(alpha: 0.6))),
                  Text(
                    'Business: ${dashboard.sourceBreakdown!.formattedBusinessBytes}',
                    style: AppTextStyles.labelSmall.copyWith(
                      color: scheme.onPrimaryContainer,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: AppSpacing.lg),

          // Recoverable size
          if (dashboard.recoverable.totalRecoverableBytes > 0)
            _RecoverableRow(
              formattedSize: dashboard.formattedRecoverable,
              scheme: scheme,
            ),

          const SizedBox(height: AppSpacing.lg),

          // Primary CTA
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () => _handlePrimaryCta(context, ref),
              style: ElevatedButton.styleFrom(
                backgroundColor: scheme.primary,
                foregroundColor: scheme.onPrimary,
                elevation: AppElevation.none,
                shape: const RoundedRectangleBorder(
                    borderRadius: AppRadius.buttonRadius),
              ),
              child: Text(dashboard.totalItemCount == 0 ? 'Scan Media' : 'Review Cleanup'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handlePrimaryCta(BuildContext context, WidgetRef ref) async {
    if (dashboard.totalItemCount == 0) {
      final perm = await ref.read(mediaAccessServiceProvider).checkPermission();
      if (perm != MediaPermissionState.granted && perm != MediaPermissionState.limited) {
        final req = await ref.read(mediaAccessServiceProvider).requestPermission();
        ref.invalidate(mediaPermissionStateProvider);
        if (req != MediaPermissionState.granted && req != MediaPermissionState.limited) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Storage permission is required to scan your WhatsApp media.')),
            );
          }
          return;
        }
      }
      ref.read(indexingServiceProvider).startScan();
    }
    if (context.mounted) {
      context.go(AppRoutes.clean);
    }
  }
}

// ---------------------------------------------------------------------------
// Media by App breakdown card (REQ-7)
// ---------------------------------------------------------------------------

class _SourceBreakdownCard extends ConsumerWidget {
  const _SourceBreakdownCard({required this.breakdown});
  final SourceBreakdown breakdown;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final activeFilter = ref.watch(activeSourceFilterProvider);

    final waFlex = (breakdown.whatsAppPercent * 10).round().clamp(1, 1000);
    final bizFlex = (breakdown.businessPercent * 10).round().clamp(1, 1000);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: AppRadius.cardRadius,
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Media by App',
                style: AppTextStyles.titleSmall.copyWith(
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface,
                ),
              ),
              if (breakdown.totalPotentialCleanupBytes > 0)
                Text(
                  'Potential cleanup: ${breakdown.formattedTotalCleanup}',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // Split progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 8,
              child: Row(
                children: [
                  Expanded(
                    flex: waFlex,
                    child: Container(color: const Color(0xFF25D366)),
                  ),
                  const SizedBox(width: 2),
                  Expanded(
                    flex: bizFlex,
                    child: Container(color: const Color(0xFF128C7E)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // App rows
          _AppRow(
            color: const Color(0xFF25D366),
            title: 'WhatsApp',
            count: breakdown.whatsAppCount,
            formattedSize: breakdown.formattedWhatsAppBytes,
            cleanupSize: breakdown.formattedWhatsAppCleanup,
            isSelected: activeFilter == MediaSourceFilter.whatsApp,
            onTap: () {
              ref.read(activeSourceFilterProvider.notifier).setFilter(
                    activeFilter == MediaSourceFilter.whatsApp
                        ? MediaSourceFilter.all
                        : MediaSourceFilter.whatsApp,
                  );
            },
          ),
          const SizedBox(height: AppSpacing.xs),
          _AppRow(
            color: const Color(0xFF128C7E),
            title: 'WhatsApp Business',
            count: breakdown.businessCount,
            formattedSize: breakdown.formattedBusinessBytes,
            cleanupSize: breakdown.formattedBusinessCleanup,
            isSelected: activeFilter == MediaSourceFilter.whatsAppBusiness,
            onTap: () {
              ref.read(activeSourceFilterProvider.notifier).setFilter(
                    activeFilter == MediaSourceFilter.whatsAppBusiness
                        ? MediaSourceFilter.all
                        : MediaSourceFilter.whatsAppBusiness,
                  );
            },
          ),
        ],
      ),
    );
  }
}

class _AppRow extends StatelessWidget {
  const _AppRow({
    required this.color,
    required this.title,
    required this.count,
    required this.formattedSize,
    required this.cleanupSize,
    required this.isSelected,
    required this.onTap,
  });

  final Color color;
  final String title;
  final int count;
  final String formattedSize;
  final String cleanupSize;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? scheme.primaryContainer.withValues(alpha: 0.35) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.labelMedium.copyWith(
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                    ),
                  ),
                  Text(
                    '$count files • $formattedSize',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (cleanupSize != '0 B')
              Text(
                '~$cleanupSize cleanable',
                style: AppTextStyles.labelSmall.copyWith(
                  color: scheme.primary,
                ),
              ),
            const SizedBox(width: 4),
            Icon(
              isSelected ? Icons.check_circle_rounded : Icons.chevron_right_rounded,
              size: 16,
              color: isSelected ? scheme.primary : scheme.outline,
            ),
          ],
        ),
      ),
    );
  }
}

class _MomDelta extends StatelessWidget {
  const _MomDelta({required this.bytes, required this.scheme});
  final int bytes;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final isGrowth = bytes > 0;
    final formatted = _formatBytesShort(bytes.abs());
    return Row(
      children: [
        Icon(
          isGrowth ? Icons.trending_up_rounded : Icons.trending_down_rounded,
          size: 14,
          color: isGrowth
              ? kColorWarning
              : kColorSuccess,
        ),
        const SizedBox(width: 4),
        Text(
          isGrowth ? '+$formatted this month' : '-$formatted this month',
          style: AppTextStyles.bodySmall.copyWith(
            color: scheme.onPrimaryContainer.withValues(alpha: 0.8),
          ),
        ),
      ],
    );
  }

  String _formatBytesShort(int b) {
    if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(0)} KB';
    if (b < 1024 * 1024 * 1024) {
      return '${(b / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(b / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}

class _RecoverableRow extends StatelessWidget {
  const _RecoverableRow({required this.formattedSize, required this.scheme});
  final String formattedSize;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: scheme.onPrimaryContainer.withValues(alpha: 0.08),
        borderRadius: AppRadius.chipRadius,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.recycling_rounded,
              size: 16, color: kColorSuccess),
          const SizedBox(width: AppSpacing.xs),
          Text(
            '$formattedSize potentially recoverable',
            style: AppTextStyles.labelMedium.copyWith(
                color: scheme.onPrimaryContainer),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Health score card (REQ-HOM-02)
// ---------------------------------------------------------------------------

class _HealthScoreCard extends StatelessWidget {
  const _HealthScoreCard({required this.result});
  final HealthScoreResult result;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      elevation: AppElevation.card,
      child: InkWell(
        borderRadius: AppRadius.cardRadius,
        onTap: () => _showBreakdownSheet(context),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              // Score gauge
              _ScoreGauge(score: result.score),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Media Health',
                        style: AppTextStyles.titleMedium
                            .copyWith(color: scheme.onSurface)),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      _scoreLabel(result.score),
                      style: AppTextStyles.bodySmall
                          .copyWith(color: scheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Tap to see breakdown',
                      style: AppTextStyles.labelSmall.copyWith(
                          color: scheme.primary),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }

  void _showBreakdownSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _HealthBreakdownSheet(result: result),
    );
  }

  String _scoreLabel(int score) {
    if (score >= 80) return 'Your library is in good shape.';
    if (score >= 60) return 'Some cleanup could help.';
    if (score >= 40) return 'Your library has room for improvement.';
    return 'Consider reviewing your media.';
  }
}

class _ScoreGauge extends StatelessWidget {
  const _ScoreGauge({required this.score});
  final int score;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = score >= 70
        ? kColorSuccess
        : score >= 45
            ? kColorWarning
            : kColorDestructive;

    return SizedBox(
      width: 64,
      height: 64,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: score / 100,
            strokeWidth: 6,
            backgroundColor: scheme.surfaceContainerHighest,
            color: color,
          ),
          Text(
            '$score',
            style: AppTextStyles.titleMedium
                .copyWith(color: scheme.onSurface, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Health breakdown bottom sheet (REQ-HOM-02 tap-through)
// ---------------------------------------------------------------------------

class _HealthBreakdownSheet extends StatelessWidget {
  const _HealthBreakdownSheet({required this.result});
  final HealthScoreResult result;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize:     0.4,
      maxChildSize:     0.9,
      expand: false,
      builder: (_, scrollController) => ListView(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.xxl),
        children: [
          // Handle
          Center(
            child: Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: AppSpacing.lg),
              decoration: BoxDecoration(
                color: scheme.outlineVariant,
                borderRadius: AppRadius.chipRadius,
              ),
            ),
          ),
          Text('Media Health Breakdown',
              style: AppTextStyles.titleLarge
                  .copyWith(color: scheme.onSurface)),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Score: ${result.score}/100 — computed from your actual media library. '
            'Never an AI score.',
            style: AppTextStyles.bodySmall
                .copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (result.components.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
              child: Text(
                'Scan your media first to see the breakdown.',
                style: AppTextStyles.bodyMedium
                    .copyWith(color: scheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
            )
          else
            ...result.components.map((c) => _ComponentRow(component: c)),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Categories not yet scanned (blur detection, similar photos) '
            'contribute 0 points. Their weight is redistributed proportionally.',
            style: AppTextStyles.bodySmall
                .copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _ComponentRow extends StatelessWidget {
  const _ComponentRow({required this.component});
  final HealthScoreComponent component;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final labelColor = switch (component.healthLabel) {
      HealthLabel.good     => kColorSuccess,
      HealthLabel.moderate => kColorWarning,
      HealthLabel.high     => kColorDestructive,
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(component.label,
                    style: AppTextStyles.bodyMedium
                        .copyWith(color: scheme.onSurface)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm, vertical: 2),
                decoration: BoxDecoration(
                  color: labelColor.withValues(alpha: 0.12),
                  borderRadius: AppRadius.chipRadius,
                ),
                child: Text(
                  component.healthLabel.displayName,
                  style: AppTextStyles.labelSmall.copyWith(color: labelColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: const BorderRadius.all(Radius.circular(4)),
                  child: LinearProgressIndicator(
                    value: component.ratio,
                    minHeight: 4,
                    backgroundColor: scheme.surfaceContainerHighest,
                    color: labelColor,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                component.ratioPercent,
                style: AppTextStyles.labelSmall
                    .copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Opportunity card tile (REQ-HOM-03)
// ---------------------------------------------------------------------------

class _OpportunityCardTile extends StatelessWidget {
  const _OpportunityCardTile({required this.card});
  final OpportunityCard card;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      elevation: AppElevation.none,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.cardRadius,
        side: BorderSide(color: scheme.outlineVariant, width: 1),
      ),
      child: InkWell(
        borderRadius: AppRadius.cardRadius,
        onTap: () => context.go(card.routePath),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: const BorderRadius.all(Radius.circular(12)),
                ),
                child: Icon(
                  _iconForCard(card.id),
                  color: scheme.onPrimaryContainer,
                  size: 22,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(card.title,
                        style: AppTextStyles.titleSmall
                            .copyWith(color: scheme.onSurface)),
                    const SizedBox(height: 2),
                    Text(
                      card.subtitle,
                      style: AppTextStyles.bodySmall
                          .copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    card.formattedSize,
                    style: AppTextStyles.titleSmall
                        .copyWith(color: scheme.onSurface),
                  ),
                  Text(
                    '${card.fileCount} files',
                    style: AppTextStyles.labelSmall
                        .copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
              const SizedBox(width: AppSpacing.sm),
              Icon(Icons.chevron_right_rounded,
                  color: scheme.onSurfaceVariant, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Recent activity section (REQ-HOM-04)
// ---------------------------------------------------------------------------

class _RecentActivitySection extends StatelessWidget {
  const _RecentActivitySection({required this.entries});
  final List<RecentActivityEntry> entries;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(title: 'Recent Activity'),
        const SizedBox(height: AppSpacing.sm),
        if (entries.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
            child: Center(
              child: Text(
                'No cleanup sessions yet.\nTap "Review Cleanup" to get started.',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodySmall
                    .copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
          )
        else
          ...entries.take(5).map((e) => _ActivityRow(entry: e)),
      ],
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.entry});
  final RecentActivityEntry entry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          Icon(Icons.check_circle_outline_rounded,
              color: kColorSuccess, size: 18),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.actionLabel,
                    style: AppTextStyles.bodyMedium
                        .copyWith(color: scheme.onSurface)),
                Text(
                  '${entry.filesCount} files · ${entry.formattedBytes} freed',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          Text(
            _relativeTime(entry.timestamp),
            style: AppTextStyles.labelSmall
                .copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1)   return '${diff.inMinutes}m ago';
    if (diff.inDays < 1)    return '${diff.inHours}h ago';
    if (diff.inDays < 30)   return '${diff.inDays}d ago';
    return '${(diff.inDays / 30).floor()}mo ago';
  }
}

// ---------------------------------------------------------------------------
// Section header
// ---------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: AppTextStyles.titleMedium
          .copyWith(color: Theme.of(context).colorScheme.onSurface),
    );
  }
}

// ---------------------------------------------------------------------------
// Icon lookup — resolves card ID → const IconData (avoids non-const IconData)
// ---------------------------------------------------------------------------

IconData _iconForCard(String cardId) {
  return switch (cardId) {
    'duplicates'   => Icons.copy_all_rounded,
    'large_videos' => Icons.video_library_rounded,
    'old_media'    => Icons.history_rounded,
    'screenshots'  => Icons.screenshot_outlined,
    _              => Icons.folder_outlined,
  };
}
