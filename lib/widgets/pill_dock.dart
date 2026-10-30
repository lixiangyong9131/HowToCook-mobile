import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

/// Full-width bottom navigation bar (flush to screen bottom).
class PillDock extends StatelessWidget {
  final int index;
  final ValueChanged<int> onChanged;
  final List<IconData> icons;
  final List<IconData>? selectedIcons;
  final List<String> labels;

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
    this.labels = const ['首页', '收藏', '我的'],
  });

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Material(
      color: AppTheme.navy,
      elevation: 12,
      shadowColor: AppTheme.navy.withValues(alpha: 0.45),
      child: Padding(
        padding: EdgeInsets.only(bottom: bottom),
        child: SizedBox(
          height: 64,
          width: double.infinity,
          child: Row(
            children: List.generate(icons.length, (i) {
              final selected = i == index;
              final icon =
                  selected ? (selectedIcons?[i] ?? icons[i]) : icons[i];
              final label = i < labels.length ? labels[i] : '';
              return Expanded(
                child: InkWell(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onChanged(i);
                  },
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                        width: 48,
                        height: 32,
                        decoration: BoxDecoration(
                          color: selected
                              ? AppTheme.neon
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          icon,
                          size: 22,
                          color: selected ? AppTheme.navy : Colors.white70,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight:
                              selected ? FontWeight.w800 : FontWeight.w600,
                          color: selected ? AppTheme.neon : Colors.white60,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
