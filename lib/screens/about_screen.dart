import 'package:flutter/material.dart';

import '../services/recipe_repository.dart';
import '../theme/app_theme.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final db = RecipeRepository.instance.db;
    return Scaffold(
      appBar: AppBar(title: const Text('我的')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFF8A65), Color(0xFFE65100)],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              children: [
                Text('👨‍💻🍳', style: TextStyle(fontSize: 36)),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '程序员做饭指南',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '版本 0.2.0 · 离线可用',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _InfoCard(
            title: '菜谱来源与致谢',
            children: [
              Text(db?.attribution ??
                  '菜谱内容来自 Anduin2017/HowToCook，致谢原作者与贡献者。'),
              const SizedBox(height: 8),
              const SelectableText('https://github.com/Anduin2017/HowToCook'),
              const SizedBox(height: 6),
              Text('许可：${db?.license ?? 'Unlicense'}（公共领域）'),
              const SizedBox(height: 8),
              Text('共 ${db?.recipes.length ?? 0} 道菜已打包进 App，可完全离线浏览。'),
            ],
          ),
          const SizedBox(height: 12),
          const _InfoCard(
            title: '功能参考',
            children: [
              Text(
                '交互灵感参考微信小程序 LeeJim/HowToCookOnMiniprogram：'
                '分类侧栏浏览、搜索、分节详情（原料/计算/操作）、步骤引导、步骤计时、本地收藏。',
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
            children: [
              SelectableText(
                'https://github.com/lixiangyong9131/HowToCook-mobile',
              ),
              SizedBox(height: 8),
              Text(
                '网页版可作补充参考：https://howtocook.aiursoft.com\n'
                '当前版本以文本菜谱为主，步骤配图未内置。',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _InfoCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFE0B2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: AppTheme.seed,
            ),
          ),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }
}
