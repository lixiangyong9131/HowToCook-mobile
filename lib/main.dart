import 'package:flutter/material.dart';

import 'screens/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const HowToCookApp());
}

class HowToCookApp extends StatelessWidget {
  const HowToCookApp({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFFE65100),
      brightness: Brightness.light,
    );
    return MaterialApp(
      title: '程序员做饭指南',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: scheme,
        useMaterial3: true,
        appBarTheme: AppBarTheme(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          centerTitle: true,
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
