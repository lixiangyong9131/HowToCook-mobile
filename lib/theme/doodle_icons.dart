import 'package:flutter/material.dart';

/// Icons8 Food Doodle assets under assets/icons/doodle/.
class DoodleIcons {
  DoodleIcons._();

  static const dir = 'assets/icons/doodle';

  /// Category id → doodle asset path.
  static const category = <String, String>{
    'aquatic': '$dir/prawn.png',
    'breakfast': '$dir/sunny-side-up-eggs.png',
    'condiment': '$dir/salt-shaker.png',
    'dessert': '$dir/cheesecake.png',
    'drink': '$dir/lemonade.png',
    'meat_dish': '$dir/steak.png',
    'semi-finished': '$dir/tin-can.png',
    'soup': '$dir/soup-plate.png',
    'staple': '$dir/rice-bowl.png',
    'vegetable_dish': '$dir/broccoli.png',
  };

  static const fallback = '$dir/chef-hat.png';
  static const utensil = '$dir/cutlery.png';
  static const pot = '$dir/cooking-pot.png';
  static const basket = '$dir/shopping-basket.png';

  static String forCategory(String id) => category[id] ?? fallback;

  /// Strip markdown / amounts / units so keyword matching sees the ingredient name.
  static String normalizeIngredient(String raw) {
    return raw
        .replaceAll(RegExp(r'!\[.*?\]\([^)]+\)'), '')
        .replaceAll(RegExp(r'\[[^\]]*\]\([^)]*\)'), '')
        .replaceAll(RegExp(r'[（(].*?[）)]'), '')
        .replaceAll(RegExp(r'\d+(\.\d+)?'), '')
        .replaceAll(
          RegExp(r'(克|毫升|升|个|只|条|片|块|根|瓣|颗|粒|勺|茶匙|汤匙|适量|kg|ml|ML|g|l|L)'),
          '',
        )
        .replaceAll(RegExp(r'[^\u4e00-\u9fffA-Za-z]'), '')
        .trim()
        .toLowerCase();
  }

