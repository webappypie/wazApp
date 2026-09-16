// lib/core/design/tokens.dart
//
// Design tokens — the ONLY place colours, type scale, spacing, radii and
// elevation are defined. No widget may hardcode any of these values.
//
// Philosophy (PRD §9): premium finance/productivity aesthetic.
// Generous whitespace, precise typography, subtle elevation, restrained cards.

import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// Colour palette
// ---------------------------------------------------------------------------

/// Brand primary — a calm, professional blue.
const _kPrimary = Color(0xFF1C6EF2);
const _kPrimaryContainer = Color(0xFFD6E4FF);
const _kOnPrimaryContainer = Color(0xFF001A41);

/// Surface variants
const _kSurfaceLight = Color(0xFFF8F9FC);
const _kSurfaceDark = Color(0xFF111318);
const _kCardLight = Color(0xFFFFFFFF);
const _kCardDark = Color(0xFF1E2128);

/// Semantic colours — same in both themes.
const kColorSuccess = Color(0xFF1E8A4C);
const kColorWarning = Color(0xFFB45309);
const kColorDestructive = Color(0xFFDC2626);
const kColorDestructiveSurface = Color(0xFFFEF2F2);

// ---------------------------------------------------------------------------
// AppColorScheme — extends Material 3 ColorScheme with app-specific tokens
// ---------------------------------------------------------------------------

class AppColors {
  const AppColors._();

  // --- Light scheme ---
  static const ColorScheme light = ColorScheme(
    brightness: Brightness.light,
    primary: _kPrimary,
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: _kPrimaryContainer,
    onPrimaryContainer: _kOnPrimaryContainer,
    secondary: Color(0xFF3D5A8A),
    onSecondary: Color(0xFFFFFFFF),
    secondaryContainer: Color(0xFFD6E3FF),
    onSecondaryContainer: Color(0xFF001B3D),
    tertiary: Color(0xFF006A60),
    onTertiary: Color(0xFFFFFFFF),
    tertiaryContainer: Color(0xFF9EF2E4),
    onTertiaryContainer: Color(0xFF00201C),
    error: kColorDestructive,
    onError: Color(0xFFFFFFFF),
    errorContainer: Color(0xFFFFDAD6),
    onErrorContainer: Color(0xFF410002),
    surface: _kSurfaceLight,
    onSurface: Color(0xFF1A1C1E),
    surfaceContainerHighest: Color(0xFFE2E2E9),
    onSurfaceVariant: Color(0xFF44474E),
    outline: Color(0xFF74777F),
    outlineVariant: Color(0xFFC4C6D0),
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
    inverseSurface: Color(0xFF2F3033),
    onInverseSurface: Color(0xFFF1F0F4),
    inversePrimary: Color(0xFFABC7FF),
  );

  // --- Dark scheme ---
  static const ColorScheme dark = ColorScheme(
    brightness: Brightness.dark,
    primary: Color(0xFFABC7FF),
    onPrimary: Color(0xFF002F6B),
    primaryContainer: Color(0xFF164399),
    onPrimaryContainer: _kPrimaryContainer,
    secondary: Color(0xFFAAC7FF),
    onSecondary: Color(0xFF002F69),
    secondaryContainer: Color(0xFF234377),
    onSecondaryContainer: Color(0xFFD6E3FF),
    tertiary: Color(0xFF82D5C8),
    onTertiary: Color(0xFF003731),
    tertiaryContainer: Color(0xFF004F47),
    onTertiaryContainer: Color(0xFF9EF2E4),
    error: Color(0xFFFFB4AB),
    onError: Color(0xFF690005),
    errorContainer: Color(0xFF93000A),
    onErrorContainer: Color(0xFFFFDAD6),
    surface: _kSurfaceDark,
    onSurface: Color(0xFFE2E2E6),
    surfaceContainerHighest: Color(0xFF43464E),
    onSurfaceVariant: Color(0xFFC4C6D0),
    outline: Color(0xFF8E9099),
    outlineVariant: Color(0xFF44474E),
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
    inverseSurface: Color(0xFFE2E2E6),
    onInverseSurface: Color(0xFF2F3033),
    inversePrimary: _kPrimary,
  );

  /// Card surface colour — use instead of colorScheme.surface for cards.
  static Color card(BuildContext context) =>
      Theme.of(context).brightness == Brightness.light ? _kCardLight : _kCardDark;
}

// ---------------------------------------------------------------------------
// Type scale — Material 3 compliant, no arbitrary sizes
// ---------------------------------------------------------------------------

class AppTextStyles {
  AppTextStyles._();

  // Display
  static const displayLarge = TextStyle(fontSize: 57, height: 1.12, letterSpacing: -0.25, fontWeight: FontWeight.w400);
  static const displayMedium = TextStyle(fontSize: 45, height: 1.16, fontWeight: FontWeight.w400);
  static const displaySmall = TextStyle(fontSize: 36, height: 1.22, fontWeight: FontWeight.w400);

