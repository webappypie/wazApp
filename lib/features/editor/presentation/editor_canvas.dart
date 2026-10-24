// lib/features/editor/presentation/editor_canvas.dart
//
// Interactive preview. It paints with the SAME routine as the exporter
// (paintEdit), then layers selection handles / the crop frame on top.

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../domain/crop_math.dart';
import '../domain/edit_state.dart';
import '../domain/photo_renderer.dart';

enum EditorTool { adjust, crop, filters, text, stickers }

class EditorCanvas extends StatefulWidget {
  const EditorCanvas({
    super.key,
    required this.image,
    required this.state,
    required this.tool,
    required this.selectedId,
    required this.onPreview,
    required this.onCommit,
    required this.onSelect,
    this.lockedRatio,
  });

  final ui.Image image;
  final EditState state;
  final EditorTool tool;
  final String? selectedId;

  /// Live change during a gesture (not yet an undo step).
  final ValueChanged<EditState> onPreview;

  /// Gesture finished: [from] is the state before it began.
  final ValueChanged<EditState> onCommit;
  final ValueChanged<String?> onSelect;

  /// Pixel aspect (w/h) enforced while dragging the crop frame.
  final double? lockedRatio;

  @override
  State<EditorCanvas> createState() => _EditorCanvasState();
}

class _EditorCanvasState extends State<EditorCanvas> {
  // Gesture session
  EditState? _from;
  EditOverlay? _grabbed;
  CropHandle? _handle;
  Offset _startFocal = Offset.zero;

  bool get _cropping => widget.tool == EditorTool.crop;

  ui.Size get _source => ui.Size(widget.image.width.toDouble(), widget.image.height.toDouble());

  /// Size of the image area shown (full oriented image while cropping, else the cropped frame).
  ui.Size _frameAspect() {
    final s = widget.state;
    if (_cropping) return s.orientedSize(_source);
    return s.frameSize(_source);
  }

