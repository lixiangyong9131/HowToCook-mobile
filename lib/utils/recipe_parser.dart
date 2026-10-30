import 'dart:math' as math;

/// Parse HowToCook markdown into intro + named sections.
class ParsedRecipe {
  final String title;
  final String intro;
  final int? difficulty;
  final List<RecipeSection> sections;

  const ParsedRecipe({
    required this.title,
    required this.intro,
    required this.difficulty,
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

  return ParsedRecipe(
    title: title.isEmpty ? '菜谱' : title,
    intro: introBuf.toString().trim(),
    difficulty: difficulty,
    sections: sections,
  );
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
