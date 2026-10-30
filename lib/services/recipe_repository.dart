import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/recipe.dart';

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

  List<Recipe> search(String query) {
    final db = _db;
    if (db == null || query.trim().isEmpty) return const [];
    final q = query.trim().toLowerCase();
    return db.recipes
        .where((r) =>
            r.title.toLowerCase().contains(q) ||
            r.markdown.toLowerCase().contains(q) ||
            r.categoryName.contains(query.trim()))
        .toList();
  }
}
