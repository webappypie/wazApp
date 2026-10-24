// lib/core/widgets/media_tile.dart
//
// Shared grid tile used by the status grid and the saved library.

import 'package:flutter/material.dart';

import '../design/tokens.dart';
import '../format.dart';

class MediaTile extends StatelessWidget {
  const MediaTile({
    super.key,
    required this.child,
    required this.semanticLabel,
    this.isVideo = false,
    this.duration,
    this.selected = false,
    this.selectionMode = false,
    this.favourite = false,
    this.saved = false,
    this.onTap,
    this.onLongPress,
    this.trailingAction,
  });

  /// The thumbnail content (already cropped to cover the tile).
  final Widget child;
  final String semanticLabel;
  final bool isVideo;
  final Duration? duration;
  final bool selected;
  final bool selectionMode;
  final bool favourite;

  /// Shows a "Saved" marker (status already in the library).
  final bool saved;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// Optional quick action shown bottom-right when not selecting (e.g. save).
  final Widget? trailingAction;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: semanticLabel,
      button: true,
      selected: selected,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: scheme.surfaceContainerHighest, child: child),
            Positioned.fill(
              child: Material(
                type: MaterialType.transparency,
                child: InkWell(onTap: onTap, onLongPress: onLongPress),
              ),
            ),
            // Decorations never intercept taps; only the optional action button does.
            Positioned.fill(
              child: IgnorePointer(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (isVideo)
                      Positioned(
                        left: AppSpacing.xs,
                        bottom: AppSpacing.xs,
                        child: _Pill(
                          icon: Icons.play_arrow_rounded,
                          label: duration == null || duration == Duration.zero ? null : formatDuration(duration!),
                        ),
                      ),
                    if (favourite)
                      const Positioned(
                        right: AppSpacing.xs,
                        top: AppSpacing.xs,
                        child: Icon(Icons.favorite, size: 18, color: Colors.white, shadows: [
                          Shadow(blurRadius: 4, color: Colors.black54),
                        ]),
                      ),
                    if (saved && !selectionMode)
                      const Positioned(
                        left: AppSpacing.xs,
                        top: AppSpacing.xs,
                        child: _Pill(icon: Icons.check_circle, label: 'Saved', color: kBrandAccent),
                      ),
                    if (selected) ColoredBox(color: scheme.primary.withValues(alpha: 0.25)),
                    if (selectionMode)
                      Positioned(
                        right: AppSpacing.xs,
                        top: AppSpacing.xs,
                        child: Icon(
                          selected ? Icons.check_circle : Icons.radio_button_unchecked,
                          color: selected ? scheme.primary : Colors.white,
                          shadows: const [Shadow(blurRadius: 4, color: Colors.black54)],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (trailingAction != null && !selectionMode)
              Positioned(right: 2, bottom: 2, child: trailingAction!),
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, this.label, this.color});
  final IconData icon;
  final String? label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color ?? Colors.white),
            if (label != null) ...[
              const SizedBox(width: 2),
              Text(label!, style: AppTextStyles.labelSmall.copyWith(color: Colors.white)),
            ],
          ],
        ),
      ),
    );
  }
}
