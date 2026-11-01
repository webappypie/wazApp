// lib/core/design/waz_theme.dart
//
// Semantic design tokens that do not fit Material's ColorScheme: the hero gradient, card shadow,
// the one bright "signature" green, on-photo scrims and the motion scale. Pattern adapted from the
// Clenzy reference project (ThemeExtension + AppMotion); colours are WazApp's own teal/green identity.

import 'package:flutter/material.dart';

@immutable
class WazTheme extends ThemeExtension<WazTheme> {
  const WazTheme({
    required this.heroGradient,
    required this.heroGradientAlt,
    required this.cardShadow,
    required this.onHero,
    required this.onHeroMuted,
    required this.signature,
    required this.onSignature,
    required this.imageScrim,
    required this.warning,
    required this.success,
  });

  /// Brand surface: source cards, hero areas.
  final Gradient heroGradient;

  /// Second brand gradient (WhatsApp Business card) so the two sources are told apart at a glance.
  final Gradient heroGradientAlt;
  final List<BoxShadow> cardShadow;
  final Color onHero;
  final Color onHeroMuted;

  /// The single bright brand green: rings, primary calls to action on dark surfaces.
  final Color signature;
  final Color onSignature;

  /// Painted over photos so white labels stay legible.
  final Color imageScrim;
  final Color warning;
  final Color success;

  static WazTheme light() => const WazTheme(
        heroGradient: LinearGradient(
          colors: [Color(0xFF075E54), Color(0xFF128C7E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        heroGradientAlt: LinearGradient(
          colors: [Color(0xFF0B4F4A), Color(0xFF1B8F6A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        cardShadow: [BoxShadow(color: Color(0x1A075E54), blurRadius: 24, offset: Offset(0, 10))],
        onHero: Color(0xFFF2FFF8),
        onHeroMuted: Color(0xC0F2FFF8),
        signature: Color(0xFF25D366),
        onSignature: Color(0xFF06241A),
        imageScrim: Color(0xB3000000),
        warning: Color(0xFFB45309),
        success: Color(0xFF1E8A4C),
      );

  static WazTheme dark() => const WazTheme(
        heroGradient: LinearGradient(
          colors: [Color(0xFF0B3B34), Color(0xFF0E5A4D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        heroGradientAlt: LinearGradient(
          colors: [Color(0xFF0A2F33), Color(0xFF12553F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        cardShadow: [],
        onHero: Color(0xFFEFFBF4),
        onHeroMuted: Color(0xB8EFFBF4),
        signature: Color(0xFF3DDC84),
        onSignature: Color(0xFF04210F),
        imageScrim: Color(0xCC000000),
        warning: Color(0xFFF2B04E),
        success: Color(0xFF6FDCA5),
      );

  @override
  WazTheme copyWith() => this;

  @override
  WazTheme lerp(ThemeExtension<WazTheme>? other, double t) => t < 0.5 ? this : (other as WazTheme? ?? this);
}

extension WazThemeContext on BuildContext {
  WazTheme get waz => Theme.of(this).extension<WazTheme>() ?? WazTheme.light();
}

/// Motion scale. Animations are short and purposeful; the OS "remove animations" setting is honoured.
class AppMotion {
  AppMotion._();

  static const Duration fast = Duration(milliseconds: 120);
  static const Duration base = Duration(milliseconds: 220);
  static const Duration slow = Duration(milliseconds: 380);
  static const Curve standard = Curves.easeOutCubic;
  static const Curve emphasized = Curves.easeOutBack;

  static bool reduced(BuildContext context) => MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  static Duration of(BuildContext context, Duration d) => reduced(context) ? Duration.zero : d;
}
