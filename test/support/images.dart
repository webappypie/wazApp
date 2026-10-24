// Helpers to build and inspect real bitmaps in tests.

import 'dart:typed_data';
import 'dart:ui' as ui;

/// Four solid quadrants: TL red, TR green, BL blue, BR yellow.
Future<ui.Image> quadrantImage(int w, int h) async {
  final recorder = ui.PictureRecorder();
  final c = ui.Canvas(recorder);
  final hw = w / 2, hh = h / 2;
  c.drawRect(ui.Rect.fromLTWH(0, 0, hw, hh), ui.Paint()..color = const ui.Color(0xFFFF0000));
  c.drawRect(ui.Rect.fromLTWH(hw, 0, hw, hh), ui.Paint()..color = const ui.Color(0xFF00FF00));
  c.drawRect(ui.Rect.fromLTWH(0, hh, hw, hh), ui.Paint()..color = const ui.Color(0xFF0000FF));
  c.drawRect(ui.Rect.fromLTWH(hw, hh, hw, hh), ui.Paint()..color = const ui.Color(0xFFFFFF00));
  return recorder.endRecording().toImage(w, h);
}

Future<ui.Image> solidImage(int w, int h, ui.Color color) async {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawRect(ui.Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()), ui.Paint()..color = color);
  return recorder.endRecording().toImage(w, h);
}

class Pixels {
  Pixels(this.width, this.height, this.data);
  final int width;
  final int height;
  final ByteData data;

  /// (r, g, b, a)
  (int, int, int, int) at(int x, int y) {
    final i = (y * width + x) * 4;
    return (data.getUint8(i), data.getUint8(i + 1), data.getUint8(i + 2), data.getUint8(i + 3));
  }

  int get nonBackgroundCount {
    var n = 0;
    for (var i = 0; i < width * height; i++) {
      final r = data.getUint8(i * 4), g = data.getUint8(i * 4 + 1), b = data.getUint8(i * 4 + 2);
      if (r != 255 || g != 255 || b != 255) n++;
    }
    return n;
  }
}

Future<Pixels> readPixels(ui.Image image) async {
  final data = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
  return Pixels(image.width, image.height, data);
}

Future<Uint8List> encodePng(ui.Image image) async =>
    (await image.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();

/// True if (r,g,b) is within [tol] of the expected colour.
bool near((int, int, int, int) px, int r, int g, int b, {int tol = 6}) =>
    (px.$1 - r).abs() <= tol && (px.$2 - g).abs() <= tol && (px.$3 - b).abs() <= tol;
