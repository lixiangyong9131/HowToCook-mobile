import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

/// Floating black pill bottom dock — selected tab = white circle behind icon.
class PillDock extends StatelessWidget {
  final int index;
  final ValueChanged<int> onChanged;
  final List<IconData> icons;
  final List<IconData>? selectedIcons;

  const PillDock({
    super.key,
    required this.index,
    required this.onChanged,
    this.icons = const [
      Icons.home_outlined,
      Icons.favorite_border,
      Icons.person_outline,
    ],
    this.selectedIcons = const [
      Icons.home_rounded,
      Icons.favorite,
      Icons.person,
    ],
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 0, 0, 14),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.blackCard,
              borderRadius: BorderRadius.circular(999),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.28),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(icons.length, (i) {
                final selected = i == index;
                final icon = selected
                    ? (selectedIcons?[i] ?? icons[i])
                    : icons[i];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      onChanged(i);
                    },
                    behavior: HitTestBehavior.opaque,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 240),
                      curve: Curves.easeOutCubic,
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: selected ? Colors.white : Colors.transparent,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        icon,
                        size: 24,
                        color: selected ? AppTheme.ink : Colors.white,
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}
