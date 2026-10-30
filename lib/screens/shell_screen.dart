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
    // Keep bottom bar pinned when keyboard opens; search overlay handles inset.
    return Scaffold(
      backgroundColor: AppTheme.bg,
      resizeToAvoidBottomInset: false,
      body: Column(
        children: [
          Expanded(
            child: IndexedStack(index: _index, children: _pages),
          ),
          PillDock(
            index: _index,
            onChanged: (i) => setState(() => _index = i),
          ),
        ],
      ),
    );
  }
}