  /// Keyword → asset. Longer matches win so 牛奶≠steak, 面粉≠noodles, 黑胡椒≠chili.
  static const Map<String, String> keywordAssets = {
    // Dairy / fats (before 牛 / 油)
    '淡奶油': '$dir/mayonnaise.png',
    '鲜奶油': '$dir/mayonnaise.png',
    '奶油': '$dir/mayonnaise.png',
    '黄油': '$dir/cheese.png',
    '奶油芝士': '$dir/cheese.png',
    '奶酪': '$dir/cheese.png',
    '芝士': '$dir/cheese.png',
    '干酪': '$dir/cheese.png',
    '炼乳': '$dir/milk-bottle.png',
    '酸奶': '$dir/milk-bottle.png',
    '牛奶': '$dir/milk-bottle.png',
    '羊奶': '$dir/milk-bottle.png',
    '椰浆': '$dir/milk-bottle.png',
    '椰奶': '$dir/milk-bottle.png',
    '豆奶': '$dir/milk-bottle.png',
    '豆浆': '$dir/milk-bottle.png',
    '纯奶': '$dir/milk-bottle.png',
    '全脂奶': '$dir/milk-bottle.png',
    '脱脂奶': '$dir/milk-bottle.png',
    '乳清': '$dir/milk-bottle.png',
    // Flours / starches (before 面 → noodles)
    '低筋面粉': '$dir/wheat.png',
    '高筋面粉': '$dir/wheat.png',
    '中筋面粉': '$dir/wheat.png',
    '小麦粉': '$dir/wheat.png',
    '面粉': '$dir/wheat.png',
    '生粉': '$dir/wheat.png',
    '淀粉': '$dir/wheat.png',
    '玉米淀粉': '$dir/wheat.png',
    '土豆淀粉': '$dir/wheat.png',
    '澄粉': '$dir/wheat.png',
    '糯米粉': '$dir/wheat.png',
    '粘米粉': '$dir/wheat.png',
    '玉米粉': '$dir/corn.png',
    '面包糠': '$dir/bread.png',
    '面包屑': '$dir/bread.png',
    // Pepper / spice
    '黑胡椒': '$dir/pepper-grinder.png',
    '白胡椒': '$dir/pepper-grinder.png',
    '胡椒粉': '$dir/pepper-grinder.png',
    '胡椒': '$dir/pepper-grinder.png',
    '花椒': '$dir/pepper-grinder.png',
    '孜然': '$dir/pepper-grinder.png',
    '五香粉': '$dir/pepper-grinder.png',
    '咖喱': '$dir/pepper-grinder.png',
    '八角': '$dir/pepper-grinder.png',
    '桂皮': '$dir/pepper-grinder.png',
    '香叶': '$dir/organic-food.png',
    '香菜': '$dir/lettuce.png',
    '芝麻': '$dir/olive.png',
    // Chili
    '干辣椒': '$dir/chili-pepper.png',
    '小米辣': '$dir/chili-pepper.png',
    '小米椒': '$dir/chili-pepper.png',
    '青辣椒': '$dir/chili-pepper.png',
    '红辣椒': '$dir/chili-pepper.png',
    '辣椒粉': '$dir/chili-pepper.png',
    '辣椒面': '$dir/chili-pepper.png',
    '辣椒油': '$dir/chili-pepper.png',
    '辣椒': '$dir/chili-pepper.png',
    '青椒': '$dir/chili-pepper.png',
    '豆瓣酱': '$dir/jam.png',
    // Oils / sauces
    '香油': '$dir/olive.png',
    '芝麻油': '$dir/olive.png',
    '橄榄油': '$dir/olive.png',
    '花生油': '$dir/olive.png',
    '食用油': '$dir/olive.png',
    '猪油': '$dir/olive.png',
    '色拉油': '$dir/olive.png',
    '菜籽油': '$dir/olive.png',
    '蚝油': '$dir/jam.png',
    '生抽': '$dir/jam.png',
    '老抽': '$dir/jam.png',
    '酱油': '$dir/jam.png',
    '料酒': '$dir/beer.png',
    '番茄酱': '$dir/jam.png',
    '果酱': '$dir/apple-jam.png',
    '沙拉酱': '$dir/mayonnaise.png',
    '蛋黄酱': '$dir/mayonnaise.png',
    '美乃滋': '$dir/mayonnaise.png',
    '醋': '$dir/jam.png',
    '酱': '$dir/jam.png',
    '油': '$dir/olive.png',
    // Salt / sugar
    '食用盐': '$dir/salt-shaker.png',
    '食盐': '$dir/salt-shaker.png',
    '盐': '$dir/salt-shaker.png',
    '味精': '$dir/salt-shaker.png',
    '鸡精': '$dir/salt-shaker.png',
    '冰糖': '$dir/sugar.png',
    '白砂糖': '$dir/sugar.png',
    '白糖': '$dir/sugar.png',
    '糖': '$dir/sugar.png',
    // Aromatics
    '大蒜': '$dir/garlic.png',
    '蒜瓣': '$dir/garlic.png',
    '蒜苗': '$dir/garlic.png',
    '蒜': '$dir/garlic.png',
    '生姜': '$dir/garlic.png',
    '姜': '$dir/garlic.png',
    '大葱': '$dir/onion.png',
    '小葱': '$dir/onion.png',
    '香葱': '$dir/onion.png',
    '葱花': '$dir/onion.png',
    '洋葱': '$dir/onion.png',
    '葱': '$dir/onion.png',
    // Produce
    '西红柿': '$dir/tomato.png',
    '番茄': '$dir/tomato.png',
    '土豆': '$dir/potato.png',
    '马铃薯': '$dir/potato.png',
    '茄子': '$dir/beet.png',
    '胡萝卜': '$dir/carrot.png',
    '白萝卜': '$dir/carrot.png',
    '萝卜': '$dir/carrot.png',
    '西兰花': '$dir/broccoli.png',
    '花菜': '$dir/broccoli.png',
    '白菜': '$dir/lettuce.png',
    '生菜': '$dir/lettuce.png',
    '菠菜': '$dir/lettuce.png',
    '青菜': '$dir/lettuce.png',
    '蔬菜': '$dir/broccoli.png',
    '蘑菇': '$dir/mushroom.png',
    '香菇': '$dir/mushroom.png',
    '金针菇': '$dir/mushroom.png',
    '菌': '$dir/mushroom.png',
    '玉米': '$dir/corn.png',
    '豌豆': '$dir/peas.png',
    '豆腐': '$dir/cheese.png',
    '豆干': '$dir/cheese.png',
    // Fruit
    '苹果': '$dir/apple.png',
    '香蕉': '$dir/banana.png',
    '草莓': '$dir/strawberry.png',
    '蓝莓': '$dir/blueberry.png',
    '樱桃': '$dir/cherry.png',
    '柠檬': '$dir/citrus.png',
    '橙子': '$dir/citrus.png',
    '橘子': '$dir/citrus.png',
    '柑': '$dir/citrus.png',
    '橙': '$dir/citrus.png',
    '橘': '$dir/citrus.png',
    // Proteins
    '五花肉': '$dir/steak.png',
    '牛肉': '$dir/steak.png',
    '猪肉': '$dir/steak.png',
    '羊肉': '$dir/lamb.png',
    '牛排': '$dir/steak.png',
    '排骨': '$dir/steak.png',
    '火腿': '$dir/sausage.png',
    '香肠': '$dir/sausage.png',
    '腊肠': '$dir/sausage.png',
    '培根': '$dir/salami.png',
    '鸡肉': '$dir/chicken.png',
    '鸡翅': '$dir/chicken.png',
    '鸡腿': '$dir/chicken.png',
    '鸡胸': '$dir/chicken.png',
    '鸡': '$dir/chicken.png',
    '鸭': '$dir/chicken.png',
    '虾': '$dir/prawn.png',
    '蟹': '$dir/crab.png',
    '贝': '$dir/shellfish.png',
    '鱿鱼': '$dir/fish.png',
    '海鲜': '$dir/fish.png',
    '鱼': '$dir/fish.png',
    '鸡蛋': '$dir/eggs.png',
    '鸭蛋': '$dir/eggs.png',
    '皮蛋': '$dir/eggs.png',
    '蛋清': '$dir/eggs.png',
    '蛋黄': '$dir/eggs.png',
    '蛋': '$dir/eggs.png',
    // Staples
    '米饭': '$dir/rice-bowl.png',
    '糯米': '$dir/rice-bowl.png',
    '大米': '$dir/rice-bowl.png',
    '米': '$dir/rice-bowl.png',
    '粥': '$dir/porridge.png',
    '挂面': '$dir/noodles.png',
    '粉条': '$dir/noodles.png',
    '米粉': '$dir/noodles.png',
    '面条': '$dir/noodles.png',
    '意面': '$dir/noodles.png',
    '面': '$dir/noodles.png',
    '饺子': '$dir/dumplings.png',
    '馄饨': '$dir/dumplings.png',
    '饺': '$dir/dumplings.png',
    '吐司': '$dir/the-toast.png',
    '面包': '$dir/bread.png',
    '馒头': '$dir/bread.png',
    '饼': '$dir/bread.png',
    // Drinks / sweets
    '咖啡': '$dir/coffee-to-go.png',
    '红茶': '$dir/tea.png',
    '绿茶': '$dir/tea.png',
    '茶': '$dir/tea.png',
    '啤酒': '$dir/beer.png',
    '红酒': '$dir/beer.png',
    '白酒': '$dir/beer.png',
    '酒': '$dir/beer.png',
    '巧克力': '$dir/chocolate-bar.png',
    '冰淇淋': '$dir/ice-cream-cone.png',
    '冰激凌': '$dir/ice-cream-cone.png',
    '蛋糕': '$dir/cake.png',
    '布丁': '$dir/cheesecake.png',
    '罐头': '$dir/tin-can.png',
    // Liquids
    '清水': '$dir/water.png',
    '开水': '$dir/water.png',
    '高汤': '$dir/soup-plate.png',
    '清汤': '$dir/soup-plate.png',
    '汤': '$dir/soup-plate.png',
    '冰': '$dir/water.png',
    '水': '$dir/water.png',
    // Tools
    '炒锅': '$dir/cooking-pot.png',
    '汤锅': '$dir/cooking-pot.png',
    '锅': '$dir/cooking-pot.png',
    '菜刀': '$dir/knife.png',
    '刀': '$dir/knife.png',
    '铲子': '$dir/cutlery.png',
    '筷子': '$dir/cutlery.png',
    '勺子': '$dir/cutlery.png',
    '碗': '$dir/soup-plate.png',
    '盘': '$dir/tableware.png',
    '烤箱': '$dir/oven-mitten.png',
    '工具': '$dir/cutlery.png',
    // Broad meat last
    '肉': '$dir/steak.png',
    '腊': '$dir/salami.png',
    '麦': '$dir/wheat.png',
  };

