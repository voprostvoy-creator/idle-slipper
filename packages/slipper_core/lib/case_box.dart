import 'dart:math';

import 'slipper_kind.dart';

/// Вид кейса: цена, набор редкостей и их веса при розыгрыше.
class CaseType {
  const CaseType({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.weights,
    this.daily = false,
  });

  final String id;
  final String name;
  final String description;

  /// Цена в нитках. 0 — бесплатный (за рекламу).
  final int price;

  /// Веса по редкости. Редкости, которых тут нет, не выпадают.
  final Map<Rarity, int> weights;

  /// Бесплатный раз в день; обновляется в полночь.
  final bool daily;

  bool get isFree => price == 0;

  /// Шансы по редкостям — веса, нормализованные с учётом того,
  /// какие виды реально есть в каталоге.
  Map<Rarity, double> chances() {
    final live = <Rarity, int>{
      for (final e in weights.entries)
        if (SlipperCatalog.byRarity(e.key).isNotEmpty) e.key: e.value,
    };
    final total = live.values.fold(0, (a, b) => a + b);
    if (total == 0) return const {};
    return {for (final e in live.entries) e.key: e.value / total};
  }

  /// Розыгрыш: сначала редкость по весам, потом равновероятный вид внутри неё.
  SlipperKind roll(Random rng) {
    final live = <Rarity, int>{
      for (final e in weights.entries)
        if (SlipperCatalog.byRarity(e.key).isNotEmpty) e.key: e.value,
    };
    final total = live.values.fold(0, (a, b) => a + b);
    var pick = rng.nextInt(total);
    for (final e in live.entries) {
      pick -= e.value;
      if (pick < 0) {
        final pool = SlipperCatalog.byRarity(e.key);
        return pool[rng.nextInt(pool.length)];
      }
    }
    return SlipperCatalog.byId(SlipperCatalog.defaultId);
  }

  /// Лента для анимации прокрутки: случайные виды, на [winnerIndex] — выпавший.
  List<SlipperKind> reel(Random rng, SlipperKind winner, int length, int winnerIndex) {
    return [
      for (var i = 0; i < length; i++) i == winnerIndex ? winner : roll(rng),
    ];
  }
}

/// Все кейсы игры.
class CaseCatalog {
  CaseCatalog._();

  /// Ежедневный: бесплатно раз в день, шансы как у обычного.
  static const dailyCase = CaseType(
    id: 'daily',
    name: 'Ежедневный кейс',
    description: 'Бесплатно раз в день. Шансы как у обычного кейса.',
    price: 0,
    weights: {
      Rarity.common: 59,
      Rarity.rare: 30,
      Rarity.epic: 8,
      Rarity.legendary: 2,
      Rarity.mythic: 1,
    },
    daily: true,
  );

  /// Обычный кейс: в основном мусор, эпик — редкая удача.
  static const standard = CaseType(
    id: 'standard',
    name: 'Кейс с тапками',
    description: 'Внутри случайный тапок. Выпавшее можно оставить или продать.',
    price: 500,
    weights: {
      Rarity.common: 59,
      Rarity.rare: 30,
      Rarity.epic: 8,
      Rarity.legendary: 2,
      Rarity.mythic: 1,
    },
  );

  /// Кейс за рекламу: шансы на редкое заметно выше, и есть легендарный.
  static const ad = CaseType(
    id: 'ad',
    name: 'Кейс за рекламу',
    description: 'Шансы на редкое выше, может выпасть даже мифический тапок.',
    price: 0,
    weights: {
      Rarity.common: 28,
      Rarity.rare: 38,
      Rarity.epic: 25,
      Rarity.legendary: 7,
      Rarity.mythic: 2,
    },
  );

  static const all = [dailyCase, standard, ad];

  static CaseType byId(String id) =>
      all.firstWhere((c) => c.id == id, orElse: () => standard);
}

/// Лавка за монеты: три случайных тапка (кроме обычных), набор меняется
/// каждый день. Каждый можно купить один раз за день.
class CoinShop {
  CoinShop._();

  static const offers = 3;

  static int priceOf(Rarity r) => switch (r) {
        Rarity.common => 100,
        Rarity.rare => 200,
        Rarity.epic => 500,
        Rarity.legendary => 1500,
        Rarity.mythic => 4000,
      };

  /// Предложения на день [day] (номер дня): разные виды, без обычных.
  static List<SlipperKind> forDay(int day) {
    final pool = [for (final k in SlipperCatalog.all) if (k.rarity != Rarity.common) k]
      ..shuffle(Random(day * 31 + 5));
    return pool.take(offers).toList();
  }
}
