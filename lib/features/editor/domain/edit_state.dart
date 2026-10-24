// lib/features/editor/domain/edit_state.dart
//
// Immutable, non-destructive description of a photo edit. The original file is
// never modified: the same [EditState] drives the on-screen preview and the
// full-resolution export (see photo_renderer.dart), so they cannot disagree.

import 'dart:math' as math;
import 'dart:ui' show Rect, Size;

import 'package:equatable/equatable.dart';

/// Crop rectangle in *oriented-image* space (after rotation/flip), normalised 0..1.
class CropRect extends Equatable {
  const CropRect(this.left, this.top, this.right, this.bottom);

  static const full = CropRect(0, 0, 1, 1);

  final double left;
  final double top;
  final double right;
  final double bottom;

  double get width => right - left;
  double get height => bottom - top;
  bool get isFull => left <= 0 && top <= 0 && right >= 1 && bottom >= 1;

  Rect toRect() => Rect.fromLTRB(left, top, right, bottom);

  CropRect clamped({double minSize = 0.05}) {
    var l = left.clamp(0.0, 1.0 - minSize);
    var t = top.clamp(0.0, 1.0 - minSize);
    var r = right.clamp(l + minSize, 1.0);
    var b = bottom.clamp(t + minSize, 1.0);
    l = math.min(l, r - minSize);
    t = math.min(t, b - minSize);
    return CropRect(l, t, r, b);
  }

  @override
  List<Object?> get props => [left, top, right, bottom];
}

enum CropAspect {
  free('Free', null),
  original('Original', 0),
  square('1:1', 1),
  portrait45('4:5', 4 / 5),
  story('9:16', 9 / 16),
  landscape('16:9', 16 / 9);

  const CropAspect(this.label, this.ratio);
  final String label;

  /// width / height; null = free, 0 = same as the oriented image.
  final double? ratio;
}

/// Brightness / contrast / saturation, each in -1..1 (0 = unchanged).
class ColorAdjust extends Equatable {
  const ColorAdjust({this.brightness = 0, this.contrast = 0, this.saturation = 0});

  final double brightness;
  final double contrast;
  final double saturation;

  bool get isIdentity => brightness == 0 && contrast == 0 && saturation == 0;

  ColorAdjust copyWith({double? brightness, double? contrast, double? saturation}) => ColorAdjust(
        brightness: brightness ?? this.brightness,
        contrast: contrast ?? this.contrast,
        saturation: saturation ?? this.saturation,
      );

  @override
  List<Object?> get props => [brightness, contrast, saturation];
}

/// Preset looks. Each is a real colour matrix applied at preview and export.
enum PhotoFilter {
  none('Original'),
  vivid('Vivid'),
  warm('Warm'),
  cool('Cool'),
  fade('Fade'),
  mono('Mono'),
  noir('Noir'),
  sepia('Sepia'),
  vintage('Vintage');

  const PhotoFilter(this.label);
  final String label;
}

enum OverlayAlign { left, center, right }

/// A bundled font choice for text overlays.
class EditorFont extends Equatable {
  const EditorFont(this.key, this.label, this.family, {this.bold = false});
  final String key;
  final String label;
  final String family;

  /// Whether this font family has a real bold file (otherwise bold is synthesised).
  final bool bold;

  @override
  List<Object?> get props => [key, family, bold];
}

const List<EditorFont> kEditorFonts = [
  EditorFont('hind', 'Clean', 'Hind', bold: true),
  EditorFont('poppins', 'Modern', 'Poppins'),
  EditorFont('tiro', 'Serif', 'TiroDevanagariHindi'),
  EditorFont('kalam', 'Hand', 'Kalam', bold: true),
  EditorFont('rozha', 'Display', 'RozhaOne'),
  EditorFont('pacifico', 'Script', 'Pacifico'),
];

/// Every text style falls back to Hind so Devanagari never renders as missing glyphs.
const String kDevanagariFallbackFamily = 'Hind';

EditorFont fontByKey(String key) =>
    kEditorFonts.firstWhere((f) => f.key == key, orElse: () => kEditorFonts.first);

sealed class EditOverlay extends Equatable {
  const EditOverlay({required this.id, this.cx = 0.5, this.cy = 0.5, this.rotation = 0});

  final String id;

