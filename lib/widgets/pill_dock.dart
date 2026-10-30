import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

/// Navy pill dock with neon green active indicator.
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
              color: AppTheme.navy,
              borderRadius: BorderRadius.circular(999),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.purple.withValues(alpha: 0.35),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(icons.length, (i) {
                final selected = i == index;
                final icon =
                    selected ? (selectedIcons?[i] ?? icons[i]) : icons[i];
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
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: selected ? AppTheme.neon : Colors.transparent,
                        shape: BoxShape.circle,
                        boxShadow: selected
                            ? [
                                BoxShadow(
                                  color: AppTheme.neon.withValues(alpha: 0.55),
                                  blurRadius: 14,
                                ),
                              ]
                            : null,
                      ),
                      child: Icon(
                        icon,
                        size: 24,
                        color: selected ? AppTheme.navy : Colors.white,
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
