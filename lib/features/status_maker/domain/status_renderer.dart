// lib/features/status_maker/domain/status_renderer.dart
//
// Draws a text status (background, pattern, frame, text) with dart:ui. The same
// routine paints the on-screen preview and the exported 1080x1920 image.
// Text is shaped by the engine's HarfBuzz, so Devanagari conjuncts and matras
// render correctly when a Devanagari-capable font is available (bundled Hind).

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:equatable/equatable.dart';
import 'package:flutter/painting.dart';

import '../../editor/domain/edit_state.dart';
import 'status_templates.dart';

/// Longest message the maker accepts; every template is guaranteed to fit this on one canvas.
const int kMaxStatusChars = 300;

/// Export size of a status image (9:16).
const ui.Size kStatusExportSize = ui.Size(1080, 1920);

/// The user's choices for one status. Null overrides inherit from the template.
class StatusDraft extends Equatable {
  const StatusDraft({
    required this.templateId,
    required this.text,
    this.fontKey,
    this.sizeFrac,
    this.textColor,
    this.align,
    this.bold,
    this.shadow,
  });

  final String templateId;
  final String text;
  final String? fontKey;
  final double? sizeFrac;
  final int? textColor;
  final OverlayAlign? align;
  final bool? bold;
  final bool? shadow;

  StatusTemplate get template => templateById(templateId);

  StatusDraft copyWith({
    String? templateId,
    String? text,
    String? fontKey,
    double? sizeFrac,
    int? textColor,
    OverlayAlign? align,
    bool? bold,
    bool? shadow,
    bool clearOverrides = false,
  }) =>
      StatusDraft(
        templateId: templateId ?? this.templateId,
        text: text ?? this.text,
        fontKey: clearOverrides ? null : (fontKey ?? this.fontKey),
        sizeFrac: clearOverrides ? null : (sizeFrac ?? this.sizeFrac),
        textColor: clearOverrides ? null : (textColor ?? this.textColor),
        align: clearOverrides ? null : (align ?? this.align),
        bold: clearOverrides ? null : (bold ?? this.bold),
        shadow: clearOverrides ? null : (shadow ?? this.shadow),
      );

  @override
  List<Object?> get props => [templateId, text, fontKey, sizeFrac, textColor, align, bold, shadow];
}

/// Result of laying out the status text for a canvas width.
class StatusTextLayout {
  StatusTextLayout(this.painter, this.fontSize, this.fitted);
  final TextPainter painter;
  final double fontSize;

  /// False only if even the minimum size could not fit (extremely long text).
  final bool fitted;
}

/// Lays out [draft]'s text, shrinking it until it fits the safe area (no clipping).
StatusTextLayout layoutStatusText(StatusDraft d, ui.Size size) {
  final t = d.template;
  final font = fontByKey(d.fontKey ?? t.fontKey);
  final align = d.align ?? t.align;
  final bold = d.bold ?? t.bold;
  final shadow = d.shadow ?? t.shadow;
  final color = ui.Color(d.textColor ?? t.textColor);
  final maxWidth = size.width * 0.8;
  final maxHeight = size.height * 0.68;
  final minSize = size.width * 0.03;

  var fontSize = (d.sizeFrac ?? t.sizeFrac) * size.width;
  TextPainter build(double fs) => TextPainter(
        text: TextSpan(
          text: d.text,
          style: TextStyle(
            fontFamily: font.family,
            fontFamilyFallback: const [kDevanagariFallbackFamily],
            fontSize: fs,
            height: containsDevanagari(d.text) ? 1.45 : 1.3, // matras above/below need extra leading
            fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
            color: color,
            shadows: shadow
                ? [Shadow(color: const ui.Color(0x99000000), blurRadius: fs * 0.14, offset: Offset(0, fs * 0.06))]
                : null,
          ),
        ),
        textAlign: switch (align) {
          OverlayAlign.left => TextAlign.left,
          OverlayAlign.center => TextAlign.center,
          OverlayAlign.right => TextAlign.right,
        },
        textDirection: TextDirection.ltr,
      )..layout(minWidth: maxWidth, maxWidth: maxWidth);

  var tp = build(fontSize);
  var guard = 0;
  while (tp.height > maxHeight && fontSize > minSize && guard++ < 60) {
    tp.dispose();
    fontSize *= 0.94;
    tp = build(fontSize);
  }
  return StatusTextLayout(tp, fontSize, tp.height <= maxHeight);
}