  /// Centre in the *output frame*, normalised 0..1.
  final double cx;
  final double cy;

  /// Radians, clockwise.
  final double rotation;

  EditOverlay moved({double? cx, double? cy, double? rotation});
}

class TextOverlay extends EditOverlay {
  const TextOverlay({
    required super.id,
    required this.text,
    super.cx,
    super.cy,
    super.rotation,
    this.fontKey = 'hind',
    this.sizeFrac = 0.08,
    this.color = 0xFFFFFFFF,
    this.align = OverlayAlign.center,
    this.bold = true,
    this.outline = false,
    this.outlineColor = 0xFF000000,
    this.shadow = true,
  });

  final String text;
  final String fontKey;

  /// Font size as a fraction of the output frame's shorter side.
  final double sizeFrac;
  final int color;
  final OverlayAlign align;
  final bool bold;
  final bool outline;
  final int outlineColor;
  final bool shadow;

  TextOverlay copyWith({
    String? text,
    String? fontKey,
    double? sizeFrac,
    int? color,
    OverlayAlign? align,
    bool? bold,
    bool? outline,
    int? outlineColor,
    bool? shadow,
  }) =>
      TextOverlay(
        id: id,
        cx: cx,
        cy: cy,
        rotation: rotation,
        text: text ?? this.text,
        fontKey: fontKey ?? this.fontKey,
        sizeFrac: sizeFrac ?? this.sizeFrac,
        color: color ?? this.color,
        align: align ?? this.align,
        bold: bold ?? this.bold,
        outline: outline ?? this.outline,
        outlineColor: outlineColor ?? this.outlineColor,
        shadow: shadow ?? this.shadow,
      );

  @override
  TextOverlay moved({double? cx, double? cy, double? rotation}) => TextOverlay(
        id: id,
        cx: cx ?? this.cx,
        cy: cy ?? this.cy,
        rotation: rotation ?? this.rotation,
        text: text,
        fontKey: fontKey,
        sizeFrac: sizeFrac,
        color: color,
        align: align,
        bold: bold,
        outline: outline,
        outlineColor: outlineColor,
        shadow: shadow,
      );

  @override
  List<Object?> get props =>
      [id, cx, cy, rotation, text, fontKey, sizeFrac, color, align, bold, outline, outlineColor, shadow];
}

class StickerOverlay extends EditOverlay {
  const StickerOverlay({
    required super.id,
    required this.emoji,
    super.cx,
    super.cy,
    super.rotation,
    this.sizeFrac = 0.16,
  });

  final String emoji;
  final double sizeFrac;

  StickerOverlay copyWith({double? sizeFrac}) => StickerOverlay(
        id: id,
        emoji: emoji,
        cx: cx,
        cy: cy,
        rotation: rotation,
        sizeFrac: sizeFrac ?? this.sizeFrac,
      );

  @override
  StickerOverlay moved({double? cx, double? cy, double? rotation}) => StickerOverlay(
        id: id,
        emoji: emoji,
        cx: cx ?? this.cx,
        cy: cy ?? this.cy,
        rotation: rotation ?? this.rotation,
        sizeFrac: sizeFrac,
      );

  @override
  List<Object?> get props => [id, emoji, cx, cy, rotation, sizeFrac];
}

/// The complete edit. Value semantics: equal states are the same edit.
class EditState extends Equatable {
  const EditState({
    this.quarterTurns = 0,
    this.flipH = false,
    this.flipV = false,
    this.crop = CropRect.full,
    this.adjust = const ColorAdjust(),
    this.filter = PhotoFilter.none,
    this.overlays = const [],
  });

  static const initial = EditState();

  /// Clockwise 90° turns, 0..3.
  final int quarterTurns;
  final bool flipH;
  final bool flipV;
  final CropRect crop;
  final ColorAdjust adjust;
  final PhotoFilter filter;
  final List<EditOverlay> overlays;

  bool get isUnchanged => this == initial;

  EditState copyWith({
    int? quarterTurns,
    bool? flipH,
    bool? flipV,
    CropRect? crop,
    ColorAdjust? adjust,
    PhotoFilter? filter,
    List<EditOverlay>? overlays,
  }) =>
      EditState(
        quarterTurns: quarterTurns ?? this.quarterTurns,
        flipH: flipH ?? this.flipH,
        flipV: flipV ?? this.flipV,
        crop: crop ?? this.crop,
        adjust: adjust ?? this.adjust,
        filter: filter ?? this.filter,
        overlays: overlays ?? this.overlays,
      );

