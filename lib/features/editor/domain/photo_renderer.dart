// lib/features/editor/domain/photo_renderer.dart
//
// The single drawing routine used by BOTH the live preview and the full-resolution
// export. Because the same code paints both, what the user sees is what is exported.

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import 'edit_state.dart';

// -----------------------------------------------------------------------------
// Colour matrices (4x5, row-major, as used by ColorFilter.matrix)
// -----------------------------------------------------------------------------

List<double> _identity() => [
      1, 0, 0, 0, 0, //
      0, 1, 0, 0, 0,
      0, 0, 1, 0, 0,
      0, 0, 0, 1, 0,
    ];

/// a then b (apply [a] first).
List<double> multiplyMatrices(List<double> a, List<double> b) {
  // Treat each as 5x5 with last row 0 0 0 0 1.
  final out = List<double>.filled(20, 0);
  for (var row = 0; row < 4; row++) {
    for (var col = 0; col < 5; col++) {
      var v = 0.0;
      for (var k = 0; k < 4; k++) {
        v += b[row * 5 + k] * a[k * 5 + col];
      }
      if (col == 4) v += b[row * 5 + 4];
      out[row * 5 + col] = v;
    }
  }
  return out;
}

List<double> saturationMatrix(double s) {
  // s: -1..1 -> factor 0..2
  final f = (1 + s).clamp(0.0, 2.0);
  const lr = 0.2126, lg = 0.7152, lb = 0.0722;
  final inv = 1 - f;
  return [
    lr * inv + f, lg * inv, lb * inv, 0, 0, //
    lr * inv, lg * inv + f, lb * inv, 0, 0,
    lr * inv, lg * inv, lb * inv + f, 0, 0,
    0, 0, 0, 1, 0,
  ];
}

List<double> contrastMatrix(double c) {
  final f = c >= 0 ? 1 + c : 1 + c * 0.9; // -1 -> almost flat, +1 -> double
  final t = 127.5 * (1 - f);
  return [
    f, 0, 0, 0, t, //
    0, f, 0, 0, t,
    0, 0, f, 0, t,
    0, 0, 0, 1, 0,
  ];
}

List<double> brightnessMatrix(double b) {
  final t = b * 0.4 * 255;
  return [
    1, 0, 0, 0, t, //
    0, 1, 0, 0, t,
    0, 0, 1, 0, t,
    0, 0, 0, 1, 0,
  ];
}

List<double> filterMatrix(PhotoFilter f) {
  switch (f) {
    case PhotoFilter.none:
      return _identity();
    case PhotoFilter.vivid:
      return multiplyMatrices(saturationMatrix(0.45), contrastMatrix(0.12));
    case PhotoFilter.warm:
      return [
        1.08, 0, 0, 0, 10, //
        0, 1.0, 0, 0, 4,
        0, 0, 0.9, 0, -8,
        0, 0, 0, 1, 0,
      ];
    case PhotoFilter.cool:
      return [
        0.92, 0, 0, 0, -6, //
        0, 1.0, 0, 0, 2,
        0, 0, 1.1, 0, 12,
        0, 0, 0, 1, 0,
      ];
    case PhotoFilter.fade:
      return multiplyMatrices(contrastMatrix(-0.25), multiplyMatrices(saturationMatrix(-0.2), brightnessMatrix(0.12)));
    case PhotoFilter.mono:
      return saturationMatrix(-1);
    case PhotoFilter.noir:
      return multiplyMatrices(saturationMatrix(-1), contrastMatrix(0.45));
    case PhotoFilter.sepia:
      return [
        0.393, 0.769, 0.189, 0, 0, //
        0.349, 0.686, 0.168, 0, 0,
        0.272, 0.534, 0.131, 0, 0,
        0, 0, 0, 1, 0,
      ];
    case PhotoFilter.vintage:
      return multiplyMatrices(
        multiplyMatrices(saturationMatrix(-0.25), contrastMatrix(-0.1)),
        [
          1.05, 0, 0, 0, 12, //
          0, 0.98, 0, 0, 6,
          0, 0, 0.82, 0, -4,
          0, 0, 0, 1, 0,
        ],
      );
  }
}

