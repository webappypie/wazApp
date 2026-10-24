// lib/features/editor/domain/crop_math.dart
//
// Pure geometry for the crop tool (unit-tested; no widgets).

import 'dart:math' as math;
import 'dart:ui' show Offset, Size;

import 'edit_state.dart';

enum CropHandle { topLeft, top, topRight, right, bottomRight, bottom, bottomLeft, left, move }

const double kMinCrop = 0.08;

/// Largest centred crop whose *pixel* aspect (w/h) equals [ratio] inside an [oriented] image.
CropRect aspectCrop(Size oriented, double ratio) {
  final imgRatio = oriented.width / oriented.height;
  double w = 1, h = 1;
  if (ratio > imgRatio) {
    // wider than the image: full width, reduced height
    h = imgRatio / ratio;
  } else {
    w = ratio / imgRatio;
  }
  final l = (1 - w) / 2, t = (1 - h) / 2;
  return CropRect(l, t, l + w, t + h);
}

/// Resolves a [CropAspect] choice to a pixel ratio (w/h), or null when free.
double? aspectRatioFor(CropAspect a, Size oriented) {
  final r = a.ratio;
  if (r == null) return null;
  if (r == 0) return oriented.width / oriented.height;
  return r;
}

/// Applies a drag of [delta] (normalised to the oriented image) to [rect].
///
/// With [lockedRatio] (pixel w/h) the rectangle keeps that aspect while resizing.
CropRect dragCrop(
  CropRect rect,
  CropHandle handle,
  Offset delta, {
  double? lockedRatio,
  required Size oriented,
}) {
  if (handle == CropHandle.move) {
    final dx = delta.dx.clamp(-rect.left, 1 - rect.right);
    final dy = delta.dy.clamp(-rect.top, 1 - rect.bottom);
    return CropRect(rect.left + dx, rect.top + dy, rect.right + dx, rect.bottom + dy);
  }

  if (lockedRatio == null) {
    final movesLeft = handle == CropHandle.topLeft || handle == CropHandle.left || handle == CropHandle.bottomLeft;
    final movesRight = handle == CropHandle.topRight || handle == CropHandle.right || handle == CropHandle.bottomRight;
    final movesTop = handle == CropHandle.topLeft || handle == CropHandle.top || handle == CropHandle.topRight;
    final movesBottom = handle == CropHandle.bottomLeft || handle == CropHandle.bottom || handle == CropHandle.bottomRight;
    // Each moving edge is clamped against the *fixed* opposite edge, so the range is never inverted.
    final l = movesLeft ? (rect.left + delta.dx).clamp(0.0, rect.right - kMinCrop) : rect.left;
    final r = movesRight ? (rect.right + delta.dx).clamp(rect.left + kMinCrop, 1.0) : rect.right;
    final t = movesTop ? (rect.top + delta.dy).clamp(0.0, rect.bottom - kMinCrop) : rect.top;
    final b = movesBottom ? (rect.bottom + delta.dy).clamp(rect.top + kMinCrop, 1.0) : rect.bottom;
    return CropRect(l, t, r, b);
  }

  // Locked aspect: normalised height = normalised width * (oW / (ratio * oH)).
  final k = oriented.width / (lockedRatio * oriented.height);
  double w = rect.width, h = rect.height;
  final cx = (rect.left + rect.right) / 2, cy = (rect.top + rect.bottom) / 2;
  double left, top;

  switch (handle) {
    case CropHandle.topLeft:
    case CropHandle.topRight:
    case CropHandle.bottomLeft:
    case CropHandle.bottomRight:
      final sx = (handle == CropHandle.topLeft || handle == CropHandle.bottomLeft) ? -1.0 : 1.0;
      final sy = (handle == CropHandle.topLeft || handle == CropHandle.topRight) ? -1.0 : 1.0;
      // Use whichever axis moved more, expressed as a width change.
      final dw = (delta.dx * sx).abs() >= (delta.dy * sy / k).abs() ? delta.dx * sx : delta.dy * sy / k;
      w = rect.width + dw;
      final anchorX = sx > 0 ? rect.left : rect.right;
      final anchorY = sy > 0 ? rect.top : rect.bottom;
      w = _fitWidth(w, k, anchorX, anchorY, sx, sy);
      h = w * k;
      left = sx > 0 ? anchorX : anchorX - w;
      top = sy > 0 ? anchorY : anchorY - h;
    case CropHandle.left:
    case CropHandle.right:
      w = rect.width + delta.dx * (handle == CropHandle.right ? 1 : -1);
      w = w.clamp(kMinCrop, math.min(1.0, 1 / k));
      h = w * k;
      left = handle == CropHandle.right ? rect.left : rect.right - w;
      top = cy - h / 2;
    case CropHandle.top:
    case CropHandle.bottom:
      h = rect.height + delta.dy * (handle == CropHandle.bottom ? 1 : -1);
      h = h.clamp(kMinCrop * k, math.min(1.0, k));
      w = h / k;
      top = handle == CropHandle.bottom ? rect.top : rect.bottom - h;
      left = cx - w / 2;
    case CropHandle.move:
      return rect;
  }
  left = left.clamp(0.0, 1 - w);
  top = top.clamp(0.0, 1 - h);
  return CropRect(left, top, left + w, top + h);
}

/// Largest/smallest width that keeps the rect inside the image for a corner drag.
double _fitWidth(double w, double k, double anchorX, double anchorY, double sx, double sy) {
  final maxW = math.min(sx > 0 ? 1 - anchorX : anchorX, (sy > 0 ? 1 - anchorY : anchorY) / k);
  final minW = math.max(kMinCrop, kMinCrop / k);
  return w.clamp(math.min(minW, maxW), math.max(minW, maxW));
}
