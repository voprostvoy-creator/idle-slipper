import 'dart:io';

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:idle_slipper/game/case_box.dart';
import 'package:idle_slipper/game/slipper_kind.dart';

void main() {
  test('chances sum to 1 and follow rarity order', () {
    for (final type in CaseCatalog.all) {
      final ch = type.chances();
      expect(ch.values.fold(0.0, (a, b) => a + b), closeTo(1.0, 1e-9),
          reason: type.id);
      expect(ch[Rarity.common]!, greaterThan(ch[Rarity.epic]!), reason: type.id);
    }
  });

  test('ad case is more generous than the standard one', () {
    final std = CaseCatalog.standard.chances();
    final ad = CaseCatalog.ad.chances();
    expect(ad[Rarity.rare]!, greaterThan(std[Rarity.rare]!));
    expect(ad[Rarity.epic]!, greaterThan(std[Rarity.epic]!));
    // Легендарный есть только в рекламном кейсе.
    expect(std[Rarity.legendary], isNull);
    expect(ad[Rarity.legendary], greaterThan(0));
  });

  test('mythic drops only from the ad case, at 1%', () {
    expect(CaseCatalog.standard.chances()[Rarity.mythic], isNull);
    expect(CaseCatalog.dailyCase.chances()[Rarity.mythic], isNull);
    expect(CaseCatalog.ad.chances()[Rarity.mythic], closeTo(0.01, 1e-9));
  });

  test('roll respects weights over many draws', () {
    for (final type in CaseCatalog.all) {
      final rng = Random(1);
      final counts = <Rarity, int>{};
      for (var i = 0; i < 4000; i++) {
        final k = type.roll(rng);
        counts[k.rarity] = (counts[k.rarity] ?? 0) + 1;
      }
      final expected = type.chances();
      for (final r in counts.keys) {
        expect(counts[r]! / 4000, closeTo(expected[r]!, 0.05), reason: '${type.id} $r');
      }
    }
  });

  test('reel puts the winner at the requested index', () {
    final winner = SlipperCatalog.all.last;
    final reel = CaseCatalog.standard.reel(Random(7), winner, 48, 42);
    expect(reel.length, 48);
    expect(reel[42].id, winner.id);
  });

  test('sell price grows with rarity and common sells at a loss', () {
    expect(Rarity.common.sellPrice, lessThan(CaseCatalog.standard.price));
    expect(Rarity.epic.sellPrice, greaterThan(CaseCatalog.standard.price));
    for (var i = 1; i < Rarity.values.length; i++) {
      expect(Rarity.values[i].sellPrice,
          greaterThan(Rarity.values[i - 1].sellPrice));
    }
  });

  test('every catalog entry has a normalized asset path', () {
    for (final k in SlipperCatalog.all) {
      // Старые тапки в PNG, новые — в WebP (легче в 6-7 раз).
      expect(
        k.asset,
        anyOf('assets/slippers/${k.id}.png', 'assets/slippers/${k.id}.webp'),
      );
      expect(File(k.asset).existsSync(), isTrue, reason: k.asset);
    }
  });

  test('coin shop: 3 different non-common slippers per day, stable within a day', () {
    final a = CoinShop.forDay(20000);
    expect(a, hasLength(3));
    expect(a.map((k) => k.id).toSet(), hasLength(3));
    expect(a.every((k) => k.rarity != Rarity.common), isTrue);
    expect(CoinShop.forDay(20000).map((k) => k.id), a.map((k) => k.id));
  });
}
