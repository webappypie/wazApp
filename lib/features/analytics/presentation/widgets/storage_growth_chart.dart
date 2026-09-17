// lib/features/analytics/presentation/widgets/storage_growth_chart.dart
//
// Interactive custom-painted area and line chart for storage growth (REQ-ANL-03).

import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/design/tokens.dart';
import '../../domain/analytics_models.dart';

class StorageGrowthChart extends StatefulWidget {
  const StorageGrowthChart({
    super.key,
    required this.snapshots,
    required this.primaryColor,
    required this.gradientColor,
  });

  final List<StorageSnapshotPoint> snapshots;
  final Color primaryColor;
  final Color gradientColor;

  @override
  State<StorageGrowthChart> createState() => _StorageGrowthChartState();
}

class _StorageGrowthChartState extends State<StorageGrowthChart> {
  int? _scrubIndex;

  String _formatBytes(int bytes) {
    if (bytes >= 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
    return '${(bytes / (1024 * 1024)).round()} MB';
  }

  String _formatDate(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}';
  }

  @override
  Widget build(BuildContext context) {
    if (widget.snapshots.length < 2) {
      return Container(
        height: 220,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: AppRadius.cardRadius,
        ),
        child: Text(
          'Collecting storage history...',
          style: AppTextStyles.bodyMedium.copyWith(color: Theme.of(context).colorScheme.outline),
        ),
      );
    }

