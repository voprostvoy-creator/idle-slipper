import 'slipper_kind.dart';

/// Звёзды тапка: дубликаты из кейсов + монеты повышают звезду вида.
/// Звёзды принадлежат виду в коллекции, а не экземпляру.
class Stars {
  Stars._();

  static const max = 5;

  /// Каждая звезда: +8% к удару, прочности и здоровью.
  static const perStar = 0.08;

  static double multiplier(int stars) => 1 + perStar * stars;

  /// Сколько копий сверх одной нужно для звезды [star] (1..5).
  static int copiesFor(int star) => const [1, 2, 4, 8, 16][star - 1];

  /// Монеты за звезду [star]: растут со звездой и редкостью.
  static int coinsFor(int star, Rarity rarity) {
    const base = [50, 150, 400, 1000, 2500];
    const byRarity = [1.0, 1.5, 2.0, 3.0, 4.0];
    return (base[star - 1] * byRarity[rarity.index]).round();
  }
}
