import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:wazapp/features/editor/domain/edit_state.dart';
import 'package:wazapp/features/editor/domain/photo_renderer.dart';

import '../../support/images.dart';

Future<Pixels> render(ui.Image src, EditState s, {ui.Size? out}) async {
  final size = out ?? exportSize(ui.Size(src.width.toDouble(), src.height.toDouble()), s, maxDimension: 10000);
  final img = await renderEditToImage(src, s, size);
  return readPixels(img);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('geometry', () {
    const src = ui.Size(400, 300);
    test('identity keeps size; quarter turns swap; crop scales; max dimension bounds', () {
      expect(exportSize(src, EditState.initial), const ui.Size(400, 300));
      expect(exportSize(src, const EditState(quarterTurns: 1)), const ui.Size(300, 400));
      expect(exportSize(src, const EditState(quarterTurns: 2)), const ui.Size(400, 300));
      expect(exportSize(src, const EditState(crop: CropRect(0, 0, 0.5, 0.5))), const ui.Size(200, 150));
      expect(exportSize(src, EditState.initial, maxDimension: 200), const ui.Size(200, 150));
      // never upscaled
      expect(exportSize(src, EditState.initial, maxDimension: 4096), const ui.Size(400, 300));
    });
  });

  group('transform pixels (quadrants: TL red, TR green, BL blue, BR yellow)', () {
    late ui.Image src;
    setUp(() async => src = await quadrantImage(40, 40));

    test('identity is exact', () async {
      final p = await render(src, EditState.initial);
      expect(near(p.at(5, 5), 255, 0, 0), isTrue);
      expect(near(p.at(35, 5), 0, 255, 0), isTrue);
      expect(near(p.at(5, 35), 0, 0, 255), isTrue);
      expect(near(p.at(35, 35), 255, 255, 0), isTrue);
    });

    test('rotate clockwise: red moves top-left -> top-right', () async {
      final p = await render(src, const EditState(quarterTurns: 1));
      expect(near(p.at(35, 5), 255, 0, 0), isTrue, reason: 'red at top-right');
      expect(near(p.at(35, 35), 0, 255, 0), isTrue, reason: 'green at bottom-right');
      expect(near(p.at(5, 5), 0, 0, 255), isTrue, reason: 'blue at top-left');
    });

    test('four rotations return to the original', () async {
      var s = EditState.initial;
      for (var i = 0; i < 4; i++) {
        s = s.rotatedClockwise();
      }
      expect(s, EditState.initial);
      final p = await render(src, s);
      expect(near(p.at(5, 5), 255, 0, 0), isTrue);
    });

    test('counter-clockwise is the inverse of clockwise', () {
      expect(EditState.initial.rotatedClockwise().rotatedCounterClockwise(), EditState.initial);
    });

    test('flip horizontal mirrors left/right; flip vertical mirrors top/bottom', () async {
      final h = await render(src, const EditState(flipH: true));
      expect(near(h.at(35, 5), 255, 0, 0), isTrue);
      expect(near(h.at(5, 5), 0, 255, 0), isTrue);
      final v = await render(src, const EditState(flipV: true));
      expect(near(v.at(5, 35), 255, 0, 0), isTrue);
      expect(near(v.at(5, 5), 0, 0, 255), isTrue);
    });

    test('rotate + flip combination (flip applied after rotate)', () async {
      final p = await render(src, const EditState(quarterTurns: 1, flipH: true));
      // After cw rotate red is top-right; mirroring horizontally puts it top-left.
      expect(near(p.at(5, 5), 255, 0, 0), isTrue);
    });

    test('crop right half yields the right half content at the right size', () async {
      final p = await render(src, const EditState(crop: CropRect(0.5, 0, 1, 1)));
      expect(p.width, 20);
      expect(p.height, 40);
      expect(near(p.at(5, 5), 0, 255, 0), isTrue);
      expect(near(p.at(5, 35), 255, 255, 0), isTrue);
    });

    test('crop is applied in oriented space (after rotation)', () async {
      // Rotate cw: oriented top-right = red. Crop top-right quarter -> pure red.
      final p = await render(src, const EditState(quarterTurns: 1, crop: CropRect(0.5, 0, 1, 0.5)));
      expect(p.width, 20);
      expect(p.height, 20);
      expect(near(p.at(10, 10), 255, 0, 0), isTrue);
    });

    test('non-square sources keep their aspect through rotation', () async {
      final wide = await quadrantImage(80, 40);
      final p = await render(wide, const EditState(quarterTurns: 1));
      expect((p.width, p.height), (40, 80));
      expect(near(p.at(35, 5), 255, 0, 0), isTrue);
    });
  });

  group('colour adjustments', () {
    test('brightness lightens and darkens', () async {
      final gray = await solidImage(8, 8, const ui.Color(0xFF808080));
      final up = await render(gray, const EditState(adjust: ColorAdjust(brightness: 0.5)));
      final down = await render(gray, const EditState(adjust: ColorAdjust(brightness: -0.5)));
      expect(up.at(4, 4).$1, greaterThan(0x90));
      expect(down.at(4, 4).$1, lessThan(0x70));
    });

    test('extreme values clamp without overflow artefacts', () async {
      final gray = await solidImage(8, 8, const ui.Color(0xFF808080));
      final max = await render(gray, const EditState(adjust: ColorAdjust(brightness: 1, contrast: 1, saturation: 1)));
      final min = await render(gray, const EditState(adjust: ColorAdjust(brightness: -1, contrast: -1, saturation: -1)));
      expect(max.at(4, 4).$1, inInclusiveRange(0, 255));
      expect(min.at(4, 4).$1, inInclusiveRange(0, 255));
      expect(max.at(4, 4).$4, 255);
    });

    test('saturation -1 removes colour; +1 increases channel spread', () async {
      final c = await solidImage(8, 8, const ui.Color(0xFFC86432));
      final base = (await render(c, EditState.initial)).at(4, 4);
      final gray = (await render(c, const EditState(adjust: ColorAdjust(saturation: -1)))).at(4, 4);
      final vivid = (await render(c, const EditState(adjust: ColorAdjust(saturation: 1)))).at(4, 4);
      expect((gray.$1 - gray.$2).abs() <= 2 && (gray.$2 - gray.$3).abs() <= 2, isTrue);
      expect(vivid.$1 - vivid.$3, greaterThan(base.$1 - base.$3));
    });

    test('contrast spreads values around mid-gray', () async {
      final light = await solidImage(8, 8, const ui.Color(0xFFC0C0C0));
      final hi = (await render(light, const EditState(adjust: ColorAdjust(contrast: 0.6)))).at(4, 4);
      final lo = (await render(light, const EditState(adjust: ColorAdjust(contrast: -0.6)))).at(4, 4);
      expect(hi.$1, greaterThan(0xC0));
      expect(lo.$1, lessThan(0xC0));
    });

    test('every filter changes the pixel except "Original"; mono/noir are neutral grays', () async {
      final c = await solidImage(8, 8, const ui.Color(0xFFC86432));
      final base = (await render(c, EditState.initial)).at(4, 4);
      for (final f in PhotoFilter.values) {
        final px = (await render(c, EditState(filter: f))).at(4, 4);
        if (f == PhotoFilter.none) {
          expect(px, base);
        } else {
          expect(px.$1 != base.$1 || px.$2 != base.$2 || px.$3 != base.$3, isTrue, reason: f.name);
        }
        if (f == PhotoFilter.mono || f == PhotoFilter.noir) {
          expect((px.$1 - px.$2).abs() <= 2 && (px.$2 - px.$3).abs() <= 2, isTrue, reason: f.name);
        }
      }
    });

    test('filters are visually distinct from each other', () async {
      final c = await solidImage(8, 8, const ui.Color(0xFFC86432));
      final seen = <(int, int, int)>{};
      for (final f in PhotoFilter.values) {
        final px = (await render(c, EditState(filter: f))).at(4, 4);
        seen.add((px.$1, px.$2, px.$3));
      }
      expect(seen.length, PhotoFilter.values.length);
    });
  });

  group('overlays', () {
    test('text overlay draws pixels where it is placed and nowhere else', () async {
      final white = await solidImage(200, 200, const ui.Color(0xFFFFFFFF));
      const text = TextOverlay(id: 't', text: 'HI', cx: 0.5, cy: 0.5, color: 0xFF000000, shadow: false, sizeFrac: 0.2);
      final plain = await render(white, EditState.initial);
      final with_ = await render(white, const EditState(overlays: [text]));
      expect(plain.nonBackgroundCount, 0);
      expect(with_.nonBackgroundCount, greaterThan(50));
      // Centre-placed: the top-left corner stays untouched.
      expect(with_.at(2, 2), (255, 255, 255, 255));
    });

    test('outline adds more ink than plain text; moving the overlay moves the ink', () async {
      final white = await solidImage(200, 200, const ui.Color(0xFFFFFFFF));
      const base = TextOverlay(id: 't', text: 'HI', color: 0xFFFFFFFF, shadow: false, sizeFrac: 0.25);
      final fill = await render(white, const EditState(overlays: [base]));
      final outlined = await render(white, EditState(overlays: [base.copyWith(outline: true)]));
      expect(outlined.nonBackgroundCount, greaterThan(fill.nonBackgroundCount));

      final left = await render(white, EditState(overlays: [base.copyWith(color: 0xFF000000).moved(cx: 0.2, cy: 0.5)]));
      final right = await render(white, EditState(overlays: [base.copyWith(color: 0xFF000000).moved(cx: 0.8, cy: 0.5)]));
      int inkLeftHalf(Pixels p) {
        var n = 0;
        for (var y = 0; y < p.height; y++) {
          for (var x = 0; x < p.width ~/ 2; x++) {
            if (p.at(x, y).$1 != 255) n++;
          }
        }
        return n;
      }

      expect(inkLeftHalf(left), greaterThan(0));
      expect(inkLeftHalf(right), 0);
    });

    test('sticker emoji draws, and rotation changes the painted footprint', () async {
      final white = await solidImage(200, 200, const ui.Color(0xFFFFFFFF));
      const s = StickerOverlay(id: 's', emoji: 'A', sizeFrac: 0.4);
      final a = await render(white, const EditState(overlays: [s]));
      final b = await render(white, EditState(overlays: [s.moved(rotation: 0.9)]));
      expect(a.nonBackgroundCount, greaterThan(0));
      expect(b.nonBackgroundCount, greaterThan(0));
      var differ = 0;
      for (var y = 0; y < 200; y++) {
        for (var x = 0; x < 200; x++) {
          if (a.at(x, y) != b.at(x, y)) differ++;
        }
      }
      expect(differ, greaterThan(20));
    });

    test('overlayBox hit-testing honours position and rotation', () {
      const frame = ui.Size(400, 400);
      const t = TextOverlay(id: 't', text: 'MMMM', cx: 0.5, cy: 0.5, sizeFrac: 0.1);
      final box = overlayBox(t, frame);
      expect(box.contains(const ui.Offset(200, 200)), isTrue);
      expect(box.contains(const ui.Offset(20, 20)), isFalse);
      final rotated = overlayBox(t.moved(rotation: 3.14159 / 2), frame);
      // Rotated 90°: a point above centre (vertical extent = old width/2) is now inside.
      final off = box.size.width / 2 - 2;
      expect(rotated.contains(ui.Offset(200, 200 - off), slop: 0), isTrue);
      expect(box.contains(ui.Offset(200, 200 - off), slop: 0), isFalse);
    });
  });

  group('EditState / history', () {
    test('rotate/flip reset the crop (coordinates would be invalid)', () {
      const s = EditState(crop: CropRect(0.1, 0.1, 0.6, 0.6));
      expect(s.rotatedClockwise().crop, CropRect.full);
      expect(s.flippedHorizontally().crop, CropRect.full);
    });

    test('withCrop keeps an overlay at the same spot on the photo', () {
      const src = ui.Size(1000, 1000);
      const t = TextOverlay(id: 't', text: 'x', cx: 0.75, cy: 0.5, sizeFrac: 0.1);
      final s = const EditState(overlays: [t]).withCrop(const CropRect(0.5, 0, 1, 1), src);
      final moved = s.overlays.single as TextOverlay;
      // Absolute x was 0.75; in the right-half frame that is the centre.
      expect(moved.cx, closeTo(0.5, 1e-9));
      expect(moved.cy, closeTo(0.5, 1e-9));
      // Frame short side halved (500 vs 1000): the text must be twice as large relative to it.
      expect(moved.sizeFrac, closeTo(0.2, 1e-9));
    });

    test('undo/redo/reset reflect real state', () {
      final h = EditHistory<EditState>(EditState.initial);
      expect(h.canUndo, isFalse);
      h.push(h.present.copyWith(filter: PhotoFilter.sepia));
      h.push(h.present.copyWith(adjust: const ColorAdjust(brightness: 0.3)));
      expect(h.present.filter, PhotoFilter.sepia);
      expect(h.present.adjust.brightness, 0.3);
      h.undo();
      expect(h.present.adjust.brightness, 0);
      expect(h.present.filter, PhotoFilter.sepia);
      h.undo();
      expect(h.present, EditState.initial);
      expect(h.canUndo, isFalse);
      h.redo();
      expect(h.present.filter, PhotoFilter.sepia);
      h.push(h.present.copyWith(flipH: true)); // new branch clears redo
      expect(h.canRedo, isFalse);
      h.reset();
      expect(h.present, EditState.initial);
      expect(h.canUndo, isTrue); // reset itself is undoable
      h.undo();
      expect(h.present.flipH, isTrue);
    });

    test('a slider drag becomes one undo step; no-ops create none', () {
      final h = EditHistory<EditState>(EditState.initial);
      final before = h.present;
      for (final v in [0.1, 0.2, 0.3]) {
        h.preview(h.present.copyWith(adjust: ColorAdjust(brightness: v)));
      }
      h.commit(before);
      h.undo();
      expect(h.present, EditState.initial);
      expect(h.canUndo, isFalse);
      h.push(h.present); // same value
      expect(h.canUndo, isFalse);
      expect(h.isModified, isFalse);
    });
  });
}
