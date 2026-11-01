// lib/core/widgets/status_ring.dart
//
// Segmented circular "status ring": the brand motif of WazApp (original artwork, drawn in code).
// Used by the animated splash and as the source indicator on Home, where the number of segments
// is the real number of statuses found.

import 'dart:math' as math;

import 'package:flutter/material.dart';

class StatusRingPainter extends CustomPainter {
  StatusRingPainter({
    required this.segments,
    required this.color,
    this.trackColor,
    this.progress = 1,
    this.strokeWidth = 4,
    this.gapRadians = 0.22,
  });

  /// Number of arcs (1 draws a full circle).
  final int segments;
  final Color color;

  /// Faint ring drawn behind the arcs (e.g. "no statuses yet"). Null draws nothing behind.
  final Color? trackColor;

  /// 0..1: how much of the ring has been drawn (animated by the splash).
  final double progress;
  final double strokeWidth;
  final double gapRadians;

  @override
  void paint(Canvas canvas, Size size) {
    final rect =
        Offset(strokeWidth / 2, strokeWidth / 2) &
        Size(size.width - strokeWidth, size.height - strokeWidth);
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    if (trackColor != null) {
      canvas.drawArc(rect, 0, math.pi * 2, false, base..color = trackColor!);
    }
    final n = segments.clamp(1, 24);
    final paint = base..color = color;
    if (n == 1) {
      canvas.drawArc(
        rect,
        -math.pi / 2,
        math.pi * 2 * progress.clamp(0, 1),
        false,
        paint,
      );
      return;
    }
    final slot = math.pi * 2 / n;
    final sweep = slot - gapRadians;
    final drawn = math.pi * 2 * progress.clamp(0, 1);
    for (var i = 0; i < n; i++) {
      final start = -math.pi / 2 + i * slot + gapRadians / 2;
      final from = i * slot;
      final visible = (drawn - from).clamp(0, slot);
      if (visible <= 0) break;
      canvas.drawArc(
        rect,
        start,
        math.min(sweep, visible.toDouble()),
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(StatusRingPainter old) =>
      old.segments != segments ||
      old.color != color ||
      old.trackColor != trackColor ||
      old.progress != progress ||
      old.strokeWidth != strokeWidth;
}

/// A circular avatar surrounded by a status ring.
class StatusRing extends StatelessWidget {
  const StatusRing({
    super.key,
    required this.child,
    required this.segments,
    required this.color,
    this.trackColor,
    this.size = 72,
    this.strokeWidth = 4,
    this.progress = 1,
  });

  final Widget child;
  final int segments;
  final Color color;
  final Color? trackColor;
  final double size;
  final double strokeWidth;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: StatusRingPainter(
          segments: segments,
          color: color,
          trackColor: trackColor,
          strokeWidth: strokeWidth,
          progress: progress,
        ),
        child: Padding(
          padding: EdgeInsets.all(strokeWidth + 4),
          child: ClipOval(child: child),
        ),
      ),
    );
  }
}