void paintStatus(ui.Canvas canvas, ui.Size size, StatusDraft d) {
  final t = d.template;
  final rect = ui.Offset.zero & size;
  canvas.save();
  canvas.clipRect(rect);
  _paintBackground(canvas, size, t);
  _paintPattern(canvas, size, t);
  _paintFrame(canvas, size, t);

  final layout = layoutStatusText(d, size);
  final tp = layout.painter;
  final dx = size.width * 0.1;
  final dy = (size.height - tp.height) / 2;
  tp.paint(canvas, Offset(dx, dy));
  tp.dispose();
  canvas.restore();
}

Future<ui.Image> renderStatusImage(StatusDraft d, {ui.Size size = kStatusExportSize}) {
  final recorder = ui.PictureRecorder();
  paintStatus(ui.Canvas(recorder), size, d);
  final picture = recorder.endRecording();
  final image = picture.toImage(size.width.round(), size.height.round());
  picture.dispose();
  return image;
}

// -----------------------------------------------------------------------------

void _paintBackground(ui.Canvas c, ui.Size s, StatusTemplate t) {
  final rect = ui.Offset.zero & s;
  final colors = [for (final v in t.colors) ui.Color(v)];
  final paint = ui.Paint();
  switch (t.bgKind) {
    case BgKind.solid:
      paint.color = colors.first;
    case BgKind.linear:
      final dx = math.cos(t.angle), dy = math.sin(t.angle);
      final half = s.longestSide / 2;
      final center = rect.center;
      paint.shader = ui.Gradient.linear(
        center - Offset(dx, dy) * half,
        center + Offset(dx, dy) * half,
        colors,
      );
    case BgKind.radial:
      paint.shader = ui.Gradient.radial(
        rect.center,
        s.longestSide * 0.62,
        colors,
        [for (var i = 0; i < colors.length; i++) i / (colors.length - 1)],
      );
    case BgKind.sweep:
      paint.shader = ui.Gradient.sweep(
        rect.center,
        colors,
        [for (var i = 0; i < colors.length; i++) i / (colors.length - 1)],
        ui.TileMode.clamp,
        0,
        math.pi * 2,
      );
  }
  c.drawRect(rect, paint);
}

void _paintPattern(ui.Canvas c, ui.Size s, StatusTemplate t) {
  if (t.pattern == PatternKind.none) return;
  final color = ui.Color(t.patternColor);
  final paint = ui.Paint()..color = color;
  final rnd = math.Random(t.id.hashCode);
  final w = s.width, h = s.height;
  switch (t.pattern) {
    case PatternKind.none:
      break;
    case PatternKind.dots:
      final step = w / 12;
      for (var y = step / 2; y < h; y += step) {
        for (var x = step / 2 + ((y / step).floor().isOdd ? step / 2 : 0); x < w; x += step) {
          c.drawCircle(Offset(x, y), step * 0.08, paint);
        }
      }
    case PatternKind.stripes:
      paint
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = w * 0.06;
      for (var x = -h; x < w + h; x += w * 0.16) {
        c.drawLine(Offset(x, 0), Offset(x + h * 0.6, h), paint);
      }
    case PatternKind.grid:
      paint
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = 2;
      final step = w / 10;
      for (var x = 0.0; x <= w; x += step) {
        c.drawLine(Offset(x, 0), Offset(x, h), paint);
      }
      for (var y = 0.0; y <= h; y += step) {
        c.drawLine(Offset(0, y), Offset(w, y), paint);
      }
    case PatternKind.waves:
      paint
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = w * 0.012;
      for (var i = 0; i < 9; i++) {
        final y0 = h * (0.62 + i * 0.045);
        final path = ui.Path()..moveTo(0, y0);
        for (var x = 0.0; x <= w; x += 8) {
          path.lineTo(x, y0 + math.sin(x / w * math.pi * 3 + i) * w * 0.02);
        }
        c.drawPath(path, paint);
      }
    case PatternKind.blobs:
      for (var i = 0; i < 7; i++) {
        c.drawCircle(
          Offset(rnd.nextDouble() * w, rnd.nextDouble() * h),
          w * (0.12 + rnd.nextDouble() * 0.2),
          paint,
        );
      }
    case PatternKind.hearts:
      for (var i = 0; i < 22; i++) {
        _heart(c, Offset(rnd.nextDouble() * w, rnd.nextDouble() * h), w * (0.03 + rnd.nextDouble() * 0.05), paint);
      }
    case PatternKind.stars:
      for (var i = 0; i < 46; i++) {
        c.drawCircle(Offset(rnd.nextDouble() * w, rnd.nextDouble() * h), 1.5 + rnd.nextDouble() * 4, paint);
      }
    case PatternKind.circles:
      paint
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = w * 0.006;
      for (var i = 1; i <= 6; i++) {
        c.drawCircle(Offset(w / 2, h / 2), w * 0.18 * i, paint);
      }
    case PatternKind.bands:
      final bandH = h * 0.035;
      for (var i = 0; i < 5; i++) {
        c.drawRect(ui.Rect.fromLTWH(0, h * 0.08 + i * bandH * 1.4, w, bandH), ui.Paint()..color = color.withValues(alpha: 1 - i * 0.18));
        c.drawRect(ui.Rect.fromLTWH(0, h * 0.82 + i * bandH * 1.4, w, bandH), ui.Paint()..color = color.withValues(alpha: 0.2 + i * 0.18));
      }
  }
}