    final activeIndex = _scrubIndex ?? widget.snapshots.length - 1;
    final activePoint = widget.snapshots[activeIndex.clamp(0, widget.snapshots.length - 1)];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Active point readout / scrub card
        Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
          decoration: BoxDecoration(
            color: widget.primaryColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppRadius.full),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.timeline, size: 16, color: widget.primaryColor),
              const SizedBox(width: AppSpacing.xs),
              Text(
                '${_formatDate(activePoint.date)}: ${_formatBytes(activePoint.totalBytes)}',
                style: AppTextStyles.labelMedium.copyWith(
                  color: widget.primaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),

        // Interactive chart canvas
        SizedBox(
          height: 200,
          child: LayoutBuilder(
            builder: (context, constraints) {
              return GestureDetector(
                onHorizontalDragStart: (details) => _updateScrub(details.localPosition.dx, constraints.maxWidth),
                onHorizontalDragUpdate: (details) => _updateScrub(details.localPosition.dx, constraints.maxWidth),
                onHorizontalDragEnd: (_) => setState(() => _scrubIndex = null),
                onTapDown: (details) => _updateScrub(details.localPosition.dx, constraints.maxWidth),
                onTapUp: (_) => setState(() => _scrubIndex = null),
                child: CustomPaint(
                  size: Size(constraints.maxWidth, 200),
                  painter: _ChartPainter(
                    snapshots: widget.snapshots,
                    primaryColor: widget.primaryColor,
                    gradientColor: widget.gradientColor,
                    scrubIndex: _scrubIndex,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _updateScrub(double localX, double totalWidth) {
    if (widget.snapshots.length < 2 || totalWidth <= 0) return;
    const paddingLeft = 45.0;
    const paddingRight = 16.0;
    final chartWidth = totalWidth - paddingLeft - paddingRight;

    final ratio = ((localX - paddingLeft) / chartWidth).clamp(0.0, 1.0);
    final idx = (ratio * (widget.snapshots.length - 1)).round();
    setState(() {
      _scrubIndex = idx;
    });
  }
}

class _ChartPainter extends CustomPainter {
  _ChartPainter({
    required this.snapshots,
    required this.primaryColor,
    required this.gradientColor,
    this.scrubIndex,
  });

  final List<StorageSnapshotPoint> snapshots;
  final Color primaryColor;
  final Color gradientColor;
  final int? scrubIndex;

  @override
  void paint(Canvas canvas, Size size) {
    if (snapshots.isEmpty) return;

    const paddingLeft = 45.0;
    const paddingRight = 16.0;
    const paddingTop = 16.0;
    const paddingBottom = 28.0;

    final chartWidth = size.width - paddingLeft - paddingRight;
    final chartHeight = size.height - paddingTop - paddingBottom;

    var minBytes = snapshots.map((s) => s.totalBytes).reduce(math.min);
    var maxBytes = snapshots.map((s) => s.totalBytes).reduce(math.max);

    // Padding headroom
    if (maxBytes == minBytes) {
      maxBytes += 1024 * 1024 * 100; // +100MB
      minBytes = math.max(0, minBytes - 1024 * 1024 * 100);
    } else {
      final range = maxBytes - minBytes;
      maxBytes += (range * 0.1).round();
      minBytes = math.max(0, minBytes - (range * 0.05).round());
    }

    // Grid lines & Y-axis labels
    final gridPaint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.2)
      ..strokeWidth = 1.0;

    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    const gridLines = 3;
    for (int i = 0; i <= gridLines; i++) {
      final y = paddingTop + chartHeight - (i * chartHeight / gridLines);
      canvas.drawLine(Offset(paddingLeft, y), Offset(size.width - paddingRight, y), gridPaint);

      final val = minBytes + ((maxBytes - minBytes) * i / gridLines).round();
      final label = _formatBytes(val);

      textPainter.text = TextSpan(
        text: label,
        style: const TextStyle(color: Colors.grey, fontSize: 10),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(paddingLeft - textPainter.width - 6, y - textPainter.height / 2));
    }

    // Line & Area Path
    final linePath = Path();
    final areaPath = Path();

    Offset pointToOffset(int index, StorageSnapshotPoint point) {
      final x = paddingLeft + (index / (snapshots.length - 1)) * chartWidth;
      final yRatio = (point.totalBytes - minBytes) / (maxBytes - minBytes);
      final y = paddingTop + chartHeight - (yRatio * chartHeight);
      return Offset(x, y);
    }

    final firstOffset = pointToOffset(0, snapshots.first);
    linePath.moveTo(firstOffset.dx, firstOffset.dy);
    areaPath.moveTo(firstOffset.dx, paddingTop + chartHeight);
    areaPath.lineTo(firstOffset.dx, firstOffset.dy);

    for (int i = 1; i < snapshots.length; i++) {
      final prev = pointToOffset(i - 1, snapshots[i - 1]);
      final curr = pointToOffset(i, snapshots[i]);

      final controlX = (prev.dx + curr.dx) / 2;
      linePath.cubicTo(controlX, prev.dy, controlX, curr.dy, curr.dx, curr.dy);
      areaPath.cubicTo(controlX, prev.dy, controlX, curr.dy, curr.dx, curr.dy);
    }

    final lastOffset = pointToOffset(snapshots.length - 1, snapshots.last);
    areaPath.lineTo(lastOffset.dx, paddingTop + chartHeight);
    areaPath.close();

    // Draw gradient area fill
    final areaPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          primaryColor.withValues(alpha: 0.35),
          primaryColor.withValues(alpha: 0.0),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(paddingLeft, paddingTop, chartWidth, chartHeight));

    canvas.drawPath(areaPath, areaPaint);

    // Draw stroke line
    final strokePaint = Paint()
      ..color = primaryColor
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    canvas.drawPath(linePath, strokePaint);

    // Draw indicator dot on active/scrubbed point
    final activeIdx = scrubIndex ?? snapshots.length - 1;
    final activeOffset = pointToOffset(activeIdx, snapshots[activeIdx]);

    final dotGlow = Paint()..color = primaryColor.withValues(alpha: 0.3);
    canvas.drawCircle(activeOffset, 8, dotGlow);

    final dotPaint = Paint()..color = primaryColor;
    canvas.drawCircle(activeOffset, 4, dotPaint);

    final innerDot = Paint()..color = Colors.white;
    canvas.drawCircle(activeOffset, 2, innerDot);

    // If scrubbing, draw vertical guide line
    if (scrubIndex != null) {
      final guidePaint = Paint()
        ..color = primaryColor.withValues(alpha: 0.5)
        ..strokeWidth = 1.0
        ..style = PaintingStyle.stroke;
      canvas.drawLine(
        Offset(activeOffset.dx, paddingTop),
        Offset(activeOffset.dx, paddingTop + chartHeight),
        guidePaint,
      );
    }

    // X-axis date labels (start, mid, end)
    void drawXLabel(int idx, Alignment alignment) {
      if (idx < 0 || idx >= snapshots.length) return;
      final pt = snapshots[idx];
      final pos = pointToOffset(idx, pt);
      final label = '/';

      textPainter.text = TextSpan(
        text: label,
        style: const TextStyle(color: Colors.grey, fontSize: 10),
      );
      textPainter.layout();

      double dx = pos.dx;
      if (alignment == Alignment.centerLeft) {
        dx = pos.dx;
      } else if (alignment == Alignment.centerRight) {
        dx = pos.dx - textPainter.width;
      } else {
        dx = pos.dx - (textPainter.width / 2);
      }

      textPainter.paint(canvas, Offset(dx, paddingTop + chartHeight + 8));
    }

    drawXLabel(0, Alignment.centerLeft);
    if (snapshots.length >= 3) {
      drawXLabel(snapshots.length ~/ 2, Alignment.center);
    }
    drawXLabel(snapshots.length - 1, Alignment.centerRight);
  }

  String _formatBytes(int bytes) {
    if (bytes >= 1024 * 1024 * 1024) {
      return ' GB';
    }
    return ' MB';
  }

  @override
  bool shouldRepaint(covariant _ChartPainter oldDelegate) {
    return oldDelegate.snapshots != snapshots ||
        oldDelegate.primaryColor != primaryColor ||
        oldDelegate.scrubIndex != scrubIndex;
  }
}
