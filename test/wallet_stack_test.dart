import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:how_to_cook/models/recipe.dart';
import 'package:how_to_cook/widgets/stacked_category_cards.dart';

void main() {
  testWidgets('folded wallet renders stacked pile (not a PageView)', (tester) async {
    final cats = [
      for (var i = 0; i < 5; i++)
        CategoryInfo(id: 'c$i', name: '分类$i'),
    ];
    final counts = {for (final c in cats) c.id: 3};

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: StackedCategoryCards(
              categories: cats,
              counts: counts,
              onOpen: (_) {},
              initiallyExpanded: false,
              showExpandButton: true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(PageView), findsNothing);
    expect(find.text('分类浏览'), findsOneWidget);
    expect(find.text('展开 ↓'), findsOneWidget);
  });
}
