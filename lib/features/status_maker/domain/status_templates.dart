// lib/features/status_maker/domain/status_templates.dart
//
// Data-only definitions of the text-status templates. Every template is a
// distinct combination of background, pattern, frame, font and colour, drawn
// procedurally (no image assets). Hindi and English share the same templates.

import 'package:equatable/equatable.dart';

import '../../editor/domain/edit_state.dart';

enum StatusLanguage {
  english('English'),
  hindi('हिन्दी');

  const StatusLanguage(this.label);
  final String label;
}

enum BgKind { solid, linear, radial, sweep }

/// Decoration painted over the background, under the text.
enum PatternKind { none, dots, stripes, grid, waves, blobs, hearts, stars, circles, bands }

/// Decoration painted around the text.
enum FrameKind { none, border, doubleBorder, corners, quoteMarks, topBar }

class StatusTemplate extends Equatable {
  const StatusTemplate({
    required this.id,
    required this.name,
    required this.category,
    required this.bgKind,
    required this.colors,
    required this.fontKey,
    required this.textColor,
    this.angle = 0.8,
    this.pattern = PatternKind.none,
    this.patternColor = 0x33FFFFFF,
    this.frame = FrameKind.none,
    this.frameColor = 0xFFFFFFFF,
    this.align = OverlayAlign.center,
    this.bold = true,
    this.shadow = false,
    this.sizeFrac = 0.075,
    this.sample = 0,
  });

  final String id;
  final String name;
  final String category;
  final BgKind bgKind;

  /// ARGB. One colour for [BgKind.solid]; two or more for gradients.
  final List<int> colors;

  /// Gradient direction in radians (linear only).
  final double angle;
  final PatternKind pattern;
  final int patternColor;
  final FrameKind frame;
  final int frameColor;
  final String fontKey;
  final int textColor;
  final OverlayAlign align;
  final bool bold;
  final bool shadow;

  /// Default font size as a fraction of the canvas width.
  final double sizeFrac;

  /// Index into the sample quotes shown when this template is chosen.
  final int sample;

  @override
  List<Object?> get props => [id];
}

