import 'package:flutter_test/flutter_test.dart';
import 'package:how_to_cook/theme/doodle_icons.dart';

void main() {
  group('DoodleIcons.forIngredient', () {
    String file(String raw) =>
        DoodleIcons.forIngredient(raw).split('/').last;

    test('milk / cream / butter not steak or jam jar', () {
      expect(file('牛奶'), 'milk-bottle.png');
      expect(file('纯牛奶 200ml'), 'milk-bottle.png');
      expect(file('淡奶油'), 'mayonnaise.png');
      expect(file('鲜奶油 100g'), 'mayonnaise.png');
      expect(file('黄油'), 'cheese.png');
      expect(file('黄油 20g'), 'cheese.png');
    });

    test('flour not noodles', () {
      expect(file('面粉'), 'wheat.png');
      expect(file('低筋面粉'), 'wheat.png');
      expect(file('淀粉'), 'wheat.png');
      expect(file('生粉（别称：淀粉）'), 'wheat.png');
      expect(file('面条'), 'noodles.png');
      expect(file('挂面'), 'noodles.png');
    });

    test('pepper vs chili', () {
      expect(file('黑胡椒'), 'pepper-grinder.png');
      expect(file('黑胡椒粉'), 'pepper-grinder.png');
      expect(file('白胡椒粉'), 'pepper-grinder.png');
      expect(file('胡椒粉'), 'pepper-grinder.png');
      expect(file('干辣椒'), 'chili-pepper.png');
      expect(file('小米辣'), 'chili-pepper.png');
    });

    test('common Chinese staples', () {
      expect(file('盐'), 'salt-shaker.png');
      expect(file('食用盐'), 'salt-shaker.png');
      expect(file('白糖'), 'sugar.png');
      expect(file('生抽'), 'jam.png');
      expect(file('食用油'), 'olive.png');
      expect(file('大蒜'), 'garlic.png');
      expect(file('鸡蛋'), 'eggs.png');
      expect(file('牛肉'), 'steak.png');
      expect(file('五花肉'), 'steak.png');
      expect(file('虾'), 'prawn.png');
      expect(file('土豆'), 'potato.png');
      expect(file('番茄'), 'tomato.png');
    });

    test('normalize strips amounts', () {
      expect(
        DoodleIcons.normalizeIngredient('牛奶 200ml'),
        contains('牛奶'),
      );
      expect(file('牛奶 200ml'), 'milk-bottle.png');
    });
  });
}
