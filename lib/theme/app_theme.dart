import 'package:flutter/material.dart';

class AppTheme {
  static const bg = Color(0xFFF5F5F7);
  static const card = Colors.white;
  static const ink = Color(0xFF111111);
  static const muted = Color(0xFF8E8E93);
  static const lime = Color(0xFFC6FF00);
  static const lavender = Color(0xFFD1C4E9);
  static const orange = Color(0xFFFF5722);
  static const blue = Color(0xFF2979FF);
  static const blackCard = Color(0xFF1A1A1A);
  static const accent = lime;
  static const seed = Color(0xFF1A1A1A);

  /// Editorial radius used across cards / pills.
  static const radius = 26.0;
  static const radiusSm = 18.0;

  static List<BoxShadow> softShadow({double opacity = 0.08}) => [
        BoxShadow(
          color: Colors.black.withValues(alpha: opacity),
          blurRadius: 24,
          offset: const Offset(0, 10),
        ),
      ];

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.light,
      surface: bg,
      primary: ink,
      secondary: lime,
    );
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      scaffoldBackgroundColor: bg,
      fontFamily: null,
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontSize: 40,
          fontWeight: FontWeight.w900,
          letterSpacing: -1.2,
          color: ink,
          height: 1.05,
        ),
        headlineLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w900,
          letterSpacing: -0.8,
          color: ink,
        ),
        titleLarge: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: ink,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: ink,
        ),
        bodyLarge: TextStyle(fontSize: 16, height: 1.5, color: ink),
        bodyMedium: TextStyle(fontSize: 14, height: 1.45, color: ink),
        labelLarge: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: bg,
        foregroundColor: ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: ink,
          fontSize: 22,
          fontWeight: FontWeight.w900,
        ),
      ),
      cardTheme: CardThemeData(
        color: card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
      dividerColor: const Color(0xFFE5E5EA),
    );
  }
}

const categoryEmojis = <String, String>{
  'aquatic': '🦐',
  'breakfast': '🥣',
  'condiment': '🧂',
  'dessert': '🍰',
  'drink': '🥤',
  'meat_dish': '🥩',
  'semi-finished': '🍜',
  'soup': '🍲',
  'staple': '🍚',
  'vegetable_dish': '🥬',
};

/// High-contrast editorial palette cycling for stacked category cards.
const categoryCardPalette = <Color>[
  Color(0xFFC6FF00), // lime
  Color(0xFFD1C4E9), // lavender
  Color(0xFF1A1A1A), // black
  Color(0xFFFFFFFF), // white
  Color(0xFFFF5722), // orange
  Color(0xFF2979FF), // blue
  Color(0xFFCDDC39), // chartreuse
  Color(0xFFFFAB91), // soft coral
  Color(0xFFB39DDB), // soft purple
  Color(0xFF80CBC4), // teal
];

Color categoryAccent(String id, int index) {
  return categoryCardPalette[index % categoryCardPalette.length];
}

bool isDarkCard(Color c) {
  return c.computeLuminance() < 0.45;
}

/// Legacy map kept for accent lookups elsewhere.
const categoryColors = <String, Color>{
  'aquatic': Color(0xFF2979FF),
  'breakfast': Color(0xFFFF5722),
  'condiment': Color(0xFFD1C4E9),
  'dessert': Color(0xFFFFAB91),
  'drink': Color(0xFF80CBC4),
  'meat_dish': Color(0xFF1A1A1A),
  'semi-finished': Color(0xFFB39DDB),
  'soup': Color(0xFFCDDC39),
  'staple': Color(0xFFC6FF00),
  'vegetable_dish': Color(0xFF43A047),
};