const List<StatusTemplate> kStatusTemplates = [
  StatusTemplate(
    id: 'sunrise', name: 'Sunrise', category: 'Motivation', bgKind: BgKind.linear,
    colors: [0xFFFF9A44, 0xFFFC6076], angle: 1.2, fontKey: 'poppins', textColor: 0xFFFFFFFF, shadow: true, sample: 0,
  ),
  StatusTemplate(
    id: 'ocean', name: 'Ocean', category: 'Motivation', bgKind: BgKind.linear,
    colors: [0xFF0BA5A4, 0xFF0B3C5D], angle: 1.5, pattern: PatternKind.waves, patternColor: 0x22FFFFFF,
    fontKey: 'hind', textColor: 0xFFFFFFFF, sample: 3,
  ),
  StatusTemplate(
    id: 'midnight', name: 'Midnight', category: 'Quotes', bgKind: BgKind.solid,
    colors: [0xFF0F172A], pattern: PatternKind.stars, patternColor: 0x66FFFFFF,
    fontKey: 'tiro', textColor: 0xFFF5D98B, bold: false, sample: 1,
  ),
  StatusTemplate(
    id: 'forest', name: 'Forest', category: 'Nature', bgKind: BgKind.linear,
    colors: [0xFF134E3A, 0xFF5BA55B], angle: 1.4, fontKey: 'kalam', textColor: 0xFFFFF6DC, sample: 2,
  ),
  StatusTemplate(
    id: 'rose', name: 'Rose', category: 'Love', bgKind: BgKind.radial,
    colors: [0xFFFF6FA5, 0xFF8E1050], fontKey: 'pacifico', textColor: 0xFFFFFFFF, bold: false, shadow: true,
    sizeFrac: 0.07, sample: 1,
  ),
  StatusTemplate(
    id: 'mono_bold', name: 'Mono Bold', category: 'Bold', bgKind: BgKind.solid,
    colors: [0xFF000000], fontKey: 'rozha', textColor: 0xFFFFFFFF, frame: FrameKind.border,
    sizeFrac: 0.095, bold: false, sample: 4,
  ),
  StatusTemplate(
    id: 'paper', name: 'Paper', category: 'Quotes', bgKind: BgKind.solid,
    colors: [0xFFF5EFE0], fontKey: 'tiro', textColor: 0xFF4A3426, frame: FrameKind.quoteMarks,
    frameColor: 0x55936A4B, bold: false, sample: 0,
  ),
  StatusTemplate(
    id: 'neon', name: 'Neon', category: 'Bold', bgKind: BgKind.sweep,
    colors: [0xFF7B2FF7, 0xFF00D4FF, 0xFF7B2FF7], fontKey: 'poppins', textColor: 0xFFFFFFFF, shadow: true,
    sizeFrac: 0.08, sample: 3,
  ),
  StatusTemplate(
    id: 'sunset_stripes', name: 'Sunset Stripes', category: 'Bold', bgKind: BgKind.linear,
    colors: [0xFFFF7E5F, 0xFFFEB47B], angle: 0.6, pattern: PatternKind.stripes, patternColor: 0x26FFFFFF,
    fontKey: 'hind', textColor: 0xFFFFFFFF, shadow: true, sample: 4,
  ),
  StatusTemplate(
    id: 'mint', name: 'Mint Fresh', category: 'Minimal', bgKind: BgKind.solid,
    colors: [0xFFCFF5E7], pattern: PatternKind.waves, patternColor: 0x3300796B,
    fontKey: 'hind', textColor: 0xFF075E54, sample: 6,
  ),
  StatusTemplate(
    id: 'royal', name: 'Royal', category: 'Festive', bgKind: BgKind.linear,
    colors: [0xFF1B1464, 0xFF6A1B9A], angle: 1.1, fontKey: 'rozha', textColor: 0xFFFFD36A,
    frame: FrameKind.doubleBorder, frameColor: 0xFFFFD36A, bold: false, sample: 7,
  ),
  StatusTemplate(
    id: 'candy', name: 'Candy', category: 'Fun', bgKind: BgKind.solid,
    colors: [0xFFFFE3EF], pattern: PatternKind.blobs, patternColor: 0x55A5D8FF,
    fontKey: 'kalam', textColor: 0xFF5B2A86, sample: 2,
  ),
  StatusTemplate(
    id: 'fire', name: 'Fire', category: 'Bold', bgKind: BgKind.radial,
    colors: [0xFFFFD200, 0xFFFF4B1F, 0xFF7A0A00], fontKey: 'rozha', textColor: 0xFFFFFFFF, shadow: true,
    bold: false, sizeFrac: 0.09, sample: 4,
  ),
  StatusTemplate(
    id: 'slate_grid', name: 'Slate Grid', category: 'Minimal', bgKind: BgKind.solid,
    colors: [0xFF263238], pattern: PatternKind.grid, patternColor: 0x22FFFFFF, fontKey: 'poppins',
    textColor: 0xFFFFFFFF, align: OverlayAlign.left, sizeFrac: 0.07, sample: 0,
  ),
  StatusTemplate(
    id: 'lavender', name: 'Lavender Dream', category: 'Love', bgKind: BgKind.linear,
    colors: [0xFFD4B5F5, 0xFFFFC2E2], angle: 1.3, fontKey: 'pacifico', textColor: 0xFF4A1D7A, bold: false, sample: 5,
  ),
  StatusTemplate(
    id: 'gold_festive', name: 'Gold Festive', category: 'Festive', bgKind: BgKind.solid,
    colors: [0xFF8E0E1B], pattern: PatternKind.dots, patternColor: 0x44FFD36A, fontKey: 'rozha',
    textColor: 0xFFFFD36A, frame: FrameKind.corners, frameColor: 0xFFFFD36A, bold: false, sample: 8,
  ),
  StatusTemplate(
    id: 'diwali_glow', name: 'Diwali Glow', category: 'Festive', bgKind: BgKind.radial,
    colors: [0xFFFFB300, 0xFF3E1F00, 0xFF120800], pattern: PatternKind.circles, patternColor: 0x33FFD36A,
    fontKey: 'tiro', textColor: 0xFFFFE9A8, bold: false, shadow: true, sample: 8,
  ),
  StatusTemplate(
    id: 'eid_night', name: 'Eid Night', category: 'Festive', bgKind: BgKind.linear,
    colors: [0xFF0B3D2E, 0xFF02110C], angle: 1.57, pattern: PatternKind.stars, patternColor: 0x88FFF3C4,
    fontKey: 'hind', textColor: 0xFFFFF3C4, frame: FrameKind.topBar, frameColor: 0xFFFFD36A, sample: 9,
  ),
  StatusTemplate(
    id: 'love_letter', name: 'Love Letter', category: 'Love', bgKind: BgKind.solid,
    colors: [0xFFFFE0E6], pattern: PatternKind.hearts, patternColor: 0x44E0294A, fontKey: 'kalam',
    textColor: 0xFFA3122F, sample: 1,
  ),
  StatusTemplate(
    id: 'minimal_white', name: 'Minimal White', category: 'Minimal', bgKind: BgKind.solid,
    colors: [0xFFFFFFFF], fontKey: 'hind', textColor: 0xFF111111, align: OverlayAlign.left,
    frame: FrameKind.topBar, frameColor: 0xFF111111, bold: false, sizeFrac: 0.07, sample: 5,
  ),
  StatusTemplate(
    id: 'peach', name: 'Peach', category: 'Minimal', bgKind: BgKind.linear,
    colors: [0xFFFFE0C2, 0xFFFFB199], angle: 1.0, fontKey: 'poppins', textColor: 0xFF5A2E1A, bold: false, sample: 6,
  ),
  StatusTemplate(
    id: 'aurora', name: 'Aurora', category: 'Nature', bgKind: BgKind.sweep,
    colors: [0xFF0F9B8E, 0xFF5B3EA6, 0xFF1D976C, 0xFF0F9B8E], fontKey: 'hind', textColor: 0xFFFFFFFF,
    shadow: true, sample: 7,
  ),
  StatusTemplate(
    id: 'terminal', name: 'Terminal', category: 'Fun', bgKind: BgKind.solid,
    colors: [0xFF04140B], pattern: PatternKind.grid, patternColor: 0x2200FF88, fontKey: 'kalam',
    textColor: 0xFF3DFF9A, align: OverlayAlign.left, sample: 3,
  ),
  StatusTemplate(
    id: 'sky', name: 'Sky', category: 'Nature', bgKind: BgKind.linear,
    colors: [0xFF8EC5FC, 0xFFE0F7FF], angle: 1.57, pattern: PatternKind.circles, patternColor: 0x66FFFFFF,
    fontKey: 'poppins', textColor: 0xFF0D3B66, bold: false, sample: 2,
  ),
  StatusTemplate(
    id: 'chalk', name: 'Chalkboard', category: 'Fun', bgKind: BgKind.solid,
    colors: [0xFF2F4F3E], fontKey: 'kalam', textColor: 0xFFF4F1E8, frame: FrameKind.border,
    frameColor: 0xAAF4F1E8, sample: 4,
  ),
  StatusTemplate(
    id: 'retro', name: 'Retro', category: 'Fun', bgKind: BgKind.solid,
    colors: [0xFFFFE8B8], pattern: PatternKind.bands, patternColor: 0xFFE4572E, fontKey: 'rozha',
    textColor: 0xFF2B1B17, bold: false, shadow: false, sample: 0,
  ),
];

