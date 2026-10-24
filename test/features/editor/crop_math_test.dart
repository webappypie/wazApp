import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:wazapp/features/editor/domain/crop_math.dart';
import 'package:wazapp/features/editor/domain/edit_state.dart';

void expectRect(CropRect a, CropRect b) {
  expect(a.left, closeTo(b.left, 1e-9));
  expect(a.top, closeTo(b.top, 1e-9));
  expect(a.right, closeTo(b.right, 1e-9));
  expect(a.bottom, closeTo(b.bottom, 1e-9));
}

double pixelRatio(CropRect r, Size o) => (r.width * o.width) / (r.height * o.height);

void main() {
  const wide = Size(4000, 3000);
  const tall = Size(3000, 4000);

  test('aspectCrop returns the largest centred rect with the requested pixel aspect', () {
    final sq = aspectCrop(wide, 1);
    expect(pixelRatio(sq, wide), closeTo(1, 1e-9));
    expect(sq.height, 1); // limited by height
    expect(sq.left, closeTo((1 - 0.75) / 2, 1e-9));

    final story = aspectCrop(wide, 9 / 16);
    expect(pixelRatio(story, wide), closeTo(9 / 16, 1e-9));
    expect(story.height, 1);

    final land = aspectCrop(tall, 16 / 9);
    expect(pixelRatio(land, tall), closeTo(16 / 9, 1e-9));
    expect(land.width, 1);
    expect(land.top, greaterThan(0));
  });

  test('aspectRatioFor handles free / original / fixed', () {
    expect(aspectRatioFor(CropAspect.free, wide), isNull);
    expect(aspectRatioFor(CropAspect.original, wide), closeTo(4 / 3, 1e-9));
    expect(aspectRatioFor(CropAspect.square, wide), 1);
  });

  group('free dragging', () {
    const start = CropRect(0.2, 0.2, 0.8, 0.8);
    test('each edge/corner moves only its sides', () {
      expectRect(dragCrop(start, CropHandle.left, const Offset(0.1, 0.5), oriented: wide), const CropRect(0.3, 0.2, 0.8, 0.8));
      expectRect(dragCrop(start, CropHandle.bottomRight, const Offset(0.05, -0.05), oriented: wide),
          const CropRect(0.2, 0.2, 0.85, 0.75));
    });

    test('cannot leave the image or collapse below the minimum size', () {
      final out = dragCrop(start, CropHandle.topLeft, const Offset(-5, -5), oriented: wide);
      expect((out.left, out.top), (0.0, 0.0));
      final tiny = dragCrop(start, CropHandle.right, const Offset(-5, 0), oriented: wide);
      expect(tiny.width, closeTo(kMinCrop, 1e-9));
    });

    test('move keeps size and stays inside', () {
      final m = dragCrop(start, CropHandle.move, const Offset(0.5, -0.5), oriented: wide);
      expect(m.width, closeTo(0.6, 1e-9));
      expect(m.right, closeTo(1, 1e-9));
      expect(m.top, 0);
    });
  });

  group('locked aspect dragging keeps the pixel ratio and stays inside', () {
    for (final ratio in [1.0, 4 / 5, 9 / 16, 16 / 9]) {
      for (final handle in CropHandle.values.where((h) => h != CropHandle.move)) {
        test('ratio ${ratio.toStringAsFixed(2)} handle ${handle.name}', () {
          final base = aspectCrop(wide, ratio);
          // shrink first so there is room to grow in every direction
          final start = CropRect(
            base.left + base.width * 0.25,
            base.top + base.height * 0.25,
            base.right - base.width * 0.25,
            base.bottom - base.height * 0.25,
          );
          for (final d in const [Offset(0.05, 0.03), Offset(-0.1, -0.02), Offset(0.4, 0.4), Offset(-0.9, 0.9)]) {
            final r = dragCrop(start, handle, d, lockedRatio: ratio, oriented: wide);
            expect(pixelRatio(r, wide), closeTo(ratio, 1e-6), reason: '$d');
            expect(r.left, greaterThanOrEqualTo(-1e-9));
            expect(r.top, greaterThanOrEqualTo(-1e-9));
            expect(r.right, lessThanOrEqualTo(1 + 1e-9));
            expect(r.bottom, lessThanOrEqualTo(1 + 1e-9));
            expect(r.width, greaterThan(0));
          }
        });
      }
    }
  });
}
