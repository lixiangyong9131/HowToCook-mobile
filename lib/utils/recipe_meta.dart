import '../models/recipe.dart';
import 'recipe_parser.dart';

/// Cached front-matter meta for list filters (difficulty / time / calories).
class RecipeMeta {
  final int? difficulty;
  final int? calories;
  final Duration? cookTime;

  const RecipeMeta({
    required this.difficulty,
    required this.calories,
    required this.cookTime,
  });

  int? get cookMinutes => cookTime?.inMinutes;

  static final Map<String, RecipeMeta> _cache = {};

  static RecipeMeta of(Recipe recipe) {
    return _cache.putIfAbsent(recipe.id, () {
      final p = parseRecipeMarkdown(recipe.markdown);
      return RecipeMeta(
        difficulty: recipe.difficulty ?? p.difficulty,
        calories: p.calories,
        cookTime: p.cookTime,
      );
    });
  }

  static void clearCache() => _cache.clear();
}

enum DifficultyFilter { all, easy, medium, hard }

enum TimeFilter { all, le15, le30, le60, over60, unknown }

enum CalorieFilter { all, le300, le600, le1000, over1000, unknown }

enum RecipeSort {
  /// Keep the incoming order (search relevance).
  relevance,
  name,
  difficultyAsc,
  difficultyDesc,
  timeAsc,
  caloriesAsc,
}

bool recipeMatchesFilters(
  Recipe recipe, {
  DifficultyFilter difficulty = DifficultyFilter.all,
  TimeFilter time = TimeFilter.all,
  CalorieFilter calories = CalorieFilter.all,
}) {
  final m = RecipeMeta.of(recipe);
  switch (difficulty) {
    case DifficultyFilter.all:
      break;
    case DifficultyFilter.easy:
      if (m.difficulty == null || m.difficulty! > 2) return false;
    case DifficultyFilter.medium:
      if (m.difficulty != 3) return false;
    case DifficultyFilter.hard:
      if (m.difficulty == null || m.difficulty! < 4) return false;
  }
  final mins = m.cookMinutes;
  switch (time) {
    case TimeFilter.all:
      break;
    case TimeFilter.le15:
      if (mins == null || mins > 15) return false;
    case TimeFilter.le30:
      if (mins == null || mins > 30) return false;
    case TimeFilter.le60:
      if (mins == null || mins > 60) return false;
    case TimeFilter.over60:
      if (mins == null || mins <= 60) return false;
    case TimeFilter.unknown:
      if (mins != null) return false;
  }
  final cal = m.calories;
  switch (calories) {
    case CalorieFilter.all:
      break;
    case CalorieFilter.le300:
      if (cal == null || cal > 300) return false;
    case CalorieFilter.le600:
      if (cal == null || cal > 600) return false;
    case CalorieFilter.le1000:
      if (cal == null || cal > 1000) return false;
    case CalorieFilter.over1000:
      if (cal == null || cal <= 1000) return false;
    case CalorieFilter.unknown:
      if (cal != null) return false;
  }
  return true;
}

List<Recipe> applyRecipeFilters(
  List<Recipe> input, {
  DifficultyFilter difficulty = DifficultyFilter.all,
  TimeFilter time = TimeFilter.all,
  CalorieFilter calories = CalorieFilter.all,
  RecipeSort sort = RecipeSort.name,
}) {
  final out = input
      .where(
        (r) => recipeMatchesFilters(
          r,
          difficulty: difficulty,
          time: time,
          calories: calories,
        ),
      )
      .toList();
  switch (sort) {
    case RecipeSort.relevance:
      break;
    case RecipeSort.name:
      out.sort((a, b) => a.title.compareTo(b.title));
    case RecipeSort.difficultyAsc:
      out.sort((a, b) {
        final da = RecipeMeta.of(a).difficulty ?? 99;
        final db = RecipeMeta.of(b).difficulty ?? 99;
        final c = da.compareTo(db);
        return c != 0 ? c : a.title.compareTo(b.title);
      });
    case RecipeSort.difficultyDesc:
      out.sort((a, b) {
        final da = RecipeMeta.of(a).difficulty ?? -1;
        final db = RecipeMeta.of(b).difficulty ?? -1;
        final c = db.compareTo(da);
        return c != 0 ? c : a.title.compareTo(b.title);
      });
    case RecipeSort.timeAsc:
      out.sort((a, b) {
        final ta = RecipeMeta.of(a).cookMinutes ?? 1 << 20;
        final tb = RecipeMeta.of(b).cookMinutes ?? 1 << 20;
        final c = ta.compareTo(tb);
        return c != 0 ? c : a.title.compareTo(b.title);
      });
    case RecipeSort.caloriesAsc:
      out.sort((a, b) {
        final ca = RecipeMeta.of(a).calories ?? 1 << 20;
        final cb = RecipeMeta.of(b).calories ?? 1 << 20;
        final c = ca.compareTo(cb);
        return c != 0 ? c : a.title.compareTo(b.title);
      });
  }
  return out;
}
