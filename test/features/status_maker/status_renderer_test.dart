import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wazapp/features/editor/domain/edit_state.dart';
import 'package:wazapp/features/status_maker/domain/status_renderer.dart';
import 'package:wazapp/features/status_maker/domain/status_templates.dart';

import '../../support/fonts.dart';
import '../../support/images.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadBundledFonts);

  group('template catalogue', () {
    test('has 20-30 uniquely named templates using only bundled fonts', () {
      expect(kStatusTemplates.length, inInclusiveRange(20, 30));
      expect(kStatusTemplates.map((t) => t.id).toSet().length, kStatusTemplates.length);
      expect(kStatusTemplates.map((t) => t.name).toSet().length, kStatusTemplates.length);
      final fontKeys = kEditorFonts.map((f) => f.key).toSet();
      for (final t in kStatusTemplates) {
        expect(fontKeys, contains(t.fontKey), reason: t.id);
        expect(t.colors, isNotEmpty);
        if (t.bgKind != BgKind.solid) expect(t.colors.length, greaterThanOrEqualTo(2), reason: t.id);
      }
    });

    test('every template has a sample in both languages; Hindi samples really are Devanagari', () {
      for (final t in kStatusTemplates) {
        final en = sampleFor(t, StatusLanguage.english);
        final hi = sampleFor(t, StatusLanguage.hindi);
        expect(en, isNotEmpty);
        expect(containsDevanagari(en), isFalse, reason: t.id);
        expect(containsDevanagari(hi), isTrue, reason: t.id);
      }
      expect(kSampleTexts[StatusLanguage.english]!.length, kSampleTexts[StatusLanguage.hindi]!.length);
    });

    test('isSampleText only treats built-in samples/blank as replaceable', () {
      expect(isSampleText(''), isTrue);
      expect(isSampleText('  Eid Mubarak! '), isTrue);
      expect(isSampleText('ईद मुबारक!'), isTrue);
      expect(isSampleText('My own words'), isFalse);
    });

    test('templates are genuinely distinct images (same text, different look)', () async {
      const size = ui.Size(108, 192);
      final seen = <String, String>{};
      for (final t in kStatusTemplates) {
        final img = await renderStatusImage(StatusDraft(templateId: t.id, text: 'Hello'), size: size);
        final px = await readPixels(img);
        // 6x6 quantised signature of the whole picture.
        final sig = StringBuffer();
        for (var gy = 0; gy < 6; gy++) {
          for (var gx = 0; gx < 6; gx++) {
            final c = px.at((gx * 18 + 9).clamp(0, 107), (gy * 32 + 16).clamp(0, 191));
            sig.write('${c.$1 ~/ 24},${c.$2 ~/ 24},${c.$3 ~/ 24};');
          }
        }
        final key = sig.toString();
        expect(seen[key], isNull, reason: '${t.id} looks identical to ${seen[key]}');
        seen[key] = t.id;
      }
    });
  });

  group('rendering', () {
    test('exports exactly 1080x1920', () async {
      final img = await renderStatusImage(const StatusDraft(templateId: 'sunrise', text: 'Hi'));
      expect((img.width, img.height), (1080, 1920));
    });

    test('background colours match the template (solid, gradient ends)', () async {
      const size = ui.Size(100, 200);
      final black = await readPixels(await renderStatusImage(const StatusDraft(templateId: 'mono_bold', text: ''), size: size));
      expect(near(black.at(50, 100), 0, 0, 0, tol: 3), isTrue);
      final ocean = await readPixels(await renderStatusImage(const StatusDraft(templateId: 'ocean', text: ''), size: size));
      final a = ocean.at(2, 2), b = ocean.at(97, 197);
      expect(a != b, isTrue, reason: 'gradient varies across the canvas');
    });

    test('text colour override and alignment are honoured', () async {
      const size = ui.Size(300, 600);
      final red = await readPixels(await renderStatusImage(
        const StatusDraft(templateId: 'minimal_white', text: 'MMM', textColor: 0xFFFF0000, sizeFrac: 0.2),
        size: size,
      ));
      var redPx = 0;
      for (var y = 0; y < red.height; y++) {
        for (var x = 0; x < red.width; x++) {
          final c = red.at(x, y);
          if (c.$1 > 200 && c.$2 < 60 && c.$3 < 60) redPx++;
        }
      }
      expect(redPx, greaterThan(100));

      Future<double> centroidX(OverlayAlign a) async {
        final withText = await readPixels(await renderStatusImage(
          StatusDraft(templateId: 'peach', text: 'Hi there', align: a, sizeFrac: 0.1, textColor: 0xFF000000), size: size));
        final blank = await readPixels(await renderStatusImage(
          StatusDraft(templateId: 'peach', text: '', align: a), size: size));
        var sum = 0.0, n = 0;
        for (var y = 0; y < size.height; y++) {
          for (var x = 0; x < size.width; x++) {
            if (withText.at(x, y) != blank.at(x, y)) {
              sum += x;
              n++;
            }
          }
        }
        return sum / n;
      }

      final left = await centroidX(OverlayAlign.left);
      final center = await centroidX(OverlayAlign.center);
      final right = await centroidX(OverlayAlign.right);
      expect(left, lessThan(center - 20));
      expect(right, greaterThan(center + 20));
    });

    test('ink never leaves the safe area, even for very long English and Hindi text', () async {
      const size = ui.Size(360, 640);
      final longEn = ('Believe in yourself and keep going. ' * 9).substring(0, kMaxStatusChars);
      final longHi = ('जो होता है, अच्छे के लिए होता है। ' * 9).substring(0, kMaxStatusChars);
      for (final text in [longEn, longHi, 'क्षत्रिय ज्ञान श्रीमान् कृपया', 'Hi 😀 there 🎉']) {
        for (final id in ['peach', 'minimal_white', 'sky']) {
          final withText = await readPixels(await renderStatusImage(StatusDraft(templateId: id, text: text), size: size));
          final blank = await readPixels(await renderStatusImage(StatusDraft(templateId: id, text: ''), size: size));
          var minX = 9999, maxX = -1, minY = 9999, maxY = -1;
          for (var y = 0; y < size.height; y++) {
            for (var x = 0; x < size.width; x++) {
              if (withText.at(x, y) != blank.at(x, y)) {
                minX = minX < x ? minX : x;
                maxX = maxX > x ? maxX : x;
                minY = minY < y ? minY : y;
                maxY = maxY > y ? maxY : y;
              }
            }
          }
          expect(maxX, greaterThan(0), reason: '$id: text must be visible');
          expect(minX, greaterThanOrEqualTo(size.width * 0.08), reason: '$id left clip');
          expect(maxX, lessThanOrEqualTo(size.width * 0.92), reason: '$id right clip');
          expect(minY, greaterThanOrEqualTo(size.height * 0.1), reason: '$id top clip');
          expect(maxY, lessThanOrEqualTo(size.height * 0.9), reason: '$id bottom clip');
        }
      }
    });

    test('long text shrinks to fit instead of overflowing', () {
      const size = ui.Size(1080, 1920);
      final short = layoutStatusText(const StatusDraft(templateId: 'peach', text: 'Hi'), size);
      final long = layoutStatusText(StatusDraft(templateId: 'peach', text: ('word ' * 100).substring(0, kMaxStatusChars)), size);
      expect(long.fitted, isTrue);
      expect(long.painter.height, lessThanOrEqualTo(size.height * 0.68));
      expect(long.fontSize, lessThan(short.fontSize));
    });
  });

  group('Devanagari (Hindi) rendering with the bundled fonts', () {
    double width(String text, String family, {List<String>? fallback}) {
      final tp = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(fontFamily: family, fontFamilyFallback: fallback, fontSize: 100),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final w = tp.width;
      tp.dispose();
      return w;
    }

    test('conjuncts are shaped (ligature narrower than separate letters), not drawn letter by letter', () {
      final ligature = width('क्ष', 'Hind');
      final separate = width('क', 'Hind') + width('ष', 'Hind') + width('्', 'Hind');
      expect(ligature, lessThan(separate));
      // Matras attach to their consonant: कि is about as wide as the consonant plus the short-i bar, not 2 full letters.
      expect(width('कि', 'Hind'), lessThan(width('क', 'Hind') * 2));
    });

    test('Hindi text under a Latin-only font falls back to Hind glyphs (no missing-glyph boxes)', () {
      const hindi = 'नमस्ते'; // no spaces: the space glyph legitimately comes from the Latin font
      final viaFallback = width(hindi, 'Pacifico', fallback: const [kDevanagariFallbackFamily]);
      final direct = width(hindi, 'Hind');
      expect(viaFallback, closeTo(direct, 0.5));
      // Without the fallback the Latin-only font cannot supply the glyphs, so the metrics differ.
      expect(width(hindi, 'Pacifico'), isNot(closeTo(direct, 0.5)));
    });

    test('every status font renders the Hindi samples with ink', () async {
      const size = ui.Size(360, 640);
      for (final f in kEditorFonts) {
        final withText = await readPixels(await renderStatusImage(
          StatusDraft(templateId: 'peach', text: 'क्षत्रिय ज्ञान', fontKey: f.key, textColor: 0xFF000000),
          size: size,
        ));
        final blank = await readPixels(await renderStatusImage(
          StatusDraft(templateId: 'peach', text: '', fontKey: f.key), size: size));
        var diff = 0;
        for (var y = 0; y < size.height; y++) {
          for (var x = 0; x < size.width; x++) {
            if (withText.at(x, y) != blank.at(x, y)) diff++;
          }
        }
        expect(diff, greaterThan(200), reason: f.key);
      }
    });

    test('Devanagari lines get extra leading so matras are not clipped', () {
      const size = ui.Size(1080, 1920);
      final hi = layoutStatusText(const StatusDraft(templateId: 'peach', text: 'ऊँची इमारतें'), size);
      final en = layoutStatusText(const StatusDraft(templateId: 'peach', text: 'Tall buildings'), size);
      expect(hi.painter.height / hi.fontSize, greaterThan(en.painter.height / en.fontSize));
    });
  });
}
