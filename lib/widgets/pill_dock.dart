import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

/// Light cream bottom navigation — no navy/black dock.
class PillDock extends StatelessWidget {
  final int index;
  final ValueChanged<int> onChanged;
  final List<IconData> icons;
  final List<IconData>? selectedIcons;
  final List<String> labels;
  final List<GlobalKey>? iconKeys;

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
    this.iconKeys,
  });

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Material(
      color: AppTheme.cream,
      elevation: 0,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppTheme.cream.withValues(alpha: 0.96),
          border: Border(
            top: BorderSide(
              color: AppTheme.navy.withValues(alpha: 0.08),
              width: 1,
            ),
          ),
        ),
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
                final key = (iconKeys != null && i < iconKeys!.length)
                    ? iconKeys![i]
                    : null;
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
                          key: key,
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOutCubic,
                          width: 48,
                          height: 32,
                          decoration: BoxDecoration(
                            color: selected
                                ? AppTheme.softCoral
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            icon,
                            size: 22,
                            color: selected ? AppTheme.coral : AppTheme.navy.withValues(alpha: 0.45),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight:
                                selected ? FontWeight.w800 : FontWeight.w600,
                            color: selected
                                ? AppTheme.navy
                                : AppTheme.navy.withValues(alpha: 0.45),
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
      ),
    );
  }
}
