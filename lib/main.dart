import 'package:flutter/material.dart';

import 'screens/shell_screen.dart';
import 'services/favorites_store.dart';
import 'services/history_store.dart';
import 'services/process_image_service.dart';
import 'services/recipe_repository.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await RecipeRepository.instance.load();
  await ProcessImageService.instance.ensureLoaded();
  final favorites = FavoritesStore();
  await favorites.load();
  final history = HistoryStore();
  await history.load();
  runApp(HowToCookApp(favorites: favorites, history: history));
}

class HowToCookApp extends StatelessWidget {
  final FavoritesStore favorites;
  final HistoryStore history;
  const HowToCookApp({
    super.key,
    required this.favorites,
    required this.history,
  });

  @override
  Widget build(BuildContext context) {
    return FavoritesScope(
      store: favorites,
      child: HistoryScope(
        store: history,
        child: ListenableBuilder(
          listenable: Listenable.merge([favorites, history]),
          builder: (context, _) {
            return MaterialApp(
              title: '程序员做饭指南',
              debugShowCheckedModeBanner: false,
              theme: AppTheme.light(),
              home: const ShellScreen(),
            );
          },
        ),
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

class HistoryScope extends InheritedWidget {
  final HistoryStore store;
  const HistoryScope({super.key, required this.store, required super.child});

  static HistoryStore of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<HistoryScope>();
    assert(scope != null, 'HistoryScope not found');
    return scope!.store;
  }

  @override
  bool updateShouldNotify(HistoryScope oldWidget) => store != oldWidget.store;
}