/// Final colour matrix for an edit (adjustments first, then the preset look).
List<double> colorMatrixFor(ColorAdjust adjust, PhotoFilter filter) {
  var m = _identity();
  if (adjust.saturation != 0) m = multiplyMatrices(m, saturationMatrix(adjust.saturation));
  if (adjust.contrast != 0) m = multiplyMatrices(m, contrastMatrix(adjust.contrast));
  if (adjust.brightness != 0) m = multiplyMatrices(m, brightnessMatrix(adjust.brightness));
  if (filter != PhotoFilter.none) m = multiplyMatrices(m, filterMatrix(filter));
  return m;
}

// -----------------------------------------------------------------------------
// Text / sticker layout
// -----------------------------------------------------------------------------

/// [stroke], when given, paints the glyph outline instead of the fill (used for the outline pass).
TextStyle overlayTextStyle(TextOverlay t, double fontSize, {ui.Paint? stroke}) {
  final font = fontByKey(t.fontKey);
  final useBold = t.bold;
  return TextStyle(
    fontFamily: font.family,
    fontFamilyFallback: const [kDevanagariFallbackFamily],
    fontSize: fontSize,
    height: 1.25,
    fontWeight: useBold ? FontWeight.w700 : FontWeight.w400,
    color: stroke == null ? ui.Color(t.color) : null,
    foreground: stroke,
    shadows: stroke == null && t.shadow
        ? [Shadow(color: const ui.Color(0xAA000000), blurRadius: fontSize * 0.12, offset: Offset(0, fontSize * 0.05))]
        : null,
  );
}

TextAlign _align(OverlayAlign a) => switch (a) {
      OverlayAlign.left => TextAlign.left,
      OverlayAlign.center => TextAlign.center,
      OverlayAlign.right => TextAlign.right,
    };

/// Laid-out text for [t] within a frame of [frame] pixels.
TextPainter layoutText(TextOverlay t, Size frame) {
  final basis = math.min(frame.width, frame.height);
  final tp = TextPainter(
    text: TextSpan(text: t.text, style: overlayTextStyle(t, t.sizeFrac * basis)),
    textAlign: _align(t.align),
    textDirection: TextDirection.ltr,
  )..layout(maxWidth: frame.width * 0.9);
  return tp;
}

TextPainter layoutSticker(StickerOverlay s, Size frame) {
  final basis = math.min(frame.width, frame.height);
  return TextPainter(
    text: TextSpan(text: s.emoji, style: TextStyle(fontSize: s.sizeFrac * basis, height: 1.1, color: const ui.Color(0xFF000000))),
    textDirection: TextDirection.ltr,
  )..layout();
}

/// Where an overlay sits in the frame (pixels), for hit-testing and selection chrome.
class OverlayBox {
  const OverlayBox(this.center, this.size, this.rotation);
  final Offset center;
  final Size size;
  final double rotation;

  bool contains(Offset p, {double slop = 8}) {
    final d = p - center;
    final c = math.cos(-rotation), s = math.sin(-rotation);
    final local = Offset(d.dx * c - d.dy * s, d.dx * s + d.dy * c);
    return local.dx.abs() <= size.width / 2 + slop && local.dy.abs() <= size.height / 2 + slop;
  }
}

OverlayBox overlayBox(EditOverlay o, Size frame) {
  final tp = switch (o) {
    TextOverlay t => layoutText(t, frame),
    StickerOverlay s => layoutSticker(s, frame),
  };
  final box = OverlayBox(Offset(o.cx * frame.width, o.cy * frame.height), Size(tp.width, tp.height), o.rotation);
  tp.dispose();
  return box;
}

// -----------------------------------------------------------------------------
// Frame geometry
// -----------------------------------------------------------------------------

/// Pixel size of the exported frame when the source is [source] pixels, scaled so
/// the longer side is at most [maxDimension] (never upscaled).
ui.Size exportSize(ui.Size source, EditState s, {double maxDimension = 4096}) {
  final f = s.frameSize(source);
  final k = math.min(1.0, maxDimension / math.max(f.width, f.height));
  return ui.Size(math.max(1, (f.width * k).roundToDouble()), math.max(1, (f.height * k).roundToDouble()));
}

