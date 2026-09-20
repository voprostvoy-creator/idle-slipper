import 'package:flutter/material.dart';

/// Игровая палитра. Тёплый «домашний» фон, сочные акценты.
class GameColors {
  GameColors._();

  static const bgTop = Color(0xFF3A2352);
  static const bgBottom = Color(0xFF1B1030);

  static const panel = Color(0xFF4A3268);
  static const panelLight = Color(0xFF6A4C90);
  static const panelDark = Color(0xFF2F1E47);
  static const outline = Color(0xFF14091F);

  static const gold = Color(0xFFFFC93C);
  static const goldLight = Color(0xFFFFE28A);
  static const goldDark = Color(0xFFC77D0E);

  static const green = Color(0xFF6BE07A);
  static const greenDark = Color(0xFF2E9C46);
  static const red = Color(0xFFFF6161);
  static const redDark = Color(0xFFB92C2C);
  static const blue = Color(0xFF5BC8FF);
  static const blueDark = Color(0xFF2478B5);
  static const orange = Color(0xFFFF9F43);

  static const cream = Color(0xFFFFF3DC);
  static const text = Color(0xFFFFF6E8);
  static const textDim = Color(0xFFCDBBE0);

  /// Коврик, на котором стоит тапок.
  static const rug = Color(0xFFB8503F);
  static const rugStripe = Color(0xFFE0A24A);
}

ThemeData buildGameTheme() {
  const font = 'Nunito';
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    fontFamily: font,
    scaffoldBackgroundColor: Colors.transparent,
    colorScheme: const ColorScheme.dark(
      primary: GameColors.gold,
      onPrimary: GameColors.outline,
      secondary: GameColors.green,
      surface: GameColors.panel,
      onSurface: GameColors.text,
      onSurfaceVariant: GameColors.textDim,
      error: GameColors.red,
    ),
  );
  // Nunito — вариативный шрифт: жирность задаём через fontVariations.
  TextStyle w(TextStyle? s, double weight, {double? size, Color? color}) =>
      (s ?? const TextStyle()).copyWith(
        fontFamily: font,
        fontVariations: [FontVariation('wght', weight)],
        fontWeight: weight >= 700 ? FontWeight.w800 : FontWeight.w600,
        fontSize: size,
        color: color ?? GameColors.text,
      );
  final t = base.textTheme;
  return base.copyWith(
    textTheme: t.copyWith(
      headlineMedium: w(t.headlineMedium, 900, size: 30),
      headlineSmall: w(t.headlineSmall, 900, size: 26),
      titleLarge: w(t.titleLarge, 800, size: 21),
      titleMedium: w(t.titleMedium, 800, size: 17),
      titleSmall: w(t.titleSmall, 800, size: 14),
      bodyLarge: w(t.bodyLarge, 600, size: 16),
      bodyMedium: w(t.bodyMedium, 600, size: 14),
      bodySmall: w(t.bodySmall, 600, size: 12, color: GameColors.textDim),
      labelLarge: w(t.labelLarge, 800, size: 15),
      labelSmall: w(t.labelSmall, 700, size: 11, color: GameColors.textDim),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      foregroundColor: GameColors.text,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: GameColors.panel,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: GameColors.outline, width: 3),
      ),
    ),
    sliderTheme: const SliderThemeData(
      activeTrackColor: GameColors.gold,
      thumbColor: GameColors.goldLight,
      inactiveTrackColor: GameColors.panelDark,
    ),
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      fillColor: GameColors.panelDark,
      border: OutlineInputBorder(
        borderSide: BorderSide(color: GameColors.outline, width: 2),
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
    ),
  );
}
