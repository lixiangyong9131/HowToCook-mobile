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
  /// - Title matches count; ingredient section preferred for AND raw queries.
  List<Recipe> search(String query) {
    final db = _db;
    if (db == null || query.trim().isEmpty) return const [];

    final tokens = FoodSynonyms.tokensFor(query);
    if (tokens.isEmpty) return const [];

    final scored = <({Recipe r, int score})>[];
    for (final r in db.recipes) {
      final title = r.title;
      final ing = _ingredientBlob(r.markdown);
      final cat = r.categoryName;
      final body = r.markdown;

      // Every token-group must hit title OR ingredients (AND across tokens).
      // Fall back to full markdown only for single-token queries so
      // 「番茄」still finds mentions outside the 原料 list.
      final useBodyFallback = tokens.length == 1;
      var allHit = true;
      var titleHits = 0;
      var ingHits = 0;
      for (final g in tokens) {
        final inTitle = FoodSynonyms.groupMatches(g, title);
        final inIng = FoodSynonyms.groupMatches(g, ing);
        final inCat = FoodSynonyms.groupMatches(g, cat);
        final inBody =
            useBodyFallback && FoodSynonyms.groupMatches(g, body);
        if (!(inTitle || inIng || inCat || inBody)) {
          allHit = false;
          break;
        }
        if (inTitle) titleHits++;
        if (inIng) ingHits++;
      }
      if (!allHit) continue;

      // Rank: all tokens in title > mix > ingredients-only.
      final score = titleHits * 100 + ingHits * 10 + (useBodyFallback ? 1 : 0);
      scored.add((r: r, score: score));
    }

    scored.sort((a, b) => b.score.compareTo(a.score));
    return scored.map((e) => e.r).toList();
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
