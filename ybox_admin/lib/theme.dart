import 'package:flutter/material.dart';

/// YBOX Admin design system — dark base, admin-blue accent, 8pt grid.
class YColors {
  static const Color bg = Color(0xFF0E0E10);
  static const Color surface = Color(0xFF1A1A1E);
  static const Color card = Color(0xFF232328);
  static const Color accent = Color(0xFF0CA0DC); // admin blue
  static const Color green = Color(0xFF16C60C);
  static const Color danger = Color(0xFFE81123);

  static Color text([double opacity = 1.0]) => Colors.white.withOpacity(opacity);

  /// Accent at low opacity — secondary buttons / subtle highlights.
  static Color accentSoft([double opacity = 0.08]) => accent.withOpacity(opacity);
}

/// Spacing scale (8pt grid).
class YSpace {
  static const double xs = 4;
  static const double s = 8;
  static const double m = 16;
  static const double l = 24;
  static const double xl = 32;
  static const double xxl = 48;
}

class YText {
  static const TextStyle title = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    color: Colors.white,
    letterSpacing: -0.5,
  );
  static const TextStyle section = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    color: Colors.white,
  );
  static TextStyle body = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: YColors.text(0.8),
  );
  static TextStyle caption = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: YColors.text(0.6),
  );
  static const TextStyle mono = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    color: Colors.white,
    fontFeatures: [FontFeature.tabularFigures()],
    letterSpacing: 1.2,
  );
}

ThemeData buildAdminTheme() {
  final base = ThemeData(
    brightness: Brightness.dark,
    useMaterial3: true,
    scaffoldBackgroundColor: YColors.bg,
    colorScheme: const ColorScheme.dark(
      primary: YColors.accent,
      secondary: YColors.accent,
      surface: YColors.surface,
      error: YColors.danger,
    ),
  );
  return base.copyWith(
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: YText.title,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: YColors.card,
      contentTextStyle: TextStyle(color: YColors.text(0.9)),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? Colors.white : YColors.text(0.6),
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? YColors.accent : YColors.card,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: YColors.surface,
      hintStyle: TextStyle(color: YColors.text(0.4)),
      labelStyle: TextStyle(color: YColors.text(0.6)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: YColors.accent, width: 1.5),
      ),
    ),
    dividerTheme: DividerThemeData(color: YColors.text(0.08), thickness: 1),
  );
}
