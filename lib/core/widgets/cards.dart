// lib/core/widgets/cards.dart
//
// StorageCard, StatCard, CategoryCard — data display cards.
// No hardcoded sizes. Semantic labels for accessibility (REQ-SET-03).

import 'package:flutter/material.dart';

import '../design/tokens.dart';

// ---------------------------------------------------------------------------
// StorageCard — hero card on Home (REQ-HOM-01)
// ---------------------------------------------------------------------------

/// The primary hero card showing total storage, recoverable size, and a CTA.
/// Populated by Phase 4; Phase 1 provides the visual shell.
class StorageCard extends StatelessWidget {
  const StorageCard({
    super.key,
    required this.totalLabel,
    required this.recoverableLabel,
    required this.ctaLabel,
    required this.onCta,
    this.deltaLabel,
    this.isLoading = false,
  });

  final String totalLabel;
  final String recoverableLabel;
  final String? deltaLabel;
  final String ctaLabel;
  final VoidCallback onCta;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Chat Media', style: AppTextStyles.labelMedium.copyWith(color: scheme.onSurfaceVariant)),
            const SizedBox(height: AppSpacing.xs),
            Text(
              totalLabel,
              style: AppTextStyles.displaySmall.copyWith(color: scheme.onSurface),
            ),
            if (deltaLabel != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                deltaLabel!,
                style: AppTextStyles.bodySmall.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            _RecoverableRow(label: recoverableLabel, scheme: scheme),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: onCta,
                style: ElevatedButton.styleFrom(
                  backgroundColor: scheme.primary,
                  foregroundColor: scheme.onPrimary,
                  elevation: AppElevation.none,
                  shape: const RoundedRectangleBorder(borderRadius: AppRadius.buttonRadius),
                ),
                child: Text(ctaLabel, style: AppTextStyles.labelLarge),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecoverableRow extends StatelessWidget {
  const _RecoverableRow({required this.label, required this.scheme});
  final String label;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.savings_outlined, size: 16, color: kColorSuccess),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Text(
            '$label potentially recoverable',
            style: AppTextStyles.bodySmall.copyWith(color: kColorSuccess),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// StatCard — compact metric tile (e.g. file count, total size)
// ---------------------------------------------------------------------------

class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.semanticLabel,
  });

  final String label;
  final String value;
  final IconData? icon;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: semanticLabel ?? '$label: $value',
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20, color: scheme.primary),
                const SizedBox(height: AppSpacing.sm),
              ],
              Text(
                value,
                style: AppTextStyles.titleLarge.copyWith(color: scheme.onSurface),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                label,
                style: AppTextStyles.bodySmall.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// CategoryCard — cleanup opportunity card (REQ-HOM-03)
// ---------------------------------------------------------------------------

class CategoryCard extends StatelessWidget {
  const CategoryCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.previewWidgets,
    this.semanticLabel,
  });

  final IconData icon;
  final String title;
  final String subtitle; // e.g. "342 files • 1.8 GB"
  final VoidCallback onTap;
  final List<Widget>? previewWidgets; // small thumbnails — optional collage
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: semanticLabel ?? '$title. $subtitle',
      button: true,
      child: Card(
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.cardRadius,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.cardPadding),
            child: Row(
              children: [
                _CategoryIcon(icon: icon, scheme: scheme),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: AppTextStyles.titleSmall.copyWith(color: scheme.onSurface)),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        subtitle,
                        style: AppTextStyles.bodySmall.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                if (previewWidgets != null) ...[
                  const SizedBox(width: AppSpacing.sm),
                  ...previewWidgets!.take(3),
                ],
                const SizedBox(width: AppSpacing.sm),
                Icon(Icons.chevron_right, color: scheme.onSurfaceVariant, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryIcon extends StatelessWidget {
  const _CategoryIcon({required this.icon, required this.scheme});
  final IconData icon;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: const BorderRadius.all(Radius.circular(AppRadius.md)),
      ),
      child: Icon(icon, size: 22, color: scheme.onPrimaryContainer),
    );
  }
}
