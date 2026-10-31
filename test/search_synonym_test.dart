import 'package:flutter_test/flutter_test.dart';
import 'package:how_to_cook/models/recipe.dart';
import 'package:how_to_cook/services/recipe_repository.dart';
import 'package:how_to_cook/utils/food_synonyms.dart';
import 'package:how_to_cook/utils/recipe_meta.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await RecipeRepository.instance.load();
  });

  test('番茄 and 西红柿 synonym expand share a group', () {
    final a = FoodSynonyms.expand('番茄');
    final b = FoodSynonyms.expand('西红柿');
    expect(a.contains('西红柿'), isTrue);
    expect(b.contains('番茄'), isTrue);
  });

  test('土豆牛肉 tokenizes to AND tokens 土豆 + 牛肉', () {
    final tokens = FoodSynonyms.tokensFor('土豆牛肉');
    expect(tokens.length, greaterThanOrEqualTo(2));
    expect(tokens.any((g) => g.contains('土豆')), isTrue);
    expect(
      tokens.any((g) => g.contains('牛肉') || g.contains('牛腩')),
      isTrue,
    );
  });

  test('search 西红柿 finds tomato recipes', () {
    final hits = RecipeRepository.instance.search('西红柿');
    expect(hits, isNotEmpty);
    expect(
      hits.any((r) => r.title.contains('番茄') || r.title.contains('西红柿')),
      isTrue,
    );
  });

  test('search 番茄 finds 西红柿 title recipes via synonym', () {
    final hits = RecipeRepository.instance.search('番茄');
    expect(
      hits.any((r) => r.title.contains('西红柿') || r.title.contains('番茄')),
      isTrue,
    );
  });

  test('search 土豆牛肉 requires both ingredients (AND)', () {
    final hits = RecipeRepository.instance.search('土豆牛肉');
    expect(hits, isNotEmpty);
    expect(
      hits.any((r) => r.title.contains('土豆') && r.title.contains('牛')),
      isTrue,
    );
    expect(hits.any((r) => r.title == '西红柿炒鸡蛋'), isFalse);
  });

  test('exact dish name ranks first', () {
    final hits = RecipeRepository.instance.search('西红柿炒鸡蛋');
    expect(hits.first.title, '西红柿炒鸡蛋');
  });

  test('prefix dish names rank ahead of looser title hits and ingredients', () {
    final hits = RecipeRepository.instance.search('鸡蛋');
    expect(hits.first.title.startsWith('鸡蛋'), isTrue);

    final lastPrefix = hits.lastIndexWhere((r) => r.title.startsWith('鸡蛋'));
    final firstLooseTitle = hits.indexWhere(
      (r) => r.title.contains('鸡蛋') && !r.title.startsWith('鸡蛋'),
    );
    expect(lastPrefix, greaterThanOrEqualTo(0));
    expect(firstLooseTitle, greaterThan(lastPrefix));

    final lastTitle = hits.lastIndexWhere((r) => r.title.contains('蛋'));
    final firstIngredientOnly = hits.indexWhere((r) => !r.title.contains('蛋'));
    if (firstIngredientOnly != -1) {
      expect(firstIngredientOnly, greaterThan(lastTitle));
    }
  });

  test('query prefix ranks ahead of synonym-only titles', () {
    final hits = RecipeRepository.instance.search('番茄');
    expect(hits[0].title, '番茄红酱');
    expect(hits[1].title, '番茄牛肉蛋花汤');
    final firstSynonym = hits.indexWhere((r) => r.title.contains('西红柿'));
    expect(firstSynonym, greaterThan(1));
    final lastName = hits.lastIndexWhere(
      (r) => r.title.contains('番茄') || r.title.contains('西红柿'),
    );
    final firstOther = hits.indexWhere(
      (r) => !r.title.contains('番茄') && !r.title.contains('西红柿'),
    );
    if (firstOther != -1) {
      expect(firstOther, greaterThan(lastName));
    }
  });

  test('relevance sort keeps search order; name sort and filters still apply', () {
    Recipe recipe(String title, {int? difficulty}) => Recipe(
          id: title,
          title: title,
          categoryId: 'c',
          categoryName: 'c',
          path: title,
          difficulty: difficulty,
          markdown: '',
        );

    final input = [
      recipe('鸡蛋三明治', difficulty: 1),
      recipe('包菜炒鸡蛋', difficulty: 5),
    ];
    final relevance = applyRecipeFilters(
      input,
      sort: RecipeSort.relevance,
    );
    expect(relevance.map((r) => r.title).toList(), ['鸡蛋三明治', '包菜炒鸡蛋']);

    final byName = applyRecipeFilters(input, sort: RecipeSort.name);
    expect(byName.map((r) => r.title).toList(), ['包菜炒鸡蛋', '鸡蛋三明治']);

    final easy = applyRecipeFilters(
      input,
      difficulty: DifficultyFilter.easy,
      sort: RecipeSort.relevance,
    );
    expect(easy.map((r) => r.title).toList(), ['鸡蛋三明治']);

    final quick = applyRecipeFilters(
      [
        recipe('快手'),
        recipe('慢菜'),
      ],
      time: TimeFilter.le15,
      sort: RecipeSort.relevance,
    );
    expect(quick, isEmpty);
  });
}
