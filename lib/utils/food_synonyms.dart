/// Chinese cooking synonym groups for search (番茄↔西红柿, etc.).
///
/// Each inner list is one concept; any member expands to the whole group.
class FoodSynonyms {
  FoodSynonyms._();

  /// Synonym groups — keep terms longest-first friendly (2+ chars preferred).
  static const List<List<String>> groups = [
    ['西红柿', '番茄', '洋柿子'],
    ['土豆', '马铃薯', '洋芋', '土豆丝'],
    ['牛肉', '牛腩', '牛排', '牛里脊', '肥牛', '牛肉片', '牛肉丝'],
    ['猪肉', '猪里脊', '五花肉', '排骨', '猪排', '肉丝', '肉片', '瘦肉'],
    ['鸡肉', '鸡胸', '鸡腿', '鸡翅', '鸡翅根', '鸡翅中', '大鸡腿', '小鸡腿'],
    ['鸡蛋', '蛋', '鸭蛋', '鹌鹑蛋'],
    ['白菜', '大白菜', '小白菜', '奶白菜'],
    ['青菜', '油菜', '生菜', '菜心', '上海青'],
    ['豆腐', '嫩豆腐', '老豆腐', '内酯豆腐', '豆腐皮', '豆干', '豆泡'],
    ['粉条', '粉丝', '红薯粉', '宽粉', '细粉'],
    ['米线', '米粉', '河粉', '肠粉'],
    ['面条', '挂面', '拉面', '刀削面', '意面', '通心粉', '方便面'],
    ['米饭', '大米', '糯米', '糙米', '米'],
    ['虾', '大虾', '基围虾', '明虾', '虾仁', '小虾'],
    ['鱼', '带鱼', '鲈鱼', '鲤鱼', '草鱼', '鲫鱼', '鳕鱼', '三文鱼'],
    ['螃蟹', '蟹', '大闸蟹', '肉蟹', '蟹肉'],
    ['蘑菇', '香菇', '平菇', '金针菇', '杏鲍菇', '口蘑', '茶树菇'],
    ['茄子', '紫茄子', '长茄子'],
    ['黄瓜', '青瓜'],
    ['南瓜', '贝贝南瓜'],
    ['冬瓜', '节瓜'],
    ['丝瓜', '胜瓜'],
    ['苦瓜', '凉瓜'],
    ['萝卜', '白萝卜', '胡萝卜', '红萝卜', '青萝卜'],
    ['玉米', '甜玉米', '玉米粒'],
    ['花生', '花生米', '花米'],
    ['芝麻', '白芝麻', '黑芝麻'],
    ['辣椒', '青椒', '红椒', '尖椒', '朝天椒', '小米椒', '杭椒', '彩椒', '甜椒'],
    ['胡椒', '黑胡椒', '白胡椒'],
    ['花椒', '青花椒', '红花椒', '藤椒'],
    ['大蒜', '蒜', '蒜末', '蒜蓉', '蒜片', '独头蒜'],
    ['生姜', '姜', '姜片', '姜丝', '姜末'],
    ['大葱', '葱', '小葱', '香葱', '葱花', '葱段'],
    ['香菜', '芫荽'],
    ['洋葱', '葱头'],
    ['韭菜', '韭黄'],
    ['芹菜', '西芹'],
    ['菠菜', '红根菠菜'],
    ['莲藕', '藕', '藕片'],
    ['山药', '淮山'],
    ['红薯', '地瓜', '番薯', '白薯'],
    ['芋头', '香芋'],
    ['板栗', '栗子'],
    ['核桃', '胡桃'],
    ['杏仁', '巴旦木'],
    ['腰果'],
    ['牛奶', '纯牛奶', '全脂牛奶', '鲜奶'],
    ['酸奶', '优格'],
    ['黄油', '奶油', '淡奶油', '动物黄油', '植物黄油'],
    ['芝士', '奶酪', '起司', '马苏里拉'],
    ['酱油', '生抽', '老抽', '味极鲜', '酱油膏'],
    ['醋', '陈醋', '香醋', '米醋', '白醋', '黑醋'],
    ['料酒', '黄酒', '花雕'],
    ['蚝油', '耗油'],
    ['豆瓣酱', '郫县豆瓣', '辣豆瓣'],
    ['芝麻酱', '酱麻酱', '花生酱'],
    ['番茄酱', '茄汁', '西红柿酱'],
    ['淀粉', '生粉', '玉米淀粉', '土豆淀粉', '红薯淀粉'],
    ['面粉', '中筋面粉', '低筋面粉', '高筋面粉', '小麦粉'],
    ['鸡精', '味精'],
    ['盐', '食盐', '海盐'],
    ['糖', '白糖', '冰糖', '棉白糖', '砂糖', '红糖', '黄糖'],
    ['蜂蜜', '蜜'],
    ['油', '食用油', '菜籽油', '花生油', '玉米油', '橄榄油', '香油', '芝麻油', '辣椒油'],
    ['排骨', '肋排', '猪排骨', '小排'],
    ['腊肉', '腌肉', '熏肉'],
    ['香肠', '火腿肠', '肉肠', '红肠'],
    ['培根', '烟肉'],
    ['午餐肉'],
    ['皮蛋', '松花蛋', '变蛋'],
    ['咸蛋', '咸鸭蛋'],
    ['海带', '昆布'],
    ['紫菜', '海苔'],
    ['木耳', '黑木耳', '云耳'],
    ['银耳', '白木耳'],
    ['年糕', '宁式年糕', '水磨年糕'],
    ['馒头', '包子', '花卷'],
    ['饺子', '水饺', '蒸饺', '锅贴'],
    ['馄饨', '云吞', '抄手'],
    ['啤酒', '扎啤'],
    ['可乐', '可口可乐', '百事可乐'],
    ['咖啡', '拿铁'],
    ['茶', '绿茶', '红茶', '乌龙茶', '花茶'],
  ];

