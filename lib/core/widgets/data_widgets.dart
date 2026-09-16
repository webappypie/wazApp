// lib/core/widgets/data_widgets.dart
//
// Progress ring, progress bar, and a simple bar chart component.
// Used in Home dashboard (Phase 4) and Analytics (Phase 9+).
// All values are from real data — never interpolated or fabricated (P-03).

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../design/tokens.dart';

// ---------------------------------------------------------------------------
// ProgressRing — circular score indicator (Media Health score, REQ-HOM-02)
// ---------------------------------------------------------------------------

/// Circular progress ring for the Media Health score (0–100).
///
/// The score is derived from the deterministic formula in PRD §8.1.
/// Never labels itself "AI score" (P-03, REQ-HOM-02).
class ProgressRing extends StatelessWidget {
  const ProgressRing({
    super.key,
    required this.score,
    this.size = 96,
    this.strokeWidth = 8,
    this.label,
  });

  /// Score 0–100.
  final int score;
  final double size;
  final double strokeWidth;
  final String? label;

  Color _scoreColor(BuildContext context) {
    if (score >= 70) return kColorSuccess;
    if (score >= 40) return kColorWarning;
    return kColorDestructive;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = _scoreColor(context);
    final fraction = (score.clamp(0, 100)) / 100.0;

    return Semantics(
      // Colour alone never signals state (REQ-SET-03); label always carries the value.
      label: label ?? 'Media Health score: $score out of 100',
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _RingPainter(
            fraction: fraction,
            color: color,
            trackColor: scheme.surfaceContainerHighest,
            strokeWidth: strokeWidth,
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$score',
                  style: AppTextStyles.headlineMedium.copyWith(color: scheme.onSurface),
                ),
                if (label != null)
                  Text(
                    label!,
                    style: AppTextStyles.labelSmall.copyWith(color: scheme.onSurfaceVariant),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.fraction,
    required this.color,
    required this.trackColor,
    required this.strokeWidth,
  });

  final double fraction;
  final Color color;
  final Color trackColor;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    const startAngle = -math.pi / 2;

    // Track
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      0,
      2 * math.pi,
      false,
      Paint()
        ..color = trackColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round,
    );

    // Progress arc
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      2 * math.pi * fraction,
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.fraction != fraction || old.color != color;
}

// ---------------------------------------------------------------------------
// AppProgressBar — linear progress bar
// ---------------------------------------------------------------------------

class AppProgressBar extends StatelessWidget {
  const AppProgressBar({
    super.key,
    required this.fraction,
    this.height = 6,
    this.color,
    this.semanticLabel,
  });

  /// 0.0 – 1.0
  final double fraction;
  final double height;
  final Color? color;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: semanticLabel ?? '${(fraction * 100).round()}%',
      child: ClipRRect(
        borderRadius: BorderRadius.all(Radius.circular(height / 2)),
        child: LinearProgressIndicator(
          value: fraction.clamp(0.0, 1.0),
          minHeight: height,
          backgroundColor: scheme.surfaceContainerHighest,
          valueColor: AlwaysStoppedAnimation(color ?? scheme.primary),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// SimpleBarChart — used for storage growth analytics (Phase 4/9+)
// ---------------------------------------------------------------------------

/// A simple vertical bar chart showing relative values.
/// Each bar label and value is shown for accessibility.
/// No gridlines are fabricated; bars only render real data (P-03).
class SimpleBarChart extends StatelessWidget {
  const SimpleBarChart({
    super.key,
    required this.bars,
    this.height = 120,
    this.barColor,
  });

  /// Each entry: (label, value). Values are normalised internally.
  final List<(String, double)> bars;
  final double height;
  final Color? barColor;

  @override
  Widget build(BuildContext context) {
    if (bars.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final color = barColor ?? scheme.primary;
    final maxValue = bars.map((b) => b.$2).reduce(math.max);

    return Semantics(
      label: 'Bar chart with ${bars.length} data points',
      child: SizedBox(
        height: height,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (var i = 0; i < bars.length; i++) ...[
              Expanded(
                child: Semantics(
                  label: '${bars[i].$1}: ${bars[i].$2.toStringAsFixed(1)}',
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Flexible(
                        child: FractionallySizedBox(
                          heightFactor: maxValue > 0 ? (bars[i].$2 / maxValue).clamp(0.02, 1.0) : 0,
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        bars[i].$1,
                        style: AppTextStyles.labelSmall.copyWith(color: scheme.onSurfaceVariant),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
              if (i < bars.length - 1) const SizedBox(width: AppSpacing.xs),
            ],
          ],
        ),
      ),
    );
  }
}
