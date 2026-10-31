import 'dart:math' as math;

/// Parse HowToCook markdown into intro + named sections.
class ParsedRecipe {
  final String title;
  final String intro;
  final int? difficulty;
  /// e.g. 815 from 「预估卡路里：815 大卡」
  final int? calories;
  /// Estimated cook duration from intro prose when present.
  final Duration? cookTime;
  final List<RecipeSection> sections;

  const ParsedRecipe({
    required this.title,
    required this.intro,
    required this.difficulty,
    required this.calories,
    required this.cookTime,
    required this.sections,
  });
}

class RecipeSection {
  final String title;
  final String body;
  final List<String> items; // list bullets or steps
  final bool isSteps;

  const RecipeSection({
    required this.title,
    required this.body,
    required this.items,
    required this.isSteps,
  });
}

ParsedRecipe parseRecipeMarkdown(String markdown) {
  final lines = markdown.replaceAll('\r\n', '\n').split('\n');
  String title = '';
  final introBuf = StringBuffer();
  int? difficulty;
  int? calories;
  final sections = <RecipeSection>[];

  String? currentTitle;
  final currentBody = StringBuffer();
  final currentItems = <String>[];

  void flush() {
    if (currentTitle == null) return;
    final title = currentTitle!;
    final isSteps = title.contains('操作') || title.contains('步骤');
    sections.add(RecipeSection(
      title: title,
      body: currentBody.toString().trim(),
      items: List<String>.from(currentItems),
      isSteps: isSteps,
    ));
    currentTitle = null;
    currentBody.clear();
    currentItems.clear();
  }

  for (final raw in lines) {
    final line = raw.trimRight();
    final h1 = RegExp(r'^#\s+(.+)$').firstMatch(line);
    if (h1 != null && title.isEmpty) {
      title = h1.group(1)!.trim();
      if (title.endsWith('的做法')) title = title.substring(0, title.length - 3);
      continue;
    }
    final h2 = RegExp(r'^##\s+(.+)$').firstMatch(line);
    if (h2 != null) {
      flush();
      currentTitle = h2.group(1)!.trim();
      continue;
    }
    // skip images
    if (RegExp(r'!\[.*?\]\([^)]+\)').hasMatch(line) &&
        line.trim().startsWith('![')) {
      continue;
    }
    final diff = RegExp(r'预估烹饪难度[：:]\s*(★+)').firstMatch(line);
    if (diff != null) {
      difficulty = diff.group(1)!.length;
      continue;
    }
    final cal = RegExp(r'预估卡路里[：:]\s*(\d+)\s*大卡').firstMatch(line);
    if (cal != null) {
      calories = int.tryParse(cal.group(1)!);
      continue;
    }
    if (currentTitle == null) {
      if (line.trim().isNotEmpty && !line.trim().startsWith('#')) {
        introBuf.writeln(line);
      }
      continue;
    }
    final bullet = RegExp(r'^[-*+]\s+(.+)$').firstMatch(line.trim());
    final numbered = RegExp(r'^\d+\.\s+(.+)$').firstMatch(line.trim());
    if (bullet != null) {
      currentItems.add(bullet.group(1)!.trim());
    } else if (numbered != null) {
      currentItems.add(numbered.group(1)!.trim());
    } else {
      currentBody.writeln(line);
    }
  }
  flush();

  final introRaw = introBuf.toString().trim();
  final cookTime = _extractCookTime(introRaw);

  return ParsedRecipe(
    title: title.isEmpty ? '菜谱' : title,
    intro: introRaw,
    difficulty: difficulty,
    calories: calories,
    cookTime: cookTime,
    sections: sections,
  );
}

Duration? _extractCookTime(String intro) {
  final patterns = <RegExp>[
    RegExp(r'大约需要\s*(\d+)\s*分钟'),
    RegExp(r'约需\s*(\d+)\s*分钟'),
    RegExp(r'大约\s*(\d+)\s*分钟'),
    RegExp(r'一般\s*(\d+)\s*分钟'),
    RegExp(r'需(?:要)?\s*(\d+)\s*分钟'),
    RegExp(r'(\d+)\s*分钟(?:就能|即可|左右|出锅)'),
  ];
  for (final re in patterns) {
    final m = re.firstMatch(intro);
    if (m != null) {
      final n = int.tryParse(m.group(1)!);
      if (n != null && n > 0) return Duration(minutes: n);
    }
  }
  final hour = RegExp(r'大约需要\s*(\d+)\s*小时').firstMatch(intro);
  if (hour != null) {
    final n = int.tryParse(hour.group(1)!);
    if (n != null && n > 0) return Duration(hours: n);
  }
  if (intro.contains('半小时') || intro.contains('半个小时')) {
    return const Duration(minutes: 30);
  }
  return null;
}

