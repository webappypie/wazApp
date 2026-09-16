// lib/features/clean/presentation/cleanup_success_screen.dart
//
// Cleanup success screen (REQ-ACT-07):
//   - Shows GB recovered and reviewed/removed/moved counts.
//   - RULE: No interstitial ad covering this screen (REQ-ACT-07, P-06).

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/tokens.dart';
import '../../../core/widgets/buttons.dart';
import '../domain/action_models.dart';
import '../domain/category_models.dart';

class CleanupSuccessScreen extends StatelessWidget {
  const CleanupSuccessScreen({
    super.key,
    required this.summary,
  });

  final CleanupSessionSummary summary;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final formattedRecovered = formatBytes(summary.recoveredBytes);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pagePadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Spacer(flex: 2),

              // Success illustration / icon
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: kColorSuccess.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(
                    Icons.check_circle_outline_rounded,
                    size: 56,
                    color: kColorSuccess,
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.lg),

              Text(
                'Storage Cleaned!',
                style: AppTextStyles.headlineMedium.copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: AppSpacing.xs),

              Text(
                '$formattedRecovered recovered',
                style: AppTextStyles.headlineSmall.copyWith(
                  color: kColorSuccess,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: AppSpacing.xl),

              // Breakdown Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: AppColors.card(context),
                  borderRadius: AppRadius.cardRadius,
                  border: Border.all(color: scheme.outlineVariant),
                ),
                child: Column(
                  children: [
                    _BreakdownRow(
                      label: 'Files Reviewed',
                      value: '${summary.reviewedCount}',
                      icon: Icons.rate_review_outlined,
                    ),
                    const Divider(height: AppSpacing.lg),
                    _BreakdownRow(
                      label: 'Files Removed',
                      value: '${summary.removedCount}',
                      icon: Icons.delete_outline,
                    ),
                    const Divider(height: AppSpacing.lg),
                    _BreakdownRow(
                      label: 'Files Moved / Archived',
                      value: '${summary.movedCount}',
                      icon: Icons.drive_file_move_outlined,
                    ),
                    if (summary.protectedCount > 0) ...[
                      const Divider(height: AppSpacing.lg),
                      _BreakdownRow(
                        label: 'Files Protected',
                        value: '${summary.protectedCount}',
                        icon: Icons.lock_outline,
                      ),
                    ],
                  ],
                ),
              ),

              const Spacer(flex: 3),

              // Action Buttons
              if (summary.removedCount > 0) ...[
                SecondaryButton(
                  label: 'View Recycle Bin',
                  onPressed: () {
                    // Navigate to Bin tab
                    context.go('/bin');
                  },
                ),
                const SizedBox(height: AppSpacing.sm),
              ],

              PrimaryButton(
                label: 'Done',
                onPressed: () {
                  context.go('/home');
                },
              ),

              const SizedBox(height: AppSpacing.md),
            ],
          ),
        ),
      ),
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  const _BreakdownRow({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 20, color: scheme.onSurfaceVariant),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            label,
            style: AppTextStyles.bodyMedium.copyWith(color: scheme.onSurface),
          ),
        ),
        Text(
          value,
          style: AppTextStyles.titleSmall.copyWith(
            fontWeight: FontWeight.bold,
            color: scheme.onSurface,
          ),
        ),
      ],
    );
  }
}