// -----------------------------------------------------------------------------
// Painting
// -----------------------------------------------------------------------------

/// Paints the edit into [canvas] covering exactly [out] (0,0 .. out).
///
/// [image] may be any resolution of the source; geometry is normalised.
void paintEdit(
  ui.Canvas canvas,
  ui.Size out,
  ui.Image image,
  EditState s, {
  bool drawOverlays = true,
  bool ignoreCrop = false,
  ui.Color? background,
  String? hideOverlayId,
}) {
  final src = ui.Size(image.width.toDouble(), image.height.toDouble());
  final oriented = s.orientedSize(src);
  final crop = ignoreCrop ? CropRect.full : s.crop;
  final k = out.width / (oriented.width * crop.width);

  canvas.save();
  canvas.clipRect(ui.Rect.fromLTWH(0, 0, out.width, out.height));
  if (background != null) {
    canvas.drawRect(ui.Rect.fromLTWH(0, 0, out.width, out.height), ui.Paint()..color = background);
  }
  canvas.scale(k);
  canvas.translate(-crop.left * oriented.width, -crop.top * oriented.height);
  // oriented = Flip(Rotate(source)), centred at the oriented image centre.
  canvas.translate(oriented.width / 2, oriented.height / 2);
  canvas.scale(s.flipH ? -1.0 : 1.0, s.flipV ? -1.0 : 1.0);
  canvas.rotate(s.quarterTurns * math.pi / 2);
  canvas.translate(-src.width / 2, -src.height / 2);

  final paint = ui.Paint()..filterQuality = ui.FilterQuality.high;
  final matrix = colorMatrixFor(s.adjust, s.filter);
  if (!_isIdentity(matrix)) paint.colorFilter = ui.ColorFilter.matrix(matrix);
  canvas.drawImage(image, ui.Offset.zero, paint);
  canvas.restore();

  if (drawOverlays) {
    for (final o in s.overlays) {
      if (o.id == hideOverlayId) continue;
      _paintOverlay(canvas, out, o);
    }
  }
}

bool _isIdentity(List<double> m) {
  const id = [1.0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0];
  for (var i = 0; i < 20; i++) {
    if ((m[i] - id[i]).abs() > 1e-9) return false;
  }
  return true;
}

void _paintOverlay(ui.Canvas canvas, ui.Size frame, EditOverlay o) {
  canvas.save();
  canvas.translate(o.cx * frame.width, o.cy * frame.height);
  canvas.rotate(o.rotation);
  switch (o) {
    case TextOverlay t:
      final tp = layoutText(t, frame);
      final offset = Offset(-tp.width / 2, -tp.height / 2);
      if (t.outline) {
        final basis = math.min(frame.width, frame.height);
        final stroke = TextPainter(
          text: TextSpan(
            text: t.text,
            style: overlayTextStyle(
              t,
              t.sizeFrac * basis,
              stroke: ui.Paint()
                ..style = ui.PaintingStyle.stroke
                ..strokeWidth = math.max(2, t.sizeFrac * basis * 0.14)
                ..strokeJoin = ui.StrokeJoin.round
                ..color = ui.Color(t.outlineColor),
            ),
          ),
          textAlign: _align(t.align),
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: frame.width * 0.9);
        stroke.paint(canvas, offset);
        stroke.dispose();
      }
      tp.paint(canvas, offset);
      tp.dispose();
    case StickerOverlay s:
      final tp = layoutSticker(s, frame);
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
      tp.dispose();
  }
  canvas.restore();
}

/// Renders the edit to a bitmap of [out] pixels.
Future<ui.Image> renderEditToImage(
  ui.Image source,
  EditState s,
  ui.Size out, {
  ui.Color background = const ui.Color(0xFFFFFFFF),
}) {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  paintEdit(canvas, out, source, s, background: background);
  final picture = recorder.endRecording();
  final image = picture.toImage(out.width.round(), out.height.round());
  picture.dispose();
  return image;
}
