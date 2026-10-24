// lib/features/editor/presentation/editor_panels.dart
//
// Tool option panels shown under the preview. Panels never mutate state directly:
// they call back into [EditorActions], which owns the undo history.

import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../core/design/tokens.dart';
import '../domain/crop_math.dart';
import '../domain/edit_state.dart';
import '../domain/photo_renderer.dart';

/// What panels can ask the editor to do.
abstract interface class EditorActions {
  EditState get state;
  String? get selectedId;

  /// Starts a continuous gesture (slider drag): remembers the state to undo to.
  void beginGesture();

  /// Live preview of a continuous change.
  void preview(EditState next);

  /// Ends the gesture as ONE undo step.
  void commitGesture();

  /// Discrete change: one undo step.
  void push(EditState next);

  void select(String? id);
  Future<void> editTextOf(String id);
  Future<void> addText();
  void addSticker(String emoji);
  CropAspect get cropAspect;
  void setCropAspect(CropAspect a);
}

const List<int> kSwatches = [
  0xFFFFFFFF, 0xFF000000, 0xFFFFD60A, 0xFFFF3B30, 0xFFFF9500, 0xFF34C759, //
  0xFF00C7BE, 0xFF0A84FF, 0xFFAF52DE, 0xFFFF2D92, 0xFF8E8E93, 0xFF8B5E3C,
];

const List<String> kStickerEmoji = [
  '😀', '😍', '😂', '🥳', '😎', '🤩', '😇', '🥰', //
  '❤️', '🔥', '✨', '🎉', '👍', '🙏', '💯', '🌹',
  '🌸', '🌟', '☀️', '🌙', '⭐', '🎂', '🎁', '🪔',
  '🕌', '🕉️', '🎊', '🍀', '🦋', '🌈', '💐', '👑',
];

class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.display,
    required this.onStart,
    required this.onChanged,
    required this.onEnd,
    this.onReset,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final String display;
  final VoidCallback onStart;
  final ValueChanged<double> onChanged;
  final VoidCallback onEnd;
  final VoidCallback? onReset;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 84,
          child: Text(label, style: AppTextStyles.labelLarge),
        ),
        Expanded(
          child: Semantics(
            label: label,
            value: display,
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              onChangeStart: (_) => onStart(),
              onChanged: onChanged,
              onChangeEnd: (_) => onEnd(),
            ),
          ),
        ),
        SizedBox(
          width: 40,
          child: Text(
            display,
            textAlign: TextAlign.end,
            style: AppTextStyles.labelMedium,
          ),
        ),
        if (onReset != null)
          IconButton(
            tooltip: 'Reset $label',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.restart_alt, size: 20),
            onPressed: onReset,
          ),
      ],
    );
  }
}

String _pct(double v) => '${(v * 100).round()}';

class AdjustPanel extends StatelessWidget {
  const AdjustPanel({super.key, required this.actions});
  final EditorActions actions;

  @override
  Widget build(BuildContext context) {
    final a = actions.state.adjust;
    Widget row(String label, double v, ColorAdjust Function(double) set) =>
        _SliderRow(
          label: label,
          value: v,
          min: -1,
          max: 1,
          display: _pct(v),
          onStart: actions.beginGesture,
          onChanged: (x) =>
              actions.preview(actions.state.copyWith(adjust: set(x))),
          onEnd: actions.commitGesture,
          onReset: v == 0
              ? null
              : () => actions.push(actions.state.copyWith(adjust: set(0))),
        );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        row('Brightness', a.brightness, (x) => a.copyWith(brightness: x)),
        row('Contrast', a.contrast, (x) => a.copyWith(contrast: x)),
        row('Saturation', a.saturation, (x) => a.copyWith(saturation: x)),
      ],
    );
  }
}

class CropPanel extends StatelessWidget {
  /// [showOrientation] is false for video (rotate/flip are not supported by the video encoder here).
  const CropPanel({
    super.key,
    required this.actions,
    this.showOrientation = true,
  });
  final EditorActions actions;
  final bool showOrientation;

