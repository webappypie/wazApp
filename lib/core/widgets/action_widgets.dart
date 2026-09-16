// lib/core/widgets/action_widgets.dart
//
// BottomActionBar — persistent action bar at the bottom of category screens.
// ConfirmationSheet — modal sheet required before any destructive action (P-02).
//
// RULE: No ad may be placed adjacent to or immediately before any of these
// components (P-06, REQ-ADS-05). This is enforced at the call sites in Phase 7.

import 'package:flutter/material.dart';

import '../design/tokens.dart';
import 'buttons.dart';

// ---------------------------------------------------------------------------
// BottomActionBar
// ---------------------------------------------------------------------------

/// The persistent multi-select action bar shown at the bottom of category screens.
///
/// Actions: Move, Copy, Protect, Delete (REQ-CLN-01).
/// Disabled when selection is empty.
/// Delete button uses destructive styling — never placed beside an ad (P-06).
class BottomActionBar extends StatelessWidget {
  const BottomActionBar({
    super.key,
    required this.selectionCount,
    required this.selectionSizeLabel,
    this.onMove,
    this.onCopy,
    this.onProtect,
    this.onDelete,
    this.isProtected = false,
  });

  final int selectionCount;
  final String selectionSizeLabel; // e.g. "12 items • 1.4 GB"
  final VoidCallback? onMove;
  final VoidCallback? onCopy;
  final VoidCallback? onProtect;
  final VoidCallback? onDelete;
  final bool isProtected; // if true, show Unprotect instead of Protect

  bool get _hasSelection => selectionCount > 0;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.card(context),
          border: Border(top: BorderSide(color: scheme.outlineVariant)),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.pagePadding,
          vertical: AppSpacing.sm,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Running selection total
            if (_hasSelection) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Text(
                  selectionSizeLabel,
                  style: AppTextStyles.labelMedium.copyWith(color: scheme.onSurfaceVariant),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
            // Action buttons row
            Row(
              children: [
                _ActionButton(
                  icon: Icons.drive_file_move_outline,
                  label: 'Move',
                  enabled: _hasSelection,
                  onTap: onMove,
                ),
                _ActionButton(
                  icon: Icons.copy_outlined,
                  label: 'Copy',
                  enabled: _hasSelection,
                  onTap: onCopy,
                ),
                _ActionButton(
                  icon: isProtected ? Icons.lock_open_outlined : Icons.lock_outline,
                  label: isProtected ? 'Unprotect' : 'Protect',
                  enabled: _hasSelection,
                  onTap: onProtect,
                ),
                _ActionButton(
                  icon: Icons.delete_outline,
                  label: 'Delete',
                  enabled: _hasSelection,
                  onTap: onDelete,
                  isDestructive: true,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.enabled,
    this.onTap,
    this.isDestructive = false,
  });

  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback? onTap;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = !enabled
        ? scheme.onSurface.withValues(alpha: 0.38)
        : isDestructive
            ? kColorDestructive
            : scheme.onSurface;

    return Expanded(
      child: Semantics(
        button: true,
        enabled: enabled,
        label: label,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: const BorderRadius.all(Radius.circular(AppRadius.md)),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 22, color: color),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  label,
                  style: AppTextStyles.labelSmall.copyWith(color: color),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// ConfirmationSheet
// ---------------------------------------------------------------------------

/// Modal bottom sheet shown before any destructive action (P-02, REQ-ACT-02).
///
/// Shows: item count, total size, destination (trash vs permanent).
/// The confirm button uses destructive styling.
///
/// RULE: This sheet must never contain or be immediately preceded by an ad
/// (P-06, REQ-ADS-05). Callers are responsible for this; this widget does not
/// render an ad container.
class ConfirmationSheet extends StatelessWidget {
  const ConfirmationSheet({
    super.key,
    required this.title,
    required this.body,
    required this.confirmLabel,
    required this.onConfirm,
    this.onCancel,
    this.isDestructive = true,
  });

  final String title;
  final String body;
  final String confirmLabel;
  final VoidCallback onConfirm;
  final VoidCallback? onCancel;
  final bool isDestructive;

  /// Show this sheet as a modal bottom sheet.
  static Future<bool?> show(
    BuildContext context, {
    required String title,
    required String body,
    required String confirmLabel,
    bool isDestructive = true,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.bottomSheetRadius),
      builder: (_) => ConfirmationSheet(
        title: title,
        body: body,
        confirmLabel: confirmLabel,
        isDestructive: isDestructive,
        onConfirm: () => Navigator.of(context).pop(true),
        onCancel: () => Navigator.of(context).pop(false),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.pagePadding,
          AppSpacing.lg,
          AppSpacing.pagePadding,
          AppSpacing.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: scheme.outlineVariant,
                  borderRadius: const BorderRadius.all(Radius.circular(2)),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(title, style: AppTextStyles.titleLarge.copyWith(color: scheme.onSurface)),
            const SizedBox(height: AppSpacing.sm),
            Text(body, style: AppTextStyles.bodyMedium.copyWith(color: scheme.onSurfaceVariant)),
            const SizedBox(height: AppSpacing.xl),
            SecondaryButton(
              label: confirmLabel,
              onPressed: onConfirm,
              isDestructive: isDestructive,
            ),
            const SizedBox(height: AppSpacing.sm),
            SecondaryButton(
              label: 'Cancel',
              onPressed: onCancel ?? () => Navigator.of(context).pop(false),
            ),
          ],
        ),
      ),
    );
  }
}
