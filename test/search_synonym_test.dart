import 'package:flutter_test/flutter_test.dart';
import 'package:how_to_cook/services/recipe_repository.dart';
import 'package:how_to_cook/utils/food_synonyms.dart';

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
}
