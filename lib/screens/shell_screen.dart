import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/pill_dock.dart';
import 'about_screen.dart';
import 'favorites_screen.dart';
import 'home_screen.dart';

class ShellScreen extends StatefulWidget {
  const ShellScreen({super.key});

  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen> {
  int _index = 0;

  final _pages = const [
    HomeScreen(),
    FavoritesScreen(),
    AboutScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: Stack(
        children: [
          // Content clears the floating dock.
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 72),
              child: IndexedStack(index: _index, children: _pages),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: PillDock(
              index: _index,
              onChanged: (i) => setState(() => _index = i),
            ),
          ),
        ],
      ),
    );
  }
}
