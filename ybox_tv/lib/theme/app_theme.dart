import 'package:flutter/material.dart';

/// YBOX design tokens — dark, Xbox-inspired, iOS feel.
class Ybox {
  // 60% base
  static const bg = Color(0xFF0E0E10);
  static const surface = Color(0xFF1A1A1E);
  static const card = Color(0xFF232328);
  // 10% accent
  static const accent = Color(0xFF16C60C);
  static const accentDark = Color(0xFF0E7A08);
  static const danger = Color(0xFFE5484D);

  // 30% complementary: white opacity tiers
  static const textHigh = Colors.white;
  static Color textBody = Colors.white.withOpacity(0.80);
  static Color textDim = Colors.white.withOpacity(0.60);

  static const radius = 20.0;
  static const radiusSm = 14.0;

  static List<BoxShadow> glow([double opacity = 0.35]) => [
        BoxShadow(
          color: accent.withOpacity(opacity),
          blurRadius: 24,
          spreadRadius: 1,
        ),
      ];

  /// Deterministic accent-tinted card color for a group name.
  static Color groupColor(String name) {
    const palette = [
      Color(0xFF16C60C), // green
      Color(0xFF0CB4C6), // teal
      Color(0xFF7A5AF8), // purple
      Color(0xFFF59E0B), // amber
      Color(0xFFE5484D), // red
      Color(0xFF3B82F6), // blue
      Color(0xFFEC4899), // pink
      Color(0xFF10B981), // emerald
    ];
    return palette[name.hashCode.abs() % palette.length];
  }

  static ThemeData theme() {
    final base = ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      scaffoldBackgroundColor: bg,
      colorScheme: ColorScheme.fromSeed(
        seedColor: accent,
        brightness: Brightness.dark,
        surface: surface,
        primary: accent,
      ),
      // InkRipple, not InkSparkle: the sparkle runs a fragment shader that
      // stutters (and occasionally glitches) on the old GLES drivers in
      // set-top boxes, especially with Impeller disabled.
      splashFactory: InkRipple.splashFactory,
    );
    return base.copyWith(
      textTheme: base.textTheme.copyWith(
        headlineMedium: const TextStyle(
            fontSize: 28, fontWeight: FontWeight.w700, color: textHigh),
        titleLarge: const TextStyle(
            fontSize: 20, fontWeight: FontWeight.w700, color: textHigh),
        bodyMedium: TextStyle(fontSize: 16, color: textBody),
        bodySmall: TextStyle(fontSize: 13, color: textDim),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: bg,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
            fontSize: 28, fontWeight: FontWeight.w700, color: textHigh),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: card,
        contentTextStyle: const TextStyle(color: textHigh),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusSm)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: card,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSm),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSm),
          borderSide: const BorderSide(color: accent, width: 1.5),
        ),
        hintStyle: TextStyle(color: textDim),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.black,
          minimumSize: const Size.fromHeight(52),
          textStyle:
              const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radiusSm)),
        ),
      ),
    );
  }
}
