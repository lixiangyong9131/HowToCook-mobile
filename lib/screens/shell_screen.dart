import 'package:flutter/material.dart';

import '../routes/circular_reveal_route.dart';
import '../theme/app_theme.dart';
import '../widgets/pill_dock.dart';
import 'about_screen.dart';
import 'favorites_screen.dart';
import 'home_screen.dart';
import 'tips_screen.dart';

class ShellScreen extends StatefulWidget {
  const ShellScreen({super.key});

  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen>
    with SingleTickerProviderStateMixin {
  int _index = 0; // dock highlight / settled page
  int _baseIndex = 0; // page under the reveal
  int _incomingIndex = 0;
  bool _revealing = false;
  Offset _revealOrigin = Offset.zero;

  late final AnimationController _reveal;
  final _tabKeys = List.generate(4, (_) => GlobalKey());

  // Distinct instances — never mount the same one twice.
  final _pages = const <Widget>[
    HomeScreen(),
    FavoritesScreen(),
    TipsScreen(),
    AboutScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _reveal = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    )..addStatusListener((s) {
        if (s == AnimationStatus.completed && mounted) {
          setState(() {
            _baseIndex = _incomingIndex;
            _revealing = false;
          });
        }
      });
  }

  @override
  void dispose() {
    _reveal.dispose();
    super.dispose();
  }

  void _onTab(int i) {
    if (i == _index && !_revealing) return;
    final box = _tabKeys[i].currentContext?.findRenderObject() as RenderBox?;
    final origin = (box != null && box.hasSize)
        ? box.localToGlobal(box.size.center(Offset.zero))
        : Offset(
            MediaQuery.sizeOf(context).width * (i + 0.5) / 4,
            MediaQuery.sizeOf(context).height - 40,
          );
    setState(() {
      _index = i;
      _incomingIndex = i;
      _revealOrigin = origin;
      _revealing = true;
    });
    _reveal.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      resizeToAvoidBottomInset: false,
      body: Column(
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                KeyedSubtree(
                  key: ValueKey('base-$_baseIndex'),
                  child: _pages[_baseIndex],
                ),
                if (_revealing)
                  CircularReveal(
                    progress: CurvedAnimation(
                      parent: _reveal,
                      curve: const Cubic(0.4, 0.0, 0.2, 1.0),
                    ),
                    center: _revealOrigin,
                    child: KeyedSubtree(
                      key: ValueKey('in-$_incomingIndex'),
                      child: _pages[_incomingIndex],
                    ),
                  ),
              ],
            ),
          ),
          PillDock(
            index: _index,
            onChanged: _onTab,
            iconKeys: _tabKeys,
          ),
        ],
      ),
    );
  }
}
