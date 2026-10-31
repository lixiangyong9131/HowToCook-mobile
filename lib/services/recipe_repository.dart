import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/recipe.dart';
import '../utils/food_synonyms.dart';

/// Duck type for browse history rows (avoids importing history_store).
abstract class BrowseEntryLike {
  String get id;
  String get title;
  String get categoryId;
}

class RecipeRepository {
  RecipeRepository._();
  static final RecipeRepository instance = RecipeRepository._();

  RecipeDatabase? _db;

  RecipeDatabase? get db => _db;

  Future<RecipeDatabase> load() async {
    if (_db != null) return _db!;
    final raw = await rootBundle.loadString('assets/recipes_db.json');
    _db = RecipeDatabase.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    return _db!;
  }

  List<Recipe> byCategory(String categoryId) {
    final db = _db;
    if (db == null) return const [];
    return db.recipes.where((r) => r.categoryId == categoryId).toList();
  }

  Recipe? byId(String id) {
    final db = _db;
    if (db == null) return null;
    try {
      return db.recipes.firstWhere((r) => r.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Resolve a 最近浏览 entry: id first, then title+categoryId, then title.
  /// Guards against stale ids after a recipes_db rebuild.
  Recipe? resolveBrowse(BrowseEntryLike entry) {
    final byExact = byId(entry.id);
    if (byExact != null) return byExact;
    final db = _db;
    if (db == null) return null;
    final cat = entry.categoryId;
    final title = entry.title;
    if (cat.isNotEmpty && title.isNotEmpty) {
      try {
        return db.recipes.firstWhere(
          (r) => r.categoryId == cat && r.title == title,
        );
      } catch (_) {}
    }
    if (title.isNotEmpty) {
      try {
        return db.recipes.firstWhere((r) => r.title == title);
      } catch (_) {}
    }
    return null;
  }

  /// Search with Chinese food synonyms + multi-token AND.
  ///
  /// - 「番茄」↔「西红柿」via [FoodSynonyms].
  /// - 「土豆牛肉」/「土豆 牛肉」→ ingredients (or title) must match BOTH tokens.
  /// - Rank bands, best first: exact title, title prefix, title contains the
  ///   query, other title hits (synonyms), then ingredient-only.
  ///   Within a band, higher title overlap ranks first.
  List<Recipe> search(String query) {
    final db = _db;
    final qRaw = query.trim();
    if (db == null || qRaw.isEmpty) return const [];

    final tokens = FoodSynonyms.tokensFor(qRaw);
    if (tokens.isEmpty) return const [];
    final q = qRaw.toLowerCase();

    final scored = <({Recipe r, int score})>[];
    for (final r in db.recipes) {
      final title = r.title.toLowerCase();
      final ing = _ingredientBlob(r.markdown);
      final cat = r.categoryName;
      final body = r.markdown;

      // Every token-group must hit title OR ingredients (AND across tokens).
      // Fall back to full markdown only for single-token queries so
      // 「番茄」still finds mentions outside the 原料 list.
      final useBodyFallback = tokens.length == 1;
      var allHit = true;
      var titleTokenHits = 0;
      var titleRankSum = 0;
      var matchedChars = 0;
      var ingHits = 0;
      for (final g in tokens) {
        final hit = _bestTitleHit(title, g);
        final inIng = FoodSynonyms.groupMatches(g, ing);
        final inCat = FoodSynonyms.groupMatches(g, cat);
        final inBody = useBodyFallback && FoodSynonyms.groupMatches(g, body);
        if (hit.rank == 0 && !inIng && !inCat && !inBody) {
          allHit = false;
          break;
        }
        if (hit.rank > 0) {
          titleTokenHits++;
          titleRankSum += hit.rank;
          matchedChars += hit.length;
        }
        if (inIng) ingHits++;
      }
      if (!allHit) continue;

      final phrase = _phraseRank(title, q);
      // 0 exact title … 5 no title hit (ingredients / body / category only).
      final int tier;
      if (phrase == 3) {
        tier = 0;
      } else if (phrase == 2) {
        tier = 1;
      } else if (phrase == 1) {
        tier = 2;
      } else if (titleTokenHits == tokens.length) {
        tier = 3;
      } else if (titleTokenHits > 0) {
        tier = 4;
      } else {
        tier = 5;
      }

      final overlap = phrase > 0 ? q.length : matchedChars;
      final coverage = title.isEmpty
          ? 0
          : (overlap * 100 ~/ title.length).clamp(0, 100).toInt();
      final within = titleRankSum * 10000 +
          coverage * 100 +
          matchedChars.clamp(0, 80).toInt() +
          ingHits;
      // Tier always dominates the within-band score.
      final score = (5 - tier) * 1000000 + within;
      scored.add((r: r, score: score));
    }

    scored.sort((a, b) {
      final c = b.score.compareTo(a.score);
      if (c != 0) return c;
      return a.r.title.compareTo(b.r.title);
    });
    return scored.map((e) => e.r).toList();
  }

  /// 3 exact title, 2 prefix, 1 substring, 0 miss. Longer synonym wins ties.
  static ({int rank, int length}) _bestTitleHit(
    String titleLower,
    Set<String> group,
  ) {
    var rank = 0;
    var length = 0;
    for (final term in group) {
      if (term.isEmpty) continue;
      final r = titleLower == term
          ? 3
          : titleLower.startsWith(term)
              ? 2
              : titleLower.contains(term)
                  ? 1
                  : 0;
      if (r > rank || (r == rank && r > 0 && term.length > length)) {
        rank = r;
        length = term.length;
      }
    }
    return (rank: rank, length: length);
  }

  /// How the raw query sits in the title: 3 exact, 2 prefix, 1 contains, 0 no.
  static int _phraseRank(String titleLower, String queryLower) {
    if (queryLower.isEmpty) return 0;
    if (titleLower == queryLower) return 3;
    if (titleLower.startsWith(queryLower)) return 2;
    if (titleLower.contains(queryLower)) return 1;
    return 0;
  }

  /// Pull 原料 / 用料 section list text for ingredient-oriented matching.
  static String _ingredientBlob(String markdown) {
    final lines = markdown.split('\n');
    final buf = StringBuffer();
    var inIng = false;
    for (final line in lines) {
      final t = line.trim();
      if (t.startsWith('##')) {
        final h = t.replaceFirst(RegExp(r'^##\s*'), '');
        inIng = h.contains('原料') || h.contains('用料') || h.contains('配料');
        continue;
      }
      if (!inIng) continue;
      if (t.startsWith('#')) break;
      buf.writeln(t);
    }
    // Also fold 「计算」amounts block — often repeats ingredient names.
    inIng = false;
    for (final line in lines) {
      final t = line.trim();
      if (t.startsWith('##')) {
        final h = t.replaceFirst(RegExp(r'^##\s*'), '');
        inIng = h.contains('计算');
        continue;
      }
      if (!inIng) continue;
      if (t.startsWith('#')) break;
      buf.writeln(t);
    }
    return buf.toString();
  }
}