  /// Heuristic map from 原料/工具 Chinese text → doodle asset.
  static String forIngredient(String raw) {
    final t = normalizeIngredient(raw);
    if (t.isEmpty) return fallback;

    String? best;
    var bestLen = 0;
    for (final entry in keywordAssets.entries) {
      if (t.contains(entry.key) && entry.key.length > bestLen) {
        best = entry.value;
        bestLen = entry.key.length;
      }
    }
    if (best != null) return best;

    if (t.contains('奶') || t.contains('乳')) return '$dir/milk-bottle.png';
    if (t.contains('粉') && !t.contains('粉条') && !t.contains('辣椒')) {
      return '$dir/wheat.png';
    }
    if (t.contains('辣')) return '$dir/chili-pepper.png';
    if (t.contains('菜')) return '$dir/lettuce.png';
    return fallback;
  }

  static Widget image(
    String asset, {
    double size = 28,
    BoxFit fit = BoxFit.contain,
  }) {
    return Image.asset(
      asset,
      width: size,
      height: size,
      fit: fit,
      filterQuality: FilterQuality.medium,
      errorBuilder: (_, __, ___) => Image.asset(
        fallback,
        width: size,
        height: size,
        fit: fit,
      ),
    );
  }

  static Widget categoryIcon(String id, {double size = 32}) =>
      image(forCategory(id), size: size);

  static Widget ingredientIcon(String text, {double size = 28}) =>
      image(forIngredient(text), size: size);
}
