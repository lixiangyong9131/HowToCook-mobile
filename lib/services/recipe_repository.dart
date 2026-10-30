import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/recipe.dart';

class RecipeRepository {
  RecipeRepository._();
  static final RecipeRepository instance = RecipeRepository._();

  RecipeDatabase? _db;

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
