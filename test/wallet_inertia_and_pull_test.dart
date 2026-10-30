import 'package:flutter/physics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:how_to_cook/widgets/stacked_category_cards.dart';

void main() {
  test('wallet friction coast travels multiple cards on strong fling', () {
    // ~1800 px/s upward with itemExtent 92 ⇒ ~19.5 pages/s
    final coast = walletCoastPages(
      startPage: 0,
      velocityPagesPerSec: 18,
    );
    // Must pass more than one card (user complaint: forced stop after one).
    expect(coast.abs(), greaterThan(2.5),
        reason: 'strong fling must coast across multiple cards, got $coast');
  });

  test('wallet weak flick stays near one card', () {
    final coast = walletCoastPages(
      startPage: 3,
      velocityPagesPerSec: 0.2,
    );
    expect(coast.abs(), lessThan(1.0));
  });

  test('FrictionSimulation end grows with velocity (sanity)', () {
    final slow = FrictionSimulation(0.085, 0, 2).x(double.infinity);
    final fast = FrictionSimulation(0.085, 0, 20).x(double.infinity);
    expect(fast, greaterThan(slow + 3));
  });
}
