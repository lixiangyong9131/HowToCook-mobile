import 'package:flutter/material.dart';

import '../services/recipe_repository.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final db = RecipeRepository.instance;
    return Scaffold(
      appBar: AppBar(title: const Text('关于')),
      body: FutureBuilder(
        future: db.load(),
        builder: (context, snap) {
          final data = snap.data;
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text('程序员做饭指南', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              const Text('版本 0.1.0'),
              const SizedBox(height: 16),
              Text(
                data?.attribution ??
                    '菜谱内容来自 Anduin2017/HowToCook，致谢原作者与贡献者。',
              ),
              const SizedBox(height: 12),
              const Text('上游项目：'),
              SelectableText(
                data?.source ?? 'https://github.com/Anduin2017/HowToCook',
                style: TextStyle(color: Theme.of(context).colorScheme.primary),
              ),
              const SizedBox(height: 12),
              Text('许可协议：${data?.license ?? 'Unlicense'}（公共领域）'),
              const SizedBox(height: 12),
              const Text(
                '本应用将菜谱 Markdown 打包进安装包，可完全离线浏览。'
                '图片未内置；线上站点 howtocook.aiursoft.com 可作为补充参考。',
              ),
              const SizedBox(height: 24),
              const Text(
                '移动端仓库：https://github.com/lixiangyong9131/HowToCook-mobile',
              ),
            ],
          );
        },
      ),
    );
  }
}
