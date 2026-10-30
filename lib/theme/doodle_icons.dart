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

  /// Heuristic map from 原料/工具 Chinese text → doodle asset.
  static String forIngredient(String raw) {
    final t = raw
        .replaceAll(RegExp(r'!\[.*?\]\([^)]+\)'), '')
        .replaceAll(RegExp(r'\d+(\.\d+)?'), '')
        .replaceAll(RegExp(r'[g克毫升mlML升个只条片块勺茶匙汤匙适量]'), '')
        .trim()
        .toLowerCase();

    bool has(String s) => t.contains(s);

    if (has('虾') || has('蟹') || has('贝') || has('鱼') || has('海鲜') || has('鱿鱼')) {
      if (has('虾')) return '$dir/prawn.png';
      if (has('蟹')) return '$dir/crab.png';
      return '$dir/fish.png';
    }
    if (has('牛') || has('排') || has('猪') || has('羊') || has('肉') || has('腊')) {
      if (has('肠') || has('火腿')) return '$dir/sausage.png';
      return '$dir/steak.png';
    }
    if (has('鸡') || has('鸭') || has('翅') || has('腿')) return '$dir/chicken.png';
    if (has('蛋')) return '$dir/eggs.png';
    if (has('米') || has('饭') || has('粥')) return '$dir/rice-bowl.png';
    if (has('面') || has('粉条') || has('挂面')) return '$dir/noodles.png';
    if (has('饺') || has('馄饨')) return '$dir/dumplings.png';
    if (has('面包') || has('吐司') || has('馒头') || has('饼')) return '$dir/bread.png';
    if (has('面粉') || has('淀粉') || has('麦')) return '$dir/wheat.png';
    if (has('盐') || has('味精') || has('鸡精')) return '$dir/salt-shaker.png';
    if (has('糖')) return '$dir/sugar.png';
    if (has('酱') || has('醋') || has('油') || has('蚝油') || has('酱油')) {
      if (has('辣椒') || has('辣')) return '$dir/chili-pepper.png';
      return '$dir/jam.png';
    }
    if (has('辣椒') || has('花椒') || has('胡椒') || has('辣')) return '$dir/chili-pepper.png';
    if (has('蒜')) return '$dir/garlic.png';
    if (has('葱') || has('洋葱')) return '$dir/onion.png';
    if (has('姜')) return '$dir/garlic.png';
    if (has('番茄') || has('西红柿')) return '$dir/tomato.png';
    if (has('土豆') || has('马铃薯')) return '$dir/potato.png';
    if (has('胡萝卜') || has('萝卜')) return '$dir/carrot.png';
    if (has('西兰花') || has('花菜') || has('白菜') || has('青菜') || has('菠菜') || has('生菜') || has('蔬菜')) {
      if (has('生菜')) return '$dir/lettuce.png';
      return '$dir/broccoli.png';
    }
    if (has('蘑菇') || has('香菇') || has('菌')) return '$dir/mushroom.png';
    if (has('玉米')) return '$dir/corn.png';
    if (has('豆腐')) return '$dir/cheese.png';
    if (has('奶') || has('乳')) return '$dir/milk-bottle.png';
    if (has('奶酪') || has('芝士') || has('黄油')) return '$dir/cheese.png';
    if (has('苹果')) return '$dir/apple.png';
    if (has('香蕉')) return '$dir/banana.png';
    if (has('草莓')) return '$dir/strawberry.png';
    if (has('蓝莓') || has('莓')) return '$dir/blueberry.png';
    if (has('樱桃')) return '$dir/cherry.png';
    if (has('橙') || has('橘') || has('柠檬') || has('柑')) return '$dir/citrus.png';
    if (has('咖啡')) return '$dir/coffee-to-go.png';
    if (has('茶')) return '$dir/tea.png';
    if (has('酒') || has('啤')) return '$dir/beer.png';
    if (has('水') || has('汤') || has('高汤') || has('清汤')) {
      if (has('汤')) return '$dir/soup-plate.png';
      return '$dir/water.png';
    }
    if (has('冰淇') || has('甜品') || has('蛋糕') || has('布丁')) {
      if (has('蛋糕')) return '$dir/cake.png';
      return '$dir/ice-cream-cone.png';
    }
    if (has('巧克力')) return '$dir/chocolate-bar.png';
    if (has('罐头') || has('半成品')) return '$dir/tin-can.png';
    if (has('锅') || has('铲') || has('刀') || has('叉') || has('勺') || has('碗') || has('盘') || has('工具') || has('筷子')) {
      if (has('锅')) return '$dir/cooking-pot.png';
      return '$dir/cutlery.png';
    }
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
