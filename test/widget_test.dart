import 'package:flutter_test/flutter_test.dart';
import 'package:how_to_cook/main.dart';
import 'package:how_to_cook/services/favorites_store.dart';
import 'package:how_to_cook/services/recipe_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    // Asset loading works in flutter test for package assets
    await RecipeRepository.instance.load();
  });

  testWidgets('Shell shows home title', (tester) async {
    final fav = FavoritesStore();
    await fav.load();
    await tester.pumpWidget(HowToCookApp(favorites: fav));
    await tester.pump(); // first frame
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('程序员做饭指南'), findsWidgets);
    expect(find.text('首页'), findsOneWidget);
    expect(find.text('收藏'), findsOneWidget);
  });
}
