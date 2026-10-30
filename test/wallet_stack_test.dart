import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:how_to_cook/models/recipe.dart';
import 'package:how_to_cook/widgets/stacked_category_cards.dart';

void main() {
  testWidgets('folded wallet renders stacked pile (not a PageView)', (tester) async {
    final cats = [
      for (var i = 0; i < 8; i++) CategoryInfo(id: 'c$i', name: '分类$i'),
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
    expect(find.textContaining('甩动叠卡'), findsOneWidget);
  });

  testWidgets('fling advances past more than one card then settles', (tester) async {
    final cats = [
      for (var i = 0; i < 8; i++) CategoryInfo(id: 'c$i', name: '分类$i'),
    ];
    final counts = {for (final c in cats) c.id: 3};
    String? opened;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StackedCategoryCards(
            categories: cats,
            counts: counts,
            openOnSwipeSettle: true,
            onOpen: (c) => opened = c.id,
            initiallyExpanded: false,
            showExpandButton: false,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Strong upward fling across the wallet stack area.
    final stack = find.text('分类浏览');
    expect(stack, findsOneWidget);
    await tester.fling(find.text('分类0'), const Offset(0, -1200), 3000);
    await tester.pump(); // start coast
    await tester.pump(const Duration(milliseconds: 80));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));

    // Should have coasted past card 0 — either opened a later card or at least left 分类0 focus.
    // With openOnSwipeSettle, settle fires onOpen for the new index.
    expect(opened, isNotNull);
    expect(opened, isNot('c0'));
  });
}
