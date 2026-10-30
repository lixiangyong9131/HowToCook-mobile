import 'package:flutter/material.dart';

/// Logo-derived palette: purple→coral gradient, neon green, deep navy, lilac.
class AppTheme {
  static const purple = Color(0xFF8B7CFF);
  static const coral = Color(0xFFFF7A85);
  static const neon = Color(0xFF39FF5A);
  static const navy = Color(0xFF1A1F3A);
  static const lilac = Color(0xFFF3F0FF);
  static const card = Colors.white;
  static const muted = Color(0xFF8B8798);
  static const ink = navy;
  static const bg = lilac;
  static const accent = neon;
  static const blackCard = navy;
  static const lime = neon; // alias — old widgets used lime
  static const lavender = Color(0xFFC9C0FF);
  static const orange = coral;
  static const blue = Color(0xFF5B8CFF);
  static const seed = purple;

  static const radius = 22.0;
  static const radiusSm = 16.0;

  static const logoGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [purple, coral],
  );

  static List<BoxShadow> softShadow({double opacity = 0.12}) => [
        BoxShadow(
          color: purple.withValues(alpha: opacity),
          blurRadius: 22,
          offset: const Offset(0, 10),
        ),
        BoxShadow(
          color: Colors.black.withValues(alpha: opacity * 0.35),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ];

  /// White card with purple-tinted shadow + optional left accent bar.
  static BoxDecoration logoCard({
    Color? color,
    double radius = radius,
    bool accentBar = false,
    Color? barColor,
  }) {
    return BoxDecoration(
      color: color ?? card,
      borderRadius: BorderRadius.circular(radius),
      boxShadow: softShadow(),
      border: Border.all(color: purple.withValues(alpha: 0.10)),
      gradient: accentBar
          ? null
          : null,
    );
  }

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: purple,
      brightness: Brightness.light,
      surface: lilac,
      primary: navy,
      secondary: neon,
      tertiary: coral,
    );
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      scaffoldBackgroundColor: lilac,
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontSize: 40,
          fontWeight: FontWeight.w900,
          letterSpacing: -1.2,
          color: navy,
          height: 1.05,
        ),
        headlineLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w900,
          letterSpacing: -0.8,
          color: navy,
        ),
        titleLarge: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: navy,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: navy,
        ),
        bodyLarge: TextStyle(fontSize: 16, height: 1.5, color: navy),
        bodyMedium: TextStyle(fontSize: 14, height: 1.45, color: navy),
        labelLarge: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: lilac,
        foregroundColor: navy,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: navy,
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
      dividerColor: purple.withValues(alpha: 0.12),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: neon,
        foregroundColor: navy,
      ),
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

/// Logo-aligned colorful palette for stacked category cards.
const categoryCardPalette = <Color>[
  Color(0xFF8B7CFF), // purple
  Color(0xFFFF7A85), // coral
  Color(0xFF39FF5A), // neon
  Color(0xFF1A1F3A), // navy
  Color(0xFFC9C0FF), // lavender
  Color(0xFFFFB4A8), // soft coral
  Color(0xFF5B8CFF), // blue
  Color(0xFFFFD166), // warm
  Color(0xFF7CFFB2), // mint
  Color(0xFFFF8FB8), // pink
];

Color categoryAccent(String id, int index) {
  return categoryCardPalette[index % categoryCardPalette.length];
}

bool isDarkCard(Color c) {
  return c.computeLuminance() < 0.45;
}

const categoryColors = <String, Color>{
  'aquatic': Color(0xFF5B8CFF),
  'breakfast': Color(0xFFFF7A85),
  'condiment': Color(0xFFC9C0FF),
  'dessert': Color(0xFFFFB4A8),
  'drink': Color(0xFF7CFFB2),
  'meat_dish': Color(0xFF1A1F3A),
  'semi-finished': Color(0xFF8B7CFF),
  'soup': Color(0xFFFFD166),
  'staple': Color(0xFF39FF5A),
  'vegetable_dish': Color(0xFF39FF5A),
};
