import 'package:flutter/material.dart';

class AppTheme {
  static const seed = Color(0xFFE65100);
  static const cream = Color(0xFFFFF8F0);
  static const card = Colors.white;
  static const sidebarBg = Color(0xFFFFF3E0);
  static const accent = Color(0xFFFF6D00);

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.light,
      surface: cream,
    );
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      scaffoldBackgroundColor: cream,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: scheme.onSurface,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        color: card,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: scheme.primaryContainer,
        labelTextStyle: WidgetStateProperty.resolveWith((s) {
          final selected = s.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          );
        }),
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

const categoryColors = <String, Color>{
  'aquatic': Color(0xFF0288D1),
  'breakfast': Color(0xFFFFA000),
  'condiment': Color(0xFF7B1FA2),
  'dessert': Color(0xFFE91E63),
  'drink': Color(0xFF00ACC1),
  'meat_dish': Color(0xFFD84315),
  'semi-finished': Color(0xFF5D4037),
  'soup': Color(0xFF00897B),
  'staple': Color(0xFFF9A825),
  'vegetable_dish': Color(0xFF43A047),
};
