import 'package:flutter/material.dart';

import 'screens/shell_screen.dart';
import 'services/favorites_store.dart';
import 'services/history_store.dart';
import 'services/process_image_service.dart';
import 'services/recipe_repository.dart';
import 'services/tips_repository.dart';
import 'services/ringtone_settings.dart';
import 'services/timer_alarm_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await RecipeRepository.instance.load();
  await TipsRepository.instance.load();
  await ProcessImageService.instance.ensureLoaded();
  await RingtoneSettings.instance.load();
  await TimerAlarmService.instance.init();
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
    // Do NOT ListenableBuilder-wrap MaterialApp — rebuilding it can drop
    // the Navigator stack and make list taps look "dead" after browse/fav updates.
    return FavoritesScope(
      store: favorites,
      child: HistoryScope(
        store: history,
        child: MaterialApp(
          navigatorKey: appNavigatorKey,
          title: '程序员做饭指南',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          home: const ShellScreen(),
        ),
      ),
    );
  }
}

class FavoritesScope extends InheritedNotifier<FavoritesStore> {
  const FavoritesScope({
    super.key,
    required FavoritesStore store,
    required super.child,
  }) : super(notifier: store);

  static FavoritesStore of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<FavoritesScope>();
    assert(scope != null, 'FavoritesScope not found');
    return scope!.notifier!;
  }
}

class HistoryScope extends InheritedNotifier<HistoryStore> {
  const HistoryScope({
    super.key,
    required HistoryStore store,
    required super.child,
  }) : super(notifier: store);

  static HistoryStore of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<HistoryScope>();
    assert(scope != null, 'HistoryScope not found');
    return scope!.notifier!;
  }
}