void _heart(ui.Canvas c, Offset center, double r, ui.Paint paint) {
  final path = ui.Path()
    ..moveTo(center.dx, center.dy + r)
    ..cubicTo(center.dx - r * 2, center.dy - r * 0.2, center.dx - r * 0.9, center.dy - r * 1.4, center.dx, center.dy - r * 0.4)
    ..cubicTo(center.dx + r * 0.9, center.dy - r * 1.4, center.dx + r * 2, center.dy - r * 0.2, center.dx, center.dy + r)
    ..close();
  c.drawPath(path, paint);
}

void _paintFrame(ui.Canvas c, ui.Size s, StatusTemplate t) {
  final w = s.width, h = s.height;
  final paint = ui.Paint()
    ..color = ui.Color(t.frameColor)
    ..style = ui.PaintingStyle.stroke
    ..strokeWidth = w * 0.008;
  switch (t.frame) {
    case FrameKind.none:
      break;
    case FrameKind.border:
      c.drawRect(ui.Rect.fromLTWH(w * 0.05, w * 0.05, w * 0.9, h - w * 0.1), paint);
    case FrameKind.doubleBorder:
      c.drawRect(ui.Rect.fromLTWH(w * 0.04, w * 0.04, w * 0.92, h - w * 0.08), paint);
      c.drawRect(ui.Rect.fromLTWH(w * 0.07, w * 0.07, w * 0.86, h - w * 0.14), paint..strokeWidth = w * 0.003);
    case FrameKind.corners:
      final m = w * 0.06, len = w * 0.14;
      paint.strokeWidth = w * 0.012;
      for (final sx in [1.0, -1.0]) {
        for (final sy in [1.0, -1.0]) {
          final x = sx > 0 ? m : w - m;
          final y = sy > 0 ? m : h - m;
          c.drawLine(Offset(x, y), Offset(x + sx * len, y), paint);
          c.drawLine(Offset(x, y), Offset(x, y + sy * len), paint);
        }
      }
    case FrameKind.quoteMarks:
      final tp = TextPainter(
        text: TextSpan(
          text: '“',
          style: TextStyle(
            fontFamily: 'TiroDevanagariHindi',
            fontFamilyFallback: const [kDevanagariFallbackFamily],
            fontSize: w * 0.5,
            height: 1,
            color: ui.Color(t.frameColor),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(c, Offset(w * 0.06, h * 0.08));
      tp.dispose();
    case FrameKind.topBar:
      c.drawRect(ui.Rect.fromLTWH(w * 0.1, h * 0.08, w * 0.2, h * 0.006), ui.Paint()..color = ui.Color(t.frameColor));
  }
}
