// lib/features/clean/presentation/widgets/swipe_card.dart
//
// Interactive gesture-driven card with physics, rotation, and action overlays (REQ-ACT-08, REQ-SWP-01).
//
// RULES:
//   - REQ-ACT-08: Left delete, right keep, up archive, tap preview.
//   - Visual badges appear dynamically with drag intensity.

import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../../core/design/tokens.dart';
import '../../domain/category_models.dart';
import '../../domain/swipe_clean_models.dart';

class SwipeCard extends StatefulWidget {
  const SwipeCard({
    super.key,
    required this.item,
    required this.onSwipe,
    required this.onTap,
    this.isTop = true,
  });

  final CategoryItem item;
  final void Function(SwipeAction action) onSwipe;
  final VoidCallback onTap;
  final bool isTop;

  @override
  State<SwipeCard> createState() => _SwipeCardState();
}

class _SwipeCardState extends State<SwipeCard>
    with SingleTickerProviderStateMixin {
  Offset _dragOffset = Offset.zero;
  late AnimationController _springController;
  late Animation<Offset> _springAnimation;

  static const double _horizontalSwipeThreshold = 100.0;
  static const double _verticalSwipeThreshold = -120.0; // Upward drag

  @override
  void initState() {
    super.initState();
    _springController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    )..addListener(() {
        setState(() {
          _dragOffset = _springAnimation.value;
        });
      });
  }

  @override
  void dispose() {
    _springController.dispose();
    super.dispose();
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (!widget.isTop) return;
    setState(() {
      _dragOffset += details.delta;
    });
  }

  void _onPanEnd(DragEndDetails details) {
    if (!widget.isTop) return;

    if (_dragOffset.dx < -_horizontalSwipeThreshold) {
      widget.onSwipe(SwipeAction.delete);
    } else if (_dragOffset.dx > _horizontalSwipeThreshold) {
      widget.onSwipe(SwipeAction.keep);
    } else if (_dragOffset.dy < _verticalSwipeThreshold) {
      widget.onSwipe(SwipeAction.archive);
    } else {
      // Snap back to center
      _springAnimation = Tween<Offset>(
        begin: _dragOffset,
        end: Offset.zero,
      ).animate(
        CurvedAnimation(parent: _springController, curve: Curves.easeOutBack),
      );
      _springController.forward(from: 0.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    // Calculate rotation and overlay opacities based on drag
    final rotationAngle = (_dragOffset.dx / 600.0) * (math.pi / 12);
    final deleteOpacity = (-_dragOffset.dx / _horizontalSwipeThreshold).clamp(0.0, 1.0);
    final keepOpacity = (_dragOffset.dx / _horizontalSwipeThreshold).clamp(0.0, 1.0);
    final archiveOpacity = (-_dragOffset.dy / (-_verticalSwipeThreshold)).clamp(0.0, 1.0);

    return Transform.translate(
      offset: _dragOffset,
      child: Transform.rotate(
        angle: rotationAngle,
        child: GestureDetector(
          onPanUpdate: _onPanUpdate,
          onPanEnd: _onPanEnd,
          onTap: widget.onTap,
          child: Material(
            elevation: widget.isTop ? 6 : 2,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            clipBehavior: Clip.antiAlias,
            color: scheme.surfaceContainerHighest,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Media preview / thumbnail
                _buildCardMedia(scheme),

                // Gradient scrim at bottom for text readability
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: 120,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.8),
                        ],
                      ),
                    ),
                  ),
                ),

                // File metadata details
                Positioned(
                  left: AppSpacing.md,
                  right: AppSpacing.md,
                  bottom: AppSpacing.md,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Icon(
                            widget.item.isVideo
                                ? Icons.videocam_rounded
                                : Icons.image_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Text(
                            widget.item.formattedSize,
                            style: AppTextStyles.labelLarge.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (widget.item.formattedDuration != null) ...[
                            const SizedBox(width: AppSpacing.sm),
                            Text(
                              '• ${widget.item.formattedDuration}',
                              style: AppTextStyles.labelMedium.copyWith(
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.item.displayName,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                // Overlays: DELETE (Left drag)
                if (deleteOpacity > 0.05)
                  Positioned(
                    top: AppSpacing.lg,
                    right: AppSpacing.lg,
                    child: Opacity(
                      opacity: deleteOpacity,
                      child: _buildBadge(
                        label: 'DELETE',
                        color: kColorDestructive,
                        icon: Icons.delete_outline_rounded,
                      ),
                    ),
                  ),

                // Overlays: KEEP (Right drag)
                if (keepOpacity > 0.05)
                  Positioned(
                    top: AppSpacing.lg,
                    left: AppSpacing.lg,
                    child: Opacity(
                      opacity: keepOpacity,
                      child: _buildBadge(
                        label: 'KEEP',
                        color: kColorSuccess,
                        icon: Icons.favorite_rounded,
                      ),
                    ),
                  ),

                // Overlays: ARCHIVE (Up drag)
                if (archiveOpacity > 0.05)
                  Positioned(
                    top: AppSpacing.lg,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Opacity(
                        opacity: archiveOpacity,
                        child: _buildBadge(
                          label: 'ARCHIVE',
                          color: Colors.blueAccent,
                          icon: Icons.archive_outlined,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCardMedia(ColorScheme scheme) {
    if (widget.item.thumbnailProvider != null) {
      return Image(
        image: widget.item.thumbnailProvider!,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _buildFallbackMedia(scheme),
      );
    }
    return _buildFallbackMedia(scheme);
  }

  Widget _buildFallbackMedia(ColorScheme scheme) {
    return Container(
      color: scheme.surfaceContainerHigh,
      child: Center(
        child: Icon(
          widget.item.isVideo
              ? Icons.videocam_outlined
              : Icons.image_outlined,
          size: 72,
          color: scheme.onSurfaceVariant.withValues(alpha: 0.4),
        ),
      ),
    );
  }

  Widget _buildBadge({
    required String label,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(width: AppSpacing.xs),
          Text(
            label,
            style: AppTextStyles.titleMedium.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}
