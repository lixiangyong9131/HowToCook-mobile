import 'package:flutter/material.dart';

import 'screens/shell_screen.dart';
import 'services/favorites_store.dart';
import 'services/recipe_repository.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await RecipeRepository.instance.load();
  final favorites = FavoritesStore();
  await favorites.load();
  runApp(HowToCookApp(favorites: favorites));
}

class HowToCookApp extends StatelessWidget {
  final FavoritesStore favorites;
  const HowToCookApp({super.key, required this.favorites});

  @override
  Widget build(BuildContext context) {
    return FavoritesScope(
      store: favorites,
      child: ListenableBuilder(
        listenable: favorites,
        builder: (context, _) {
          return MaterialApp(
            title: '程序员做饭指南',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            home: const ShellScreen(),
          );
        },
      ),
    );
  }
}

class FavoritesScope extends InheritedWidget {
  final FavoritesStore store;
  const FavoritesScope({super.key, required this.store, required super.child});

  static FavoritesStore of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<FavoritesScope>();
    assert(scope != null, 'FavoritesScope not found');
    return scope!.store;
  }

  @override
  bool updateShouldNotify(FavoritesScope oldWidget) => store != oldWidget.store;
}
