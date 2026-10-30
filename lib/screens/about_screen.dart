import 'package:flutter/material.dart';

import '../services/recipe_repository.dart';
import '../theme/app_theme.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final db = RecipeRepository.instance.db;
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 16, 22, 40),
          children: [
            const Text(
              '我的',
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.w900,
                letterSpacing: -1,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: AppTheme.blackCard,
                borderRadius: BorderRadius.circular(AppTheme.radius),
              ),
              child: const Row(
                children: [
                  Text('👨‍💻🍳', style: TextStyle(fontSize: 36)),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '程序员做饭指南',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          '版本 0.3.0 · 离线可用',
                          style: TextStyle(
                            color: AppTheme.lime,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _InfoCard(
              title: '菜谱来源与致谢',
              accent: AppTheme.lime,
              children: [
                Text(db?.attribution ??
                    '菜谱内容来自 Anduin2017/HowToCook，致谢原作者与贡献者。'),
                const SizedBox(height: 8),
                const SelectableText(
                    'https://github.com/Anduin2017/HowToCook'),
                const SizedBox(height: 6),
                Text('许可：${db?.license ?? 'Unlicense'}（公共领域）'),
                const SizedBox(height: 8),
                Text(
                    '共 ${db?.recipes.length ?? 0} 道菜已打包进 App，可完全离线浏览。'),
              ],
            ),
            const SizedBox(height: 12),
            const _InfoCard(
              title: '功能参考',
              accent: AppTheme.lavender,
              children: [
                Text(
                  '交互灵感参考微信小程序 LeeJim/HowToCookOnMiniprogram：'
                  '分类浏览、搜索、分节详情（原料/计算/操作）、步骤引导、步骤计时、本地收藏。',
                ),
                SizedBox(height: 8),
                SelectableText(
                  'https://github.com/LeeJim/HowToCookOnMiniprogram',
                ),
              ],
            ),
            const SizedBox(height: 12),
            const _InfoCard(
              title: '本仓库',
              accent: AppTheme.orange,
              children: [
                SelectableText(
                  'https://github.com/lixiangyong9131/HowToCook-mobile',
                ),
                SizedBox(height: 8),
                Text(
                  'v0.3 视觉语言：圆角编辑风、浮动黑胶囊导航、石灰/薰衣草紫高对比动效。',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final Color accent;
  final List<Widget> children;
  const _InfoCard({
    required this.title,
    required this.children,
    this.accent = AppTheme.lime,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: const Color(0xFFE8E8ED)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: accent,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}
