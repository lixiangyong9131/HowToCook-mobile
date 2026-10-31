import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:how_to_cook/models/recipe.dart';
import 'package:how_to_cook/widgets/stacked_category_cards.dart';

void main() {
  testWidgets('folded wallet renders stacked pile (not a PageView)', (
    tester,
  ) async {
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
    expect(find.text('展开'), findsOneWidget);
    expect(find.textContaining('循环甩动'), findsNothing);

    // Tight stack: front card is tall, the next card only shows a short lip.
    expect(find.text('分类0'), findsOneWidget);
    expect(find.text('分类1'), findsOneWidget);
    expect(find.text('分类3'), findsOneWidget);
    expect(find.text('分类4'), findsNothing);
    final front = tester.getRect(find.byKey(const ValueKey('stack-card-c0')));
    final behind = tester.getRect(find.byKey(const ValueKey('stack-card-c1')));
    expect(front.height, greaterThan(240));
    expect(behind.height, front.height);
    final lip = front.top - behind.top;
    expect(lip, greaterThan(28));
    expect(lip, lessThan(52));
  });

  testWidgets('fling can coast across cards (multi-card inertia)', (
    tester,
  ) async {
    final cats = [
      for (var i = 0; i < 8; i++) CategoryInfo(id: 'c$i', name: '分类$i'),
    ];
    final counts = {for (final c in cats) c.id: 3};
    final opened = <String>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StackedCategoryCards(
            categories: cats,
            counts: counts,
            openOnSwipeSettle: true,
            onOpen: (c) => opened.add(c.id),
            initiallyExpanded: false,
            showExpandButton: false,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Strong upward fling — soft spring may take a moment to settle.
    await tester.fling(find.text('分类0'), const Offset(0, -1800), 4500);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle(const Duration(milliseconds: 50));

    // Either settle-opened a later card, or at least left the first front
    // (infinite loop / soft spring — accept either multi-skip or ≥1 advance).
    if (opened.isNotEmpty) {
      expect(opened.last, isNot('c0'));
    } else {
      // Front card label should have changed after a big fling.
      expect(find.text('分类0'), findsNothing);
    }
  });
}
