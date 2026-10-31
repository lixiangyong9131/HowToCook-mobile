import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/tip.dart';
import '../services/process_image_service.dart';
import '../services/tips_repository.dart';
import '../theme/app_theme.dart';
import 'tip_detail_screen.dart';

/// Bottom-tab: Anduin2017/HowToCook 「厨房小知识」离线浏览.
class TipsScreen extends StatelessWidget {
  const TipsScreen({super.key});

  static Color _groupColor(String groupId) {
    switch (groupId) {
      case 'learn':
        return const Color(0xFFB8E0D2); // pale mint
      case 'advanced':
        return AppTheme.softCoral;
      default:
        return const Color(0xFFD6E4F0); // pale blue
    }
  }

  static IconData _groupIcon(String groupId) {
    switch (groupId) {
      case 'learn':
        return Icons.school_outlined;
      case 'advanced':
        return Icons.auto_awesome_outlined;
      default:
        return Icons.lightbulb_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = TipsRepository.instance;
    final groups = repo.groups;
    final tips = repo.tips;

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 16, 22, 4),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      '厨房小知识',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1,
                      ),
                    ),
                  ),
                  Text(
                    '${tips.length} 篇',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                      color: AppTheme.muted,
                    ),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(22, 0, 22, 10),
              child: Text(
                '热锅凉油、焯水去腥等基础与进阶技巧',
                style: TextStyle(color: AppTheme.muted, fontSize: 13),
              ),
            ),
            Expanded(
              child: tips.isEmpty
                  ? const Center(
                      child: Text('暂无小知识',
                          style: TextStyle(color: AppTheme.muted)))
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(22, 4, 22, 40),
                      children: [
                        for (final g in groups) ...[
                          _GroupHeader(
                            name: g.name,
                            icon: _groupIcon(g.id),
                            color: _groupColor(g.id),
                            count:
                                tips.where((t) => t.groupId == g.id).length,
                          ),
                          const SizedBox(height: 10),
                          for (final tip
                              in tips.where((t) => t.groupId == g.id)) ...[
                            _TipCard(
                              tip: tip,
                              accent: _groupColor(g.id),
                              icon: _groupIcon(g.id),
                              onTap: () {
                                HapticFeedback.selectionClick();
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => TipDetailScreen(tip: tip),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 10),
                          ],
                          const SizedBox(height: 12),
                        ],
                        Text(
                          repo.db?.attribution ?? '',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.muted.withValues(alpha: 0.85),
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupHeader extends StatelessWidget {
  final String name;
  final IconData icon;
  final Color color;
  final int count;
  const _GroupHeader({
    required this.name,
    required this.icon,
    required this.color,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: AppTheme.navy),
        ),
        const SizedBox(width: 8),
        Text(
          name,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: AppTheme.ink,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '$count',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppTheme.muted,
          ),
        ),
      ],
    );
  }
}

class _TipCard extends StatelessWidget {
  final KitchenTip tip;
  final Color accent;
  final IconData icon;
  final VoidCallback onTap;
  const _TipCard({
    required this.tip,
    required this.accent,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final jpeg = ProcessImageService.instance.tipAssetPath(tip.path);
    final placeholder =
        ProcessImageService.tipPlaceholderAsset(tip.path);
    return Material(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radius),
        side: BorderSide(color: AppTheme.navy.withValues(alpha: 0.08)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  width: 64,
                  height: 64,
                  child: jpeg != null
                      ? Image.asset(
                          jpeg,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              _PlaceholderThumb(
                            accent: accent,
                            asset: placeholder,
                            icon: icon,
                          ),
                        )
                      : _PlaceholderThumb(
                          accent: accent,
                          asset: placeholder,
                          icon: icon,
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tip.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.ink,
                      ),
                    ),
                    if (tip.summary.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        tip.summary,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.35,
                          color: AppTheme.muted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.chevron_right_rounded,
                color: AppTheme.navy.withValues(alpha: 0.35),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlaceholderThumb extends StatelessWidget {
  final Color accent;
  final String asset;
  final IconData icon;
  const _PlaceholderThumb({
    required this.accent,
    required this.asset,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: accent,
      child: Center(
        child: Image.asset(
          asset,
          width: 36,
          height: 36,
          errorBuilder: (_, __, ___) =>
              Icon(icon, color: AppTheme.navy, size: 28),
        ),
      ),
    );
  }
}
