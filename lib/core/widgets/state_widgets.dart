// lib/core/widgets/state_widgets.dart
//
// EmptyState, ErrorState — displayed when lists have no content or fail.
// Skeleton loaders — list and grid variants shown during loading.
// All text tokens and spacing from design system.

import 'package:flutter/material.dart';

import '../design/tokens.dart';

// ---------------------------------------------------------------------------
// EmptyState
// ---------------------------------------------------------------------------

/// Displayed when a list/grid has no items to show.
///
/// Example: "No duplicates found. Your library looks clean." (PRD §9)
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    required this.body,
    this.icon,
    this.action,
  });

  final String title;
  final String body;
  final IconData? icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: true,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 56,
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.4),
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
              Text(
                title,
                style: AppTextStyles.titleMedium.copyWith(color: scheme.onSurface),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                body,
                style: AppTextStyles.bodyMedium.copyWith(color: scheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
              if (action != null) ...[
                const SizedBox(height: AppSpacing.lg),
                action!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// ErrorState
// ---------------------------------------------------------------------------

/// Displayed when a screen fails to load or an operation fails.
/// Never surfaces a raw exception string (PRD §9 error example).
class ErrorState extends StatelessWidget {
  const ErrorState({
    super.key,
    required this.message,
    this.onRetry,
    this.retryLabel = 'Try again',
  });

  final String message;
  final VoidCallback? onRetry;
  final String retryLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: true,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline_rounded,
                size: 48,
                color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                message,
                style: AppTextStyles.bodyMedium.copyWith(color: scheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
              if (onRetry != null) ...[
                const SizedBox(height: AppSpacing.lg),
                OutlinedButton(
                  onPressed: onRetry,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(120, 44),
                  ),
                  child: Text(retryLabel),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Skeleton loaders
// ---------------------------------------------------------------------------

/// A single shimmer-style skeleton block.
class _SkeletonBlock extends StatefulWidget {
  const _SkeletonBlock({required this.width, required this.height, this.radius = AppRadius.sm});
  final double width;
  final double height;
  final double radius;

  @override
  State<_SkeletonBlock> createState() => _SkeletonBlockState();
}

class _SkeletonBlockState extends State<_SkeletonBlock> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.3, end: 0.7).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, _) => Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: scheme.onSurface.withValues(alpha: _anim.value * 0.12),
          borderRadius: BorderRadius.all(Radius.circular(widget.radius)),
        ),
      ),
    );
  }
}

/// Skeleton loader for a list of [MediaListRow]s.
class SkeletonListLoader extends StatelessWidget {
  const SkeletonListLoader({super.key, this.itemCount = 6});
  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading…',
      child: ListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        itemCount: itemCount,
        padding: EdgeInsets.zero,
        itemBuilder: (_, i) => Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.pagePadding,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              _SkeletonBlock(width: 56, height: 56, radius: AppRadius.sm),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SkeletonBlock(width: double.infinity, height: 14),
                    const SizedBox(height: AppSpacing.sm),
                    _SkeletonBlock(width: 120, height: 12),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Skeleton loader for a grid of [MediaTile]s.
class SkeletonGridLoader extends StatelessWidget {
  const SkeletonGridLoader({
    super.key,
    this.crossAxisCount = 3,
    this.itemCount = 12,
  });
  final int crossAxisCount;
  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading…',
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        itemCount: itemCount,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: AppSpacing.xs,
          mainAxisSpacing: AppSpacing.xs,
        ),
        itemBuilder: (_, _) => _SkeletonBlock(
          width: double.infinity,
          height: double.infinity,
          radius: AppRadius.sm,
        ),
      ),
    );
  }
}