  static final Map<String, Set<String>> _lookup = () {
    final map = <String, Set<String>>{};
    for (final g in groups) {
      final set = g.map((e) => e.toLowerCase()).toSet();
      for (final term in set) {
        map[term] = set;
      }
    }
    return map;
  }();

  /// All dictionary terms, longest first (for greedy segmentation).
  static final List<String> _termsDesc = () {
    final terms = _lookup.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    return terms;
  }();

  /// Expand one surface form to its synonym set (at least itself).
  static Set<String> expand(String term) {
    final t = term.trim().toLowerCase();
    if (t.isEmpty) return const {};
    return _lookup[t] ?? {t};
  }

  /// Split a raw query into AND-tokens (each token = synonym set).
  ///
  /// - Whitespace / 、，,+ / separated parts are separate tokens.
  /// - Continuous Chinese like 「土豆牛肉」is greedily segmented by dictionary.
  /// - If nothing segments, the whole string is one token (with synonym expand).
  static List<Set<String>> tokensFor(String query) {
    final raw = query.trim();
    if (raw.isEmpty) return const [];

    final chunks = raw
        .split(RegExp(r'[\s　,，、+/|]+'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    final out = <Set<String>>[];
    for (final chunk in chunks) {
      final segs = _greedySegment(chunk);
      if (segs.isEmpty) {
        out.add(expand(chunk));
      } else {
        for (final s in segs) {
          out.add(expand(s));
        }
      }
    }

    // De-dupe identical synonym groups while preserving order.
    final seen = <String>{};
    final deduped = <Set<String>>[];
    for (final g in out) {
      if (g.isEmpty) continue;
      final key = (g.toList()..sort()).join('|');
      if (seen.add(key)) deduped.add(g);
    }
    return deduped;
  }

  /// Longest-match left-to-right segmentation against the synonym dictionary.
  static List<String> _greedySegment(String input) {
    final s = input.toLowerCase();
    final found = <String>[];
    var i = 0;
    while (i < s.length) {
      var hit = false;
      for (final term in _termsDesc) {
        if (term.length < 2) continue;
        if (i + term.length <= s.length && s.substring(i, i + term.length) == term) {
          found.add(term);
          i += term.length;
          hit = true;
          break;
        }
      }
      if (!hit) {
        // Skip one code unit and continue (allows 「炒」「炖」connectors).
        i += 1;
      }
    }
    return found;
  }

  /// Whether [haystack] contains any synonym from [group].
  static bool groupMatches(Set<String> group, String haystack) {
    final h = haystack.toLowerCase();
    for (final t in group) {
      if (t.isNotEmpty && h.contains(t)) return true;
    }
    return false;
  }
}