/// Extract first timer duration in milliseconds from step text.
/// Supports: 30分钟 / 三十分钟 / 5 分钟 / 10秒 / 半小时 etc.
Duration? extractStepDuration(String text) {
  final arabicMin = RegExp(r'(\d+)\s*分钟').firstMatch(text);
  if (arabicMin != null) {
    return Duration(minutes: int.parse(arabicMin.group(1)!));
  }
  final arabicSec = RegExp(r'(\d+)\s*秒').firstMatch(text);
  if (arabicSec != null) {
    return Duration(seconds: int.parse(arabicSec.group(1)!));
  }
  final arabicHour = RegExp(r'(\d+)\s*小时').firstMatch(text);
  if (arabicHour != null) {
    return Duration(hours: int.parse(arabicHour.group(1)!));
  }
  if (text.contains('半小时') || text.contains('半个小时')) {
    return const Duration(minutes: 30);
  }
  // simple Chinese numerals for minutes
  final cn = RegExp(r'([一二三四五六七八九十两半百]+)\s*分钟').firstMatch(text);
  if (cn != null) {
    final n = _cnToInt(cn.group(1)!);
    if (n != null && n > 0) return Duration(minutes: n);
  }
  return null;
}

int? _cnToInt(String s) {
  const map = {
    '零': 0,
    '一': 1,
    '二': 2,
    '两': 2,
    '三': 3,
    '四': 4,
    '五': 5,
    '六': 6,
    '七': 7,
    '八': 8,
    '九': 9,
    '十': 10,
    '百': 100,
  };
  if (s == '半') return null;
  if (s == '十') return 10;
  if (s.length == 1) return map[s];
  if (s.startsWith('十')) {
    return 10 + (map[s.substring(1)] ?? 0);
  }
  if (s.endsWith('十')) {
    return (map[s[0]] ?? 1) * 10;
  }
  if (s.contains('十')) {
    final parts = s.split('十');
    return (map[parts[0]] ?? 1) * 10 + (map[parts[1]] ?? 0);
  }
  // fallback: multiply digits
  var total = 0;
  for (final ch in s.split('')) {
    total = total * 10 + (map[ch] ?? 0);
  }
  return total == 0 ? null : math.max(total, 1);
}


/// Fuse 「必备原料」 names with 「计算」 amounts into one line each.
///
/// Examples:
///   鸡蛋 + `鸡蛋 1 个 *份数` → `鸡蛋 1 个`
///   生抽 + `生抽 = 30 毫升` → `生抽 30 毫升`
List<String> fuseIngredientsWithAmounts({
  required List<String> ingredients,
  required List<String> calcLines,
}) {
  final amounts = <_CalcAmount>[];
  for (final raw in calcLines) {
    final parsed = _parseCalcLine(raw);
    if (parsed != null) amounts.add(parsed);
  }

  final used = <int>{};
  final out = <String>[];

  for (final ing in ingredients) {
    final name = _ingredientKey(ing);
    if (name.isEmpty) {
      out.add(ing);
      continue;
    }
    final idx = _bestAmountMatch(name, amounts, used);
    if (idx == null) {
      out.add(ing.trim());
      continue;
    }
    used.add(idx);
    final a = amounts[idx];
    out.add(_formatFused(ing.trim(), a.amount));
  }

  // Orphan calc lines that look like concrete amounts (e.g. water not listed).
  for (var i = 0; i < amounts.length; i++) {
    if (used.contains(i)) continue;
    final a = amounts[i];
    if (a.amount.isEmpty) continue;
    out.add('${a.name} ${a.amount}'.trim());
  }
  return out;
}

class _CalcAmount {
  final String name;
  final String amount;
  const _CalcAmount(this.name, this.amount);
}