StatusTemplate templateById(String id) =>
    kStatusTemplates.firstWhere((t) => t.id == id, orElse: () => kStatusTemplates.first);

/// Ready-made messages, in both languages, indexed by [StatusTemplate.sample].
const Map<StatusLanguage, List<String>> kSampleTexts = {
  StatusLanguage.english: [
    'Believe you can and you are halfway there.',
    'Smile. It is a beautiful day.',
    'Every day is a fresh start.',
    'Dream big. Start small.',
    'Hard work always pays off.',
    'Good things take time.',
    'Good morning! Have a lovely day.',
    'Good night, sweet dreams.',
    'Happy Diwali! May your life be full of light.',
    'Eid Mubarak!',
  ],
  StatusLanguage.hindi: [
    'जो होता है, अच्छे के लिए होता है।',
    'मुस्कुराते रहिए, ज़िंदगी खूबसूरत है।',
    'हर दिन एक नई शुरुआत है।',
    'बड़े सपने देखो, छोटी शुरुआत करो।',
    'मेहनत का फल हमेशा मीठा होता है।',
    'अच्छी चीज़ों में समय लगता है।',
    'शुभ प्रभात! आपका दिन मंगलमय हो।',
    'शुभ रात्रि, मीठे सपने।',
    'दीपावली की हार्दिक शुभकामनाएँ!',
    'ईद मुबारक!',
  ],
};

String sampleFor(StatusTemplate t, StatusLanguage lang) {
  final list = kSampleTexts[lang]!;
  return list[t.sample % list.length];
}

/// True if [text] is one of the built-in samples (safe to replace when the template/language changes).
bool isSampleText(String text) {
  final t = text.trim();
  if (t.isEmpty) return true;
  return kSampleTexts.values.any((l) => l.contains(t));
}

/// Whether [text] contains Devanagari characters.
bool containsDevanagari(String text) => text.runes.any((r) => r >= 0x0900 && r <= 0x097F);