  @override
  Widget build(BuildContext context) {
    final s = actions.state;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final a in CropAspect.values)
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.sm),
                  child: ChoiceChip(
                    label: Text(a.label),
                    selected: actions.cropAspect == a,
                    onSelected: (_) => actions.setCropAspect(a),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            if (showOrientation) ...[
              _ToolIcon(
                icon: Icons.rotate_left,
                label: 'Rotate left',
                onTap: () => actions.push(s.rotatedCounterClockwise()),
              ),
              _ToolIcon(
                icon: Icons.rotate_right,
                label: 'Rotate right',
                onTap: () => actions.push(s.rotatedClockwise()),
              ),
              _ToolIcon(
                icon: Icons.flip,
                label: 'Flip horizontal',
                selected: s.flipH,
                onTap: () => actions.push(s.flippedHorizontally()),
              ),
              _ToolIcon(
                icon: Icons.flip,
                label: 'Flip vertical',
                selected: s.flipV,
                quarterTurns: 1,
                onTap: () => actions.push(s.flippedVertically()),
              ),
            ],
            _ToolIcon(
              icon: Icons.crop_free,
              label: 'Reset crop',
              onTap: s.crop.isFull
                  ? null
                  : () => actions.push(s.copyWith(crop: CropRect.full)),
            ),
          ],
        ),
      ],
    );
  }
}

class _ToolIcon extends StatelessWidget {
  const _ToolIcon({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
    this.quarterTurns = 0,
  });
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool selected;
  final int quarterTurns;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: label,
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: SizedBox(
          width: 64,
          height: 56,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              RotatedBox(
                quarterTurns: quarterTurns,
                child: Icon(
                  icon,
                  color: onTap == null
                      ? scheme.outline
                      : (selected ? scheme.primary : scheme.onSurface),
                ),
              ),
              Text(
                label,
                style: AppTextStyles.labelSmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Horizontal strip of live filter previews.
class FilterPanel extends StatelessWidget {
  const FilterPanel({super.key, required this.actions, required this.image});
  final EditorActions actions;
  final ui.Image image;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final src = ui.Size(image.width.toDouble(), image.height.toDouble());
    final square = aspectCrop(src, 1);
    return SizedBox(
      height: 104,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final f in PhotoFilter.values)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: Semantics(
                label: '${f.label} filter',
                button: true,
                selected: actions.state.filter == f,
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  onTap: () => actions.push(actions.state.copyWith(filter: f)),
                  child: Column(
                    children: [
                      Container(
                        width: 68,
                        height: 68,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          border: Border.all(
                            color: actions.state.filter == f
                                ? scheme.primary
                                : Colors.transparent,
                            width: 2.5,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                          child: CustomPaint(
                            painter: _ThumbPainter(
                              image,
                              EditState(filter: f, crop: square),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(f.label, style: AppTextStyles.labelSmall),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ThumbPainter extends CustomPainter {
  _ThumbPainter(this.image, this.state);
  final ui.Image image;
  final EditState state;

  @override
  void paint(Canvas canvas, Size size) => paintEdit(
    canvas,
    ui.Size(size.width, size.height),
    image,
    state,
    drawOverlays: false,
  );

  @override
  bool shouldRepaint(_ThumbPainter old) =>
      old.image != image || old.state != state;
}

class TextPanel extends StatelessWidget {
  const TextPanel({super.key, required this.actions});
  final EditorActions actions;

  TextOverlay? get _sel {
    for (final o in actions.state.overlays) {
      if (o.id == actions.selectedId && o is TextOverlay) return o;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final t = _sel;
    if (t == null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FilledButton.icon(
            icon: const Icon(Icons.title),
            label: const Text('Add text'),
            onPressed: actions.addText,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'English and हिन्दी are supported. Drag to move; pinch to resize and rotate.',
            style: AppTextStyles.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      );
    }
    void change(TextOverlay n) => actions.push(actions.state.upsertOverlay(n));
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Edit text'),
                onPressed: () => actions.editTextOf(t.id),
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            IconButton.outlined(
              tooltip: 'Add another text',
              icon: const Icon(Icons.add),
              onPressed: actions.addText,
            ),
            IconButton.outlined(
              tooltip: 'Delete text',
              icon: const Icon(Icons.delete_outline),
              onPressed: () {
                actions.push(actions.state.removeOverlay(t.id));
                actions.select(null);
              },
            ),
          ],
        ),
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final f in kEditorFonts)
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.sm),
                  child: ChoiceChip(
                    label: Text(
                      f.label,
                      style: TextStyle(
                        fontFamily: f.family,
                        fontFamilyFallback: const [kDevanagariFallbackFamily],
                      ),
                    ),
                    selected: t.fontKey == f.key,
                    onSelected: (_) => change(t.copyWith(fontKey: f.key)),
                  ),
                ),
            ],
          ),
        ),
        _SliderRow(
          label: 'Size',
          value: t.sizeFrac,
          min: 0.03,
          max: 0.3,
          display: _pct(t.sizeFrac),
          onStart: actions.beginGesture,
          onChanged: (x) => actions.preview(
            actions.state.upsertOverlay(t.copyWith(sizeFrac: x)),
          ),
          onEnd: actions.commitGesture,
        ),
        _Swatches(
          selected: t.color,
          onPick: (c) => change(t.copyWith(color: c)),
        ),
        Wrap(
          spacing: AppSpacing.sm,
          children: [
            SegmentedButton<OverlayAlign>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                  value: OverlayAlign.left,
                  icon: Icon(Icons.format_align_left),
                  tooltip: 'Align left',
                ),
                ButtonSegment(
                  value: OverlayAlign.center,
                  icon: Icon(Icons.format_align_center),
                  tooltip: 'Align centre',
                ),
                ButtonSegment(
                  value: OverlayAlign.right,
                  icon: Icon(Icons.format_align_right),
                  tooltip: 'Align right',
                ),
              ],
              selected: {t.align},
              onSelectionChanged: (s) => change(t.copyWith(align: s.first)),
            ),
            FilterChip(
              label: const Text('Bold'),
              selected: t.bold,
              onSelected: (v) => change(t.copyWith(bold: v)),
            ),
            FilterChip(
              label: const Text('Outline'),
              selected: t.outline,
              onSelected: (v) => change(t.copyWith(outline: v)),
            ),
            FilterChip(
              label: const Text('Shadow'),
              selected: t.shadow,
              onSelected: (v) => change(t.copyWith(shadow: v)),
            ),
          ],
        ),
      ],
    );
  }
}

