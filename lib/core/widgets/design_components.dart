// lib/core/widgets/design_components.dart
//
// Shared premium components: a tappable AppCard with press-scale, AccentIcon tiles, StatusPill labels,
// SectionTitle headings and a staggered Entrance. Pattern adapted from the Clenzy reference project.

import 'package:flutter/material.dart';

import '../design/tokens.dart';
import '../design/waz_theme.dart';

/// Tappable surface: consistent radius, hairline border, optional gradient/shadow, press-scale.
class AppCard extends StatefulWidget {
  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.radius = AppRadius.xl - 2,
    this.color,
    this.gradient,
    this.elevated = false,
    this.semanticLabel,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? color;
  final Gradient? gradient;
  final bool elevated;
  final String? semanticLabel;

  @override
  State<AppCard> createState() => _AppCardState();
}

class _AppCardState extends State<AppCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(widget.radius);
    final tappable = widget.onTap != null;
    final hero = widget.gradient != null;

    final surface = Ink(
      decoration: BoxDecoration(
        color: hero ? null : (widget.color ?? scheme.surfaceContainerLow),
        gradient: widget.gradient,
        borderRadius: radius,
        border: hero ? null : Border.all(color: scheme.outlineVariant.withValues(alpha: 0.55)),
        boxShadow: widget.elevated ? context.waz.cardShadow : null,
      ),
      child: InkWell(
        borderRadius: radius,
        onTap: widget.onTap,
        onHighlightChanged: tappable ? (v) => setState(() => _pressed = v) : null,
        child: Padding(padding: widget.padding, child: widget.child),
      ),
    );

    return Semantics(
      container: true,
      button: tappable,
      label: widget.semanticLabel,
      child: AnimatedScale(
        scale: _pressed && !AppMotion.reduced(context) ? 0.98 : 1,
        duration: AppMotion.fast,
        curve: AppMotion.standard,
        child: Material(color: Colors.transparent, borderRadius: radius, child: surface),
      ),
    );
  }
}

/// Section heading with an optional trailing widget.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.subtitle, this.trailing});

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(header: true, child: Text(title, style: AppTextStyles.titleMedium)),
              if (subtitle != null)
                Text(subtitle!, style: AppTextStyles.bodySmall.copyWith(color: scheme.onSurfaceVariant)),
            ],
          ),
        ),
        ?trailing,
      ],
    );
  }
}

/// Rounded-square icon on a tinted tile.
class AccentIcon extends StatelessWidget {
  const AccentIcon({super.key, required this.icon, required this.color, this.size = 44});

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(size * 0.32),
        ),
        child: Icon(icon, color: color, size: size * 0.5),
      ),
    );
  }
}

/// Small label that always carries text (never colour alone).
class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.label, required this.color, this.icon, this.onDark = false});

  final String label;
  final Color color;
  final IconData? icon;

  /// On the hero gradient the pill uses a translucent white tile instead of a tinted one.
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final fg = onDark ? context.waz.onHero : color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: onDark ? Colors.white.withValues(alpha: 0.16) : color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 14, color: fg), const SizedBox(width: 4)],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.labelMedium.copyWith(color: fg),
            ),
          ),
        ],
      ),
    );
  }
}

/// Fades and slides its child in once, [index] * 50 ms after the screen appears. No-op with reduced motion.
class Entrance extends StatelessWidget {
  const Entrance({super.key, required this.child, this.index = 0});

  final Widget child;
  final int index;

  @override
  Widget build(BuildContext context) {
    if (AppMotion.reduced(context)) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 320 + index * 50),
      curve: AppMotion.standard,
      builder: (context, t, child) => Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.translate(offset: Offset(0, 14 * (1 - t)), child: child),
      ),
      child: child,
    );
  }
}
