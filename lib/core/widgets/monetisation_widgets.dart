// lib/core/widgets/monetisation_widgets.dart
//
// NativeAdContainer — collapses cleanly when empty/disabled (REQ-ADS-08, REQ-HOM-07).
// UpgradeCard — Premium upsell card.
//
// RULES:
// - Ad container collapses to zero size when not ready — no phantom gaps
// - Premium users: no ad container is laid out at all (REQ-HOM-07)
// - Ad must not appear adjacent to destructive actions (REQ-ADS-05)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design/tokens.dart';
import '../di/providers.dart';
import '../services/ads/ad_manager.dart';

// ---------------------------------------------------------------------------
// NativeAdContainer
// ---------------------------------------------------------------------------

/// Container for a native ad unit.
///
/// When [canShow] is false (ad not loaded / ads disabled / Premium user / insufficient content),
/// the widget occupies zero space — no gap, no placeholder box (REQ-ADS-08).
class NativeAdContainer extends ConsumerWidget {
  const NativeAdContainer({
    super.key,
    this.minContentItemsAbove = 0,
    this.minContentItemsRequired = 10, // REQ-ADS-04
    this.placement = AdPlacement.homeSection,
  });

  /// How many real content items are rendered above this widget.
  final int minContentItemsAbove;

  /// Minimum content items that must appear before this ad (REQ-ADS-04).
  final int minContentItemsRequired;

  /// Explicit placement context (REQ-ADS-05).
  final AdPlacement placement;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final adManager = ref.watch(adManagerProvider);

    final canShow = adManager.canShowNativeAd(
      placement: placement,
      minItemsAbove: minContentItemsAbove,
    );

    if (!canShow) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Ad',
                    style: AppTextStyles.labelSmall.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Sponsored Recommendation',
                    style: AppTextStyles.labelMedium.copyWith(color: scheme.outline),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Looking to clean and organize other cloud storage?',
              style: AppTextStyles.titleSmall,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Discover secure and fast tools for your media library.',
              style: AppTextStyles.bodySmall.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// UpgradeCard
// ---------------------------------------------------------------------------

/// Shown to free users to invite them to upgrade to Premium.
/// Never shown to Premium users (guarded by isPremiumProvider).
class UpgradeCard extends ConsumerWidget {
  const UpgradeCard({
    super.key,
    required this.headline,
    required this.body,
    required this.ctaLabel,
    required this.onCta,
  });

  final String headline;
  final String body;
  final String ctaLabel;
  final VoidCallback onCta;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPremium = ref.watch(isPremiumProvider);
    if (isPremium) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.cardPadding),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.workspace_premium_outlined, color: scheme.onPrimaryContainer, size: 28),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    headline,
                    style: AppTextStyles.titleSmall.copyWith(color: scheme.onPrimaryContainer),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    body,
                    style: AppTextStyles.bodySmall.copyWith(color: scheme.onPrimaryContainer),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  SizedBox(
                    height: 36,
                    child: ElevatedButton(
                      onPressed: onCta,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: scheme.primary,
                        foregroundColor: scheme.onPrimary,
                        elevation: AppElevation.none,
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                        shape: const RoundedRectangleBorder(borderRadius: AppRadius.buttonRadius),
                        minimumSize: const Size(80, 36),
                      ),
                      child: Text(ctaLabel, style: AppTextStyles.labelMedium),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
