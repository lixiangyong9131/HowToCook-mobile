import 'package:flutter_test/flutter_test.dart';
import 'package:how_to_cook/utils/recipe_parser.dart';

void main() {
  test('parses calories and cook time', () {
    const md = '''
# 红烧肉的做法

预估烹饪难度：★★★★

预估卡路里：815 大卡

这道菜大约需要 90 分钟。

## 必备原料和工具

- 五花肉 500g

## 操作

1. 切块
''';
    final p = parseRecipeMarkdown(md);
    expect(p.title, '红烧肉');
    expect(p.difficulty, 4);
    expect(p.calories, 815);
    expect(p.cookTime, const Duration(minutes: 90));
    expect(p.intro.contains('大约需要'), isTrue);
  });
}