_CalcAmount? _parseCalcLine(String raw) {
  var t = raw.trim();
  if (t.isEmpty) return null;
  t = t.replaceFirst(RegExp(r'^[-*+]\s+'), '');
  if (t.contains('每次制作前需要确定计划做几份')) return null;
  if (t == '总量：' || t == '总量:' || t == '每份：' || t == '每份:') return null;
  if (t.startsWith('以下是') || t.startsWith('按比例')) return null;

  // Strip trailing "* 份数" / "*份数"
  t = t.replaceAll(RegExp(r'\s*\*\s*份数\s*$'), '');
  t = t.replaceAll(RegExp(r'\s*×\s*份数\s*$'), '');

  // NAME = AMOUNT
  final eq = RegExp(r'^(.+?)\s*=\s*(.+)$').firstMatch(t);
  if (eq != null) {
    final name = eq.group(1)!.trim();
    final amount = eq.group(2)!.trim();
    if (name.isNotEmpty && amount.isNotEmpty) {
      return _CalcAmount(_stripAlias(name), amount);
    }
  }

  // NAME AMOUNT…  (amount starts with digit / 两 / 半 / 一…)
  final spaced = RegExp(
    r'^([^\d]+?)\s+(\d.*|两.+|半.+|[一二三四五六七八九十].+)$',
  ).firstMatch(t);
  if (spaced != null) {
    final name = spaced.group(1)!.trim();
    final amount = spaced.group(2)!.trim();
    if (name.isNotEmpty && amount.isNotEmpty) {
      return _CalcAmount(_stripAlias(name), amount);
    }
  }

  return null;
}

String _stripAlias(String name) {
  // "青蟹（别称：肉蟹）" → keep full for display keying via aliases below
  return name.trim();
}

String _ingredientKey(String ing) {
  var t = ing.trim();
  t = t.replaceFirst(RegExp(r'^[-*+]\s+'), '');
  // Prefer alias in parentheses if present: 青蟹（别称：肉蟹） → also match 肉蟹
  return t;
}

List<String> _nameVariants(String raw) {
  final out = <String>{};
  var t = raw.trim();
  out.add(t);
  // strip （别称：xxx） / (别称:xxx) / （xxx）
  final alias = RegExp(r'[（(]别称[：:]([^）)]+)[）)]').firstMatch(t);
  if (alias != null) {
    out.add(alias.group(1)!.trim());
    t = t.replaceAll(alias.group(0)!, '').trim();
    out.add(t);
  }
  final paren = RegExp(r'[（(]([^）)]+)[）)]').firstMatch(raw);
  if (paren != null) {
    out.add(paren.group(1)!.trim());
    out.add(raw.replaceAll(paren.group(0)!, '').trim());
  }
  // also drop spaces
  out.add(t.replaceAll(' ', ''));
  return out.where((e) => e.isNotEmpty).toList();
}

int? _bestAmountMatch(
  String ingredient,
  List<_CalcAmount> amounts,
  Set<int> used,
) {
  final variants = _nameVariants(ingredient);
  // 1) exact / contains match preferring longer names
  int? best;
  var bestScore = -1;
  for (var i = 0; i < amounts.length; i++) {
    if (used.contains(i)) continue;
    final n = amounts[i].name;
    final nVars = _nameVariants(n);
    for (final v in variants) {
      for (final nv in nVars) {
        var score = -1;
        if (v == nv) {
          score = 100 + v.length;
        } else if (v.contains(nv) || nv.contains(v)) {
          score = 50 + (v.length < nv.length ? v.length : nv.length);
        }
        if (score > bestScore) {
          bestScore = score;
          best = i;
        }
      }
    }
  }
  return bestScore >= 50 ? best : null;
}

String _formatFused(String ingredient, String amount) {
  // If ingredient already contains a digit amount, keep as-is.
  if (RegExp(r'\d').hasMatch(ingredient) &&
      (ingredient.contains('g') ||
          ingredient.contains('克') ||
          ingredient.contains('个') ||
          ingredient.contains('ml') ||
          ingredient.contains('毫升'))) {
    return ingredient;
  }
  // Prefer clean display name without long alias when amount present.
  var name = ingredient;
  final alias = RegExp(r'[（(]别称[：:][^）)]+[）)]').firstMatch(name);
  if (alias != null) {
    name = name.replaceAll(alias.group(0)!, '').trim();
  }
  // Avoid duplicating if amount already starts with name
  if (amount.startsWith(name)) return amount;
  return '$name $amount';
}