  // Headline
  static const headlineLarge = TextStyle(fontSize: 32, height: 1.25, fontWeight: FontWeight.w600);
  static const headlineMedium = TextStyle(fontSize: 28, height: 1.29, fontWeight: FontWeight.w600);
  static const headlineSmall = TextStyle(fontSize: 24, height: 1.33, fontWeight: FontWeight.w600);

  // Title
  static const titleLarge = TextStyle(fontSize: 22, height: 1.27, fontWeight: FontWeight.w600);
  static const titleMedium = TextStyle(fontSize: 16, height: 1.50, letterSpacing: 0.15, fontWeight: FontWeight.w600);
  static const titleSmall = TextStyle(fontSize: 14, height: 1.43, letterSpacing: 0.1, fontWeight: FontWeight.w600);

  // Body
  static const bodyLarge = TextStyle(fontSize: 16, height: 1.50, letterSpacing: 0.15, fontWeight: FontWeight.w400);
  static const bodyMedium = TextStyle(fontSize: 14, height: 1.43, letterSpacing: 0.25, fontWeight: FontWeight.w400);
  static const bodySmall = TextStyle(fontSize: 12, height: 1.33, letterSpacing: 0.4, fontWeight: FontWeight.w400);

  // Label
  static const labelLarge = TextStyle(fontSize: 14, height: 1.43, letterSpacing: 0.1, fontWeight: FontWeight.w600);
  static const labelMedium = TextStyle(fontSize: 12, height: 1.33, letterSpacing: 0.5, fontWeight: FontWeight.w600);
  static const labelSmall = TextStyle(fontSize: 11, height: 1.45, letterSpacing: 0.5, fontWeight: FontWeight.w600);

  static TextTheme get textTheme => const TextTheme(
        displayLarge: displayLarge,
        displayMedium: displayMedium,
        displaySmall: displaySmall,
        headlineLarge: headlineLarge,
        headlineMedium: headlineMedium,
        headlineSmall: headlineSmall,
        titleLarge: titleLarge,
        titleMedium: titleMedium,
        titleSmall: titleSmall,
        bodyLarge: bodyLarge,
        bodyMedium: bodyMedium,
        bodySmall: bodySmall,
        labelLarge: labelLarge,
        labelMedium: labelMedium,
        labelSmall: labelSmall,
      );
}

// ---------------------------------------------------------------------------
// Spacing scale (8-pt grid)
// ---------------------------------------------------------------------------

class AppSpacing {
  AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
  static const double xxxl = 64;

  /// Standard page horizontal padding.
  static const double pagePadding = md;

  /// Standard card inner padding.
  static const double cardPadding = md;

  /// Vertical gap between sections.
  static const double sectionGap = lg;
}

// ---------------------------------------------------------------------------
// Radius scale
// ---------------------------------------------------------------------------

class AppRadius {
  AppRadius._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double full = 999; // pill / fully-rounded

  static const BorderRadius cardRadius = BorderRadius.all(Radius.circular(md));
  static const BorderRadius chipRadius = BorderRadius.all(Radius.circular(full));
  static const BorderRadius buttonRadius = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius bottomSheetRadius = BorderRadius.vertical(top: Radius.circular(xl));
}

// ---------------------------------------------------------------------------
// Elevation scale
// ---------------------------------------------------------------------------

class AppElevation {
  AppElevation._();

  static const double none = 0;
  static const double low = 1;
  static const double card = 2;
  static const double modal = 6;
  static const double dialog = 12;
}

// ---------------------------------------------------------------------------
// AppTheme — assembles tokens into ThemeData
// ---------------------------------------------------------------------------

class AppTheme {
  AppTheme._();

  static ThemeData light() => _build(AppColors.light);
  static ThemeData dark() => _build(AppColors.dark);

  static ThemeData _build(ColorScheme scheme) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      textTheme: AppTextStyles.textTheme,
      scaffoldBackgroundColor: scheme.surface,
      cardTheme: CardThemeData(
        elevation: AppElevation.card,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.cardRadius),
        color: scheme.brightness == Brightness.light ? _kCardLight : _kCardDark,
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(double.infinity, 52), // ≥ 48dp tap target (REQ-SET-03)
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.buttonRadius),
          textStyle: AppTextStyles.labelLarge,
          elevation: AppElevation.none,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(double.infinity, 52),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.buttonRadius),
          textStyle: AppTextStyles.labelLarge,
        ),
      ),
      chipTheme: ChipThemeData(
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.chipRadius),
        labelStyle: AppTextStyles.labelMedium,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        type: BottomNavigationBarType.fixed,
      ),
      navigationBarTheme: NavigationBarThemeData(
        labelTextStyle: WidgetStatePropertyAll(AppTextStyles.labelSmall),
        indicatorShape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppRadius.md)),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        border: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(AppRadius.md)),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm + AppSpacing.xs,
        ),
      ),
    );
  }
}
