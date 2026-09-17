// lib/core/widgets/media_tiles.dart
//
// MediaTile (grid item) and MediaListRow (list item).
// Used in all category screens. No hardcoded sizes.

import 'package:flutter/material.dart';

import '../design/tokens.dart';

// ---------------------------------------------------------------------------
// MediaTile — grid item for image/video thumbnails
// ---------------------------------------------------------------------------

/// A grid thumbnail tile for a media file.
///
/// [isSelected] drives the selection indicator.
/// Tapping an unselected item opens preview; tapping a selected item deselects.
/// Full-res images are NEVER decoded for thumbnails (PRD §5.5 performance rule).
class MediaTile extends StatelessWidget {
  const MediaTile({
    super.key,
    required this.thumbnailProvider,
    required this.isSelected,
    required this.onTap,
    required this.onLongPress,
    this.durationLabel,
    this.sizeLabel,
    this.isProtected = false,
    this.isVideo = false,
    this.badgeLabel,
    this.semanticLabel,
  });

  final ImageProvider thumbnailProvider;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final String? durationLabel; // e.g. "05:42"
  final String? sizeLabel;     // e.g. "624 MB"
  final bool isProtected;
  final bool isVideo;
  final String? badgeLabel;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: semanticLabel ?? (isSelected ? 'Selected media item' : 'Media item'),
      selected: isSelected,
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        child: ClipRRect(
          borderRadius: const BorderRadius.all(Radius.circular(AppRadius.sm)),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Thumbnail — never full-res (PRD §5.5)
              Image(image: thumbnailProvider, fit: BoxFit.cover),

              // Video overlay
              if (isVideo && durationLabel != null)
                Positioned(
                  bottom: AppSpacing.xs,
                  left: AppSpacing.xs,
                  child: _VideoChip(label: durationLabel!),
                ),

              // Badge label (e.g. "Original", "Duplicate")
              if (badgeLabel != null)
                Positioned(
                  top: AppSpacing.xs,
                  left: AppSpacing.xs,
                  child: _BadgeChip(
                    label: badgeLabel!,
                    isPrimary: badgeLabel == 'Original',
                  ),
                ),

              // Protected badge
              if (isProtected)
                Positioned(
                  top: AppSpacing.xs,
                  right: AppSpacing.xs,
                  child: _ProtectedBadge(scheme: scheme),
                ),

              // Selection overlay
              if (isSelected)
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.35),
                  ),
                  child: Center(
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: scheme.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(Icons.check, size: 16, color: Colors.white),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VideoChip extends StatelessWidget {
  const _VideoChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: const BorderRadius.all(Radius.circular(4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.play_arrow, size: 12, color: Colors.white),
          const SizedBox(width: 2),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 11)),
        ],
      ),
    );
  }
}

class _ProtectedBadge extends StatelessWidget {
  const _ProtectedBadge({required this.scheme});
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
      child: Icon(Icons.lock_outline, size: 12, color: scheme.primary),
    );
  }
}

class _BadgeChip extends StatelessWidget {
  const _BadgeChip({required this.label, this.isPrimary = false});
  final String label;
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isPrimary ? kColorSuccess : Colors.black87,
        borderRadius: const BorderRadius.all(Radius.circular(4)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}


// ---------------------------------------------------------------------------
// MediaListRow — list item (used when grid/list toggled to list)
// ---------------------------------------------------------------------------

class MediaListRow extends StatelessWidget {
  const MediaListRow({
    super.key,
    required this.thumbnailProvider,
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
    required this.onLongPress,
    this.leading,
    this.trailing,
    this.isProtected = false,
    this.semanticLabel,
  });

  final ImageProvider thumbnailProvider;
  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final Widget? leading;
  final Widget? trailing;
  final bool isProtected;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: semanticLabel ?? '$title. $subtitle',
      selected: isSelected,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.pagePadding,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              // Selection checkbox or thumbnail
              SizedBox(
                width: 56,
                height: 56,
                child: Stack(
                  children: [
                    if (leading != null)
                      leading!
                    else
                      ClipRRect(
                        borderRadius: const BorderRadius.all(Radius.circular(AppRadius.sm)),
                        child: Image(
                          image: thumbnailProvider,
                          width: 56,
                          height: 56,
                          fit: BoxFit.cover,
                        ),
                      ),
                    if (isSelected)
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: scheme.primary.withValues(alpha: 0.4),
                            borderRadius: const BorderRadius.all(Radius.circular(AppRadius.sm)),
                          ),
                          child: const Center(
                            child: Icon(Icons.check_circle, color: Colors.white, size: 24),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (isProtected) ...[
                          Icon(Icons.lock_outline, size: 14, color: scheme.primary),
                          const SizedBox(width: AppSpacing.xs),
                        ],
                        Expanded(
                          child: Text(
                            title,
                            style: AppTextStyles.bodyMedium.copyWith(color: scheme.onSurface),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      subtitle,
                      style: AppTextStyles.bodySmall.copyWith(color: scheme.onSurfaceVariant),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: AppSpacing.sm),
                trailing!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
