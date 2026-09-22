import 'dart:math';

import 'slipper_kind.dart';

/// Кейс с тапками: цена в нитках, розыгрыш по весам редкости, цена продажи.
class CaseBox {
  CaseBox._();

  /// Цена одного открытия, в нитках.
  static const int price = 500;

  /// Сколько дают за продажу выпавшего тапка.
  static int sellPrice(Rarity rarity) => (price * rarity.sellFactor).round();

  /// Виды, доступные в кейсе. Стартовый тапок тоже участвует — он и есть
  /// «мусорный» дроп, который продают в минус.
  static List<SlipperKind> get pool => SlipperCatalog.all;

  /// Шанс конкретной редкости с учётом того, какие виды реально есть.
  static Map<Rarity, double> chances() {
    final byRarity = <Rarity, int>{};
    for (final k in pool) {
      byRarity[k.rarity] = (byRarity[k.rarity] ?? 0) + k.rarity.weight;
    }
    final total = byRarity.values.fold(0, (a, b) => a + b);
    return {
      for (final e in byRarity.entries) e.key: total == 0 ? 0 : e.value / total,
    };
  }

  /// Розыгрыш. Вес вида = вес его редкости, поэтому редкие виды редки даже
  /// когда их в каталоге несколько.
  static SlipperKind roll(Random rng) {
    final total = pool.fold(0, (a, k) => a + k.rarity.weight);
    var pick = rng.nextInt(total);
    for (final k in pool) {
      pick -= k.rarity.weight;
      if (pick < 0) return k;
    }
    return pool.last;
  }

  /// Лента для анимации прокрутки: случайные виды, на [winnerIndex] — выпавший.
  static List<SlipperKind> reel(Random rng, SlipperKind winner, int length, int winnerIndex) {
    return [
      for (var i = 0; i < length; i++) i == winnerIndex ? winner : roll(rng),
    ];
  }
}