class _Swatches extends StatelessWidget {
  const _Swatches({required this.selected, required this.onPick});
  final int selected;
  final ValueChanged<int> onPick;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final c in kSwatches)
            Padding(
              padding: const EdgeInsets.all(5),
              child: Semantics(
                label: 'Colour ${c.toRadixString(16).toUpperCase()}',
                button: true,
                selected: c == selected,
                child: InkResponse(
                  onTap: () => onPick(c),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Color(c),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: c == selected
                            ? scheme.primary
                            : scheme.outlineVariant,
                        width: c == selected ? 3 : 1,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class StickerPanel extends StatelessWidget {
  const StickerPanel({super.key, required this.actions});
  final EditorActions actions;

  StickerOverlay? get _sel {
    for (final o in actions.state.overlays) {
      if (o.id == actions.selectedId && o is StickerOverlay) return o;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final s = _sel;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 56,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final e in kStickerEmoji)
                Semantics(
                  label: 'Add sticker $e',
                  button: true,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    onTap: () => actions.addSticker(e),
                    child: SizedBox(
                      width: 52,
                      height: 52,
                      child: Center(
                        child: Text(e, style: const TextStyle(fontSize: 28)),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (s != null)
          Row(
            children: [
              Expanded(
                child: _SliderRow(
                  label: 'Size',
                  value: s.sizeFrac,
                  min: 0.05,
                  max: 0.6,
                  display: _pct(s.sizeFrac),
                  onStart: actions.beginGesture,
                  onChanged: (x) => actions.preview(
                    actions.state.upsertOverlay(s.copyWith(sizeFrac: x)),
                  ),
                  onEnd: actions.commitGesture,
                ),
              ),
              IconButton.outlined(
                tooltip: 'Delete sticker',
                icon: const Icon(Icons.delete_outline),
                onPressed: () {
                  actions.push(actions.state.removeOverlay(s.id));
                  actions.select(null);
                },
              ),
            ],
          )
        else
          Text(
            'Tap a sticker to add it, then drag, pinch and rotate.',
            style: AppTextStyles.bodySmall,
          ),
      ],
    );
  }
}
