import 'package:flutter_test/flutter_test.dart';
import 'package:how_to_cook/utils/recipe_parser.dart';

void main() {
  test('fuse crab recipe amounts onto ingredient names', () {
    final fused = fuseIngredientsWithAmounts(
      ingredients: [
        '青蟹（别称：肉蟹）',
        '咖喱块（推介乐惠蟹黄咖喱）',
        '洋葱',
        '椰浆',
        '鸡蛋',
        '生粉（别称：淀粉）',
        '大蒜',
      ],
      calcLines: [
        '每次制作前需要确定计划做几份。一份正好够 1 个人食用',
        '总量：',
        '肉蟹 1 只（大约 300g） * 份数',
        '咖喱块 15g（一小块）*份数',
        '椰浆 100ml*份数',
        '鸡蛋 1 个 *份数',
        '洋葱 200g *份数',
        '大蒜 5 瓣 *份数',
      ],
    );
    expect(fused.any((e) => e.contains('鸡蛋') && e.contains('1')), isTrue);
    expect(fused.any((e) => e.contains('洋葱') && e.contains('200')), isTrue);
    expect(fused.any((e) => e.contains('——')), isFalse);
    // 肉蟹 alias should fuse onto 青蟹 line
    expect(
      fused.any((e) => e.contains('青蟹') && e.contains('1')),
      isTrue,
    );
  });
}