  Size _fit(Size avail, ui.Size aspect) {
    final k = math.min(avail.width / aspect.width, avail.height / aspect.height);
    return Size(aspect.width * k, aspect.height * k);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final aspect = _frameAspect();
      final frame = _fit(Size(c.maxWidth, c.maxHeight), aspect);
      return Center(
        child: SizedBox(
          width: frame.width,
          height: frame.height,
          child: Semantics(
            label: 'Photo preview',
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onScaleStart: (d) => _start(d, frame),
              onScaleUpdate: (d) => _update(d, frame),
              onScaleEnd: (_) => _end(),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  RepaintBoundary(
                    child: CustomPaint(
                      painter: _PhotoPainter(widget.image, widget.state, _cropping),
                    ),
                  ),
                  IgnorePointer(
                    child: CustomPaint(
                      painter: _ChromePainter(
                        state: widget.state,
                        cropping: _cropping,
                        selectedId: widget.selectedId,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }

  // ---------------------------------------------------------------------------
  // Gestures
  // ---------------------------------------------------------------------------

  void _start(ScaleStartDetails d, Size frame) {
    _from = widget.state;
    _startFocal = d.localFocalPoint;
    _grabbed = null;
    _handle = null;
    if (_cropping) {
      _handle = _hitHandle(d.localFocalPoint, frame);
      return;
    }
    // Topmost overlay under the finger.
    for (final o in widget.state.overlays.reversed) {
      if (overlayBox(o, ui.Size(frame.width, frame.height)).contains(d.localFocalPoint, slop: 14)) {
        _grabbed = o;
        widget.onSelect(o.id);
        return;
      }
    }
    widget.onSelect(null);
  }

  void _update(ScaleUpdateDetails d, Size frame) {
    final from = _from;
    if (from == null) return;
    if (_cropping) {
      final h = _handle;
      if (h == null) return;
      final total = d.localFocalPoint - _startFocal;
      final delta = Offset(total.dx / frame.width, total.dy / frame.height);
      final next = dragCrop(
        from.crop,
        h,
        delta,
        lockedRatio: widget.lockedRatio,
        oriented: from.orientedSize(_source),
      );
      widget.onPreview(from.withCrop(next, _source));
      return;
    }
    final g = _grabbed;
    if (g == null) return;
    final total = d.localFocalPoint - _startFocal;
    var moved = g.moved(
      cx: (g.cx + total.dx / frame.width).clamp(0.0, 1.0),
      cy: (g.cy + total.dy / frame.height).clamp(0.0, 1.0),
      rotation: d.pointerCount > 1 ? g.rotation + d.rotation : g.rotation,
    );
    if (d.pointerCount > 1) {
      moved = switch (moved) {
        TextOverlay t => t.copyWith(sizeFrac: ((g as TextOverlay).sizeFrac * d.scale).clamp(0.02, 0.4)),
        StickerOverlay s => s.copyWith(sizeFrac: ((g as StickerOverlay).sizeFrac * d.scale).clamp(0.04, 0.9)),
      };
    }
    widget.onPreview(from.upsertOverlay(moved));
  }

  void _end() {
    final from = _from;
    _from = null;
    _grabbed = null;
    _handle = null;
    if (from != null) widget.onCommit(from);
  }

  CropHandle? _hitHandle(Offset p, Size frame) {
    final r = widget.state.crop;
    final l = r.left * frame.width, t = r.top * frame.height;
    final rt = r.right * frame.width, b = r.bottom * frame.height;
    const hit = 32.0;
    bool near(double ax, double ay) => (p - Offset(ax, ay)).distance <= hit;
    if (near(l, t)) return CropHandle.topLeft;
    if (near(rt, t)) return CropHandle.topRight;
    if (near(l, b)) return CropHandle.bottomLeft;
    if (near(rt, b)) return CropHandle.bottomRight;
    final midX = (l + rt) / 2, midY = (t + b) / 2;
    if (near(midX, t)) return CropHandle.top;
    if (near(midX, b)) return CropHandle.bottom;
    if (near(l, midY)) return CropHandle.left;
    if (near(rt, midY)) return CropHandle.right;
    if (Rect.fromLTRB(l, t, rt, b).contains(p)) return CropHandle.move;
    return null;
  }
}

class _PhotoPainter extends CustomPainter {
  _PhotoPainter(this.image, this.state, this.cropping);
  final ui.Image image;
  final EditState state;
  final bool cropping;

  @override
  void paint(Canvas canvas, Size size) {
    paintEdit(
      canvas,
      ui.Size(size.width, size.height),
      image,
      state,
      ignoreCrop: cropping,
      drawOverlays: !cropping,
      background: const Color(0xFFFFFFFF),
    );
  }

  @override
  bool shouldRepaint(_PhotoPainter old) =>
      old.image != image || old.state != state || old.cropping != cropping;
}

class _ChromePainter extends CustomPainter {
  _ChromePainter({required this.state, required this.cropping, required this.selectedId, required this.color});
  final EditState state;
  final bool cropping;
  final String? selectedId;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (cropping) {
      _paintCrop(canvas, size);
      return;
    }
    for (final o in state.overlays) {
      if (o.id != selectedId) continue;
      final box = overlayBox(o, ui.Size(size.width, size.height));
      canvas.save();
      canvas.translate(box.center.dx, box.center.dy);
      canvas.rotate(box.rotation);
      final rect = Rect.fromCenter(center: Offset.zero, width: box.size.width + 12, height: box.size.height + 8);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(6)),
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      canvas.restore();
    }
  }

  void _paintCrop(Canvas canvas, Size size) {
    final r = state.crop;
    final rect = Rect.fromLTRB(r.left * size.width, r.top * size.height, r.right * size.width, r.bottom * size.height);
    final dim = Paint()..color = const Color(0x99000000);
    canvas.drawPath(
      Path()
        ..addRect(Offset.zero & size)
        ..addRect(rect)
        ..fillType = PathFillType.evenOdd,
      dim,
    );
    final line = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRect(rect, line);
    final thirds = Paint()
      ..color = Colors.white54
      ..strokeWidth = 0.8;
    for (var i = 1; i < 3; i++) {
      canvas.drawLine(Offset(rect.left + rect.width * i / 3, rect.top), Offset(rect.left + rect.width * i / 3, rect.bottom), thirds);
      canvas.drawLine(Offset(rect.left, rect.top + rect.height * i / 3), Offset(rect.right, rect.top + rect.height * i / 3), thirds);
    }
    final handle = Paint()..color = Colors.white;
    final edge = Paint()..color = color;
    for (final p in [
      rect.topLeft, rect.topRight, rect.bottomLeft, rect.bottomRight,
      rect.topCenter, rect.bottomCenter, rect.centerLeft, rect.centerRight, //
    ]) {
      canvas.drawCircle(p, 9, edge);
      canvas.drawCircle(p, 6.5, handle);
    }
  }

  @override
  bool shouldRepaint(_ChromePainter old) =>
      old.state != state || old.cropping != cropping || old.selectedId != selectedId || old.color != color;
}
