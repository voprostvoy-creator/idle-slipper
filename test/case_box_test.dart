import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:idle_slipper/game/case_box.dart';
import 'package:idle_slipper/game/slipper_kind.dart';

void main() {
  test('chances sum to 1 and follow rarity order', () {
    final ch = CaseBox.chances();
    expect(ch.values.fold(0.0, (a, b) => a + b), closeTo(1.0, 1e-9));
    expect(ch[Rarity.common]!, greaterThan(ch[Rarity.rare]!));
    expect(ch[Rarity.rare]!, greaterThan(ch[Rarity.epic]!));
  });

  test('roll respects weights over many draws', () {
    final rng = Random(1);
    final counts = <Rarity, int>{};
    for (var i = 0; i < 4000; i++) {
      final k = CaseBox.roll(rng);
      counts[k.rarity] = (counts[k.rarity] ?? 0) + 1;
    }
    final expected = CaseBox.chances();
    for (final r in counts.keys) {
      expect(counts[r]! / 4000, closeTo(expected[r]!, 0.05));
    }
  });

  test('reel puts the winner at the requested index', () {
    final winner = SlipperCatalog.all.last;
    final reel = CaseBox.reel(Random(7), winner, 48, 42);
    expect(reel.length, 48);
    expect(reel[42].id, winner.id);
  });

  test('common sells at a loss, epic at a profit', () {
    expect(CaseBox.sellPrice(Rarity.common), lessThan(CaseBox.price));
    expect(CaseBox.sellPrice(Rarity.epic), greaterThan(CaseBox.price));
  });
}
