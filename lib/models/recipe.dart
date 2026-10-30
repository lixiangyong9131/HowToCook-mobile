class CategoryInfo {
  final String id;
  final String name;
  const CategoryInfo({required this.id, required this.name});

  factory CategoryInfo.fromJson(Map<String, dynamic> json) => CategoryInfo(
        id: json['id'] as String,
        name: json['name'] as String,
      );
}

class Recipe {
  final String id;
  final String title;
  final String categoryId;
  final String categoryName;
  final String path;
  final int? difficulty;
  final String markdown;

  const Recipe({
    required this.id,
    required this.title,
    required this.categoryId,
    required this.categoryName,
    required this.path,
    required this.difficulty,
    required this.markdown,
  });

  factory Recipe.fromJson(Map<String, dynamic> json) => Recipe(
        id: json['id'] as String,
        title: json['title'] as String,
        categoryId: json['categoryId'] as String,
        categoryName: json['categoryName'] as String,
        path: json['path'] as String,
        difficulty: json['difficulty'] as int?,
        markdown: json['markdown'] as String,
      );

  String get difficultyStars {
    if (difficulty == null) return '';
    return '★' * difficulty! + '☆' * (5 - difficulty!);
  }
}

class RecipeDatabase {
  final String source;
  final String license;
  final String attribution;
  final List<CategoryInfo> categories;
  final List<Recipe> recipes;

  const RecipeDatabase({
    required this.source,
    required this.license,
    required this.attribution,
    required this.categories,
    required this.recipes,
  });

  factory RecipeDatabase.fromJson(Map<String, dynamic> json) => RecipeDatabase(
        source: json['source'] as String? ?? '',
        license: json['license'] as String? ?? '',
        attribution: json['attribution'] as String? ?? '',
        categories: (json['categories'] as List<dynamic>)
            .map((e) => CategoryInfo.fromJson(e as Map<String, dynamic>))
            .toList(),
        recipes: (json['recipes'] as List<dynamic>)
            .map((e) => Recipe.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
