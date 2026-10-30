import 'package:flutter/material.dart';

/// Compact palette aligned with the bottom bar: navy + cream + coral accent.
/// No purple.
class AppTheme {
  static const navy = Color(0xFF1A1F3A);
  static const charcoal = Color(0xFF2A3148);
  static const cream = Color(0xFFFFF6EB);
  static const coral = Color(0xFFFF8A65);
  static const softCoral = Color(0xFFFFD6C4);
  static const neon = Color(0xFF39FF5A); // dock active / success accent
  static const card = Colors.white;
  static const muted = Color(0xFF8A8794);
  static const ink = navy;
  static const bg = cream;
  static const accent = neon;
  static const blackCard = navy;
  static const lime = neon;
  static const orange = coral;
  static const blue = Color(0xFF4A7C9B); // muted teal-blue, not purple
  // Backward-compat aliases (former purple → coral / navy)
  static const purple = coral;
  static const lilac = cream;
  static const lavender = softCoral;
  static const seed = navy;

  static const radius = 22.0;
  static const radiusSm = 16.0;

  static const logoGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [cream, softCoral],
  );

  static List<BoxShadow> softShadow({double opacity = 0.12}) => [
        BoxShadow(
          color: navy.withValues(alpha: opacity * 0.55),
          blurRadius: 22,
          offset: const Offset(0, 10),
        ),
        BoxShadow(
          color: Colors.black.withValues(alpha: opacity * 0.25),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ];

  /// White card with soft navy-tinted shadow.
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
      border: Border.all(color: navy.withValues(alpha: 0.08)),
    );
  }

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: navy,
      brightness: Brightness.light,
      surface: cream,
      primary: navy,
      secondary: neon,
      tertiary: coral,
    );
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      scaffoldBackgroundColor: cream,
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
        backgroundColor: cream,
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
      dividerColor: navy.withValues(alpha: 0.10),
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

/// Warm navy/coral/cream tones only (no purple).
const categoryCardPalette = <Color>[
  Color(0xFF1A1F3A), // navy
  Color(0xFFFF8A65), // coral
  Color(0xFF39FF5A), // neon
  Color(0xFFFFD6C4), // soft coral
  Color(0xFF4A7C9B), // muted teal
  Color(0xFFFFB4A8), // peach
  Color(0xFF2A3148), // charcoal
  Color(0xFFFFD166), // warm gold
  Color(0xFF7CFFB2), // mint
  Color(0xFFFFA07A), // light coral
];

Color categoryAccent(String id, int index) {
  return categoryCardPalette[index % categoryCardPalette.length];
}

bool isDarkCard(Color c) {
  return c.computeLuminance() < 0.45;
}

const categoryColors = <String, Color>{
  'aquatic': Color(0xFF4A7C9B),
  'breakfast': Color(0xFFFF8A65),
  'condiment': Color(0xFFFFD166),
  'dessert': Color(0xFFFFB4A8),
  'drink': Color(0xFF7CFFB2),
  'meat_dish': Color(0xFF1A1F3A),
  'semi-finished': Color(0xFFFFA07A),
  'soup': Color(0xFFFFD166),
  'staple': Color(0xFF39FF5A),
  'vegetable_dish': Color(0xFF39FF5A),
};
