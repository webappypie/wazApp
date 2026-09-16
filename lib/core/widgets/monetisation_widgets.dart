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

// ---------------------------------------------------------------------------
// NativeAdContainer
// ---------------------------------------------------------------------------

/// Placeholder container for a native ad unit.
///
/// Phase 8: replace [child] with the real AdMob native ad widget.
/// When [isReady] is false (ad not loaded / ads disabled / Premium user),
/// the widget occupies zero space — no gap, no placeholder box (REQ-ADS-08).
class NativeAdContainer extends ConsumerWidget {
  const NativeAdContainer({
    super.key,
    this.minContentItemsAbove = 0,
    this.minContentItemsRequired = 10, // REQ-ADS-04
  });

  /// How many real content items are rendered above this widget.
  final int minContentItemsAbove;

  /// Minimum content items that must appear before this ad (REQ-ADS-04).
  final int minContentItemsRequired;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPremium = ref.watch(isPremiumProvider);

    // Premium users: no ad container laid out at all (REQ-HOM-07)
    if (isPremium) return const SizedBox.shrink();

    // Not enough real content above this ad — don't show (REQ-ADS-04)
    if (minContentItemsAbove < minContentItemsRequired) return const SizedBox.shrink();

    // Phase 0–7: stub — no ad shown, zero space.
    // Phase 8: replace this with the real native ad widget.
    return const SizedBox.shrink();
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
