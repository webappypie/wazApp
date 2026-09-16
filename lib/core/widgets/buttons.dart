// lib/core/widgets/buttons.dart
//
// PrimaryButton and SecondaryButton — all app call-to-action buttons.
// Enforce ≥ 48dp tap targets (REQ-SET-03), token sizing, semantic labels.

import 'package:flutter/material.dart';

import '../design/tokens.dart';

/// Full-width primary CTA button.
///
/// Never place adjacent to or immediately before a destructive action (P-06).
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.icon,
    this.semanticLabel,
    this.width,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final Widget? icon;
  final String? semanticLabel;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: semanticLabel ?? label,
      button: true,
      enabled: onPressed != null && !isLoading,
      child: SizedBox(
        width: width ?? double.infinity,
        height: 52, // ≥ 48dp (REQ-SET-03)
        child: ElevatedButton(
          onPressed: (onPressed != null && !isLoading) ? onPressed : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: scheme.primary,
            foregroundColor: scheme.onPrimary,
            disabledBackgroundColor: scheme.onSurface.withValues(alpha: 0.12),
            shape: const RoundedRectangleBorder(borderRadius: AppRadius.buttonRadius),
            elevation: AppElevation.none,
          ),
          child: isLoading
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: scheme.onPrimary,
                  ),
                )
              : icon != null
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        icon!,
                        const SizedBox(width: AppSpacing.sm),
                        Text(label, style: AppTextStyles.labelLarge),
                      ],
                    )
                  : Text(label, style: AppTextStyles.labelLarge),
        ),
      ),
    );
  }
}

/// Full-width secondary (outlined) button.
class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.icon,
    this.semanticLabel,
    this.width,
    this.isDestructive = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final Widget? icon;
  final String? semanticLabel;
  final double? width;

  /// When true, uses destructive colours (red outline + red text).
  /// Used for "Delete" confirmations.
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fgColor = isDestructive ? kColorDestructive : scheme.primary;

    return Semantics(
      label: semanticLabel ?? label,
      button: true,
      enabled: onPressed != null && !isLoading,
      child: SizedBox(
        width: width ?? double.infinity,
        height: 52,
        child: OutlinedButton(
          onPressed: (onPressed != null && !isLoading) ? onPressed : null,
          style: OutlinedButton.styleFrom(
            foregroundColor: fgColor,
            side: BorderSide(
              color: isDestructive ? kColorDestructive : scheme.outline,
            ),
            shape: const RoundedRectangleBorder(borderRadius: AppRadius.buttonRadius),
          ),
          child: isLoading
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: fgColor),
                )
              : icon != null
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        icon!,
                        const SizedBox(width: AppSpacing.sm),
                        Text(label, style: AppTextStyles.labelLarge.copyWith(color: fgColor)),
                      ],
                    )
                  : Text(label, style: AppTextStyles.labelLarge.copyWith(color: fgColor)),
        ),
      ),
    );
  }
}