  /// Size of the source after rotation (before crop).
  Size orientedSize(Size source) =>
      quarterTurns.isOdd ? Size(source.height, source.width) : source;

  /// Pixel size of the cropped frame at source resolution.
  Size frameSize(Size source) {
    final o = orientedSize(source);
    return Size(o.width * crop.width, o.height * crop.height);
  }

  EditState rotatedClockwise() => copyWith(quarterTurns: (quarterTurns + 1) % 4, crop: CropRect.full);
  EditState rotatedCounterClockwise() => copyWith(quarterTurns: (quarterTurns + 3) % 4, crop: CropRect.full);
  EditState flippedHorizontally() => copyWith(flipH: !flipH, crop: CropRect.full);
  EditState flippedVertically() => copyWith(flipV: !flipV, crop: CropRect.full);

  /// Changes the crop while keeping overlays at the same place *on the photo*
  /// (positions are re-expressed relative to the new frame and sizes rescaled).
  EditState withCrop(CropRect next, Size source) {
    if (next == crop) return this;
    final o = orientedSize(source);
    final oldBasis = math.min(o.width * crop.width, o.height * crop.height);
    final newBasis = math.min(o.width * next.width, o.height * next.height);
    final k = oldBasis / newBasis;
    final remapped = [
      for (final ov in overlays)
        switch (ov) {
          TextOverlay t => _remap(t, next).copyWith(sizeFrac: (t.sizeFrac * k).clamp(0.01, 0.6)),
          StickerOverlay s => _remapSticker(s, next, k),
        },
    ];
    return copyWith(crop: next, overlays: remapped);
  }

  TextOverlay _remap(TextOverlay t, CropRect next) {
    final absX = crop.left + t.cx * crop.width;
    final absY = crop.top + t.cy * crop.height;
    return t.moved(cx: (absX - next.left) / next.width, cy: (absY - next.top) / next.height);
  }

  StickerOverlay _remapSticker(StickerOverlay s, CropRect next, double k) {
    final absX = crop.left + s.cx * crop.width;
    final absY = crop.top + s.cy * crop.height;
    return s
        .moved(cx: (absX - next.left) / next.width, cy: (absY - next.top) / next.height)
        .copyWith(sizeFrac: (s.sizeFrac * k).clamp(0.02, 0.8));
  }

  EditState upsertOverlay(EditOverlay overlay) {
    final i = overlays.indexWhere((o) => o.id == overlay.id);
    final list = [...overlays];
    if (i < 0) {
      list.add(overlay);
    } else {
      list[i] = overlay;
    }
    return copyWith(overlays: list);
  }

  EditState removeOverlay(String id) =>
      copyWith(overlays: [for (final o in overlays) if (o.id != id) o]);

  @override
  List<Object?> get props => [quarterTurns, flipH, flipV, crop, adjust, filter, overlays];
}

/// Linear undo/redo over immutable snapshots.
class EditHistory<T> {
  EditHistory(T initial, {this.limit = 100}) : _present = initial, _initial = initial;

  final int limit;
  final T _initial;
  T _present;
  final List<T> _undo = [];
  final List<T> _redo = [];

  T get present => _present;
  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;
  bool get isModified => _present != _initial;

  /// Records [next] as a new step. No-ops (equal value) create no step.
  void push(T next) {
    if (next == _present) return;
    _undo.add(_present);
    if (_undo.length > limit) _undo.removeAt(0);
    _present = next;
    _redo.clear();
  }

  /// Replaces the present value without creating a step (live slider/drag preview).
  void preview(T next) => _present = next;

  /// Commits a preview as one step: [from] is the value before the gesture began.
  void commit(T from) {
    if (_present == from) return;
    _undo.add(from);
    if (_undo.length > limit) _undo.removeAt(0);
    _redo.clear();
  }

  void undo() {
    if (!canUndo) return;
    _redo.add(_present);
    _present = _undo.removeLast();
  }

  void redo() {
    if (!canRedo) return;
    _undo.add(_present);
    _present = _redo.removeLast();
  }

  /// Back to the initial value as an undoable step.
  void reset() => push(_initial);
}
