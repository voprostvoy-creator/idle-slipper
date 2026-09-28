import 'dart:math';

import 'slipper.dart';
import 'slipper_kind.dart';

/// Все числа экономики в одном месте, чтобы балансировать не бегая по коду.
///
/// Нитки приходят только из боёв (сюжет и арена) и сундука дежурства —
/// пассивного дохода нет, прокачка идёт за победы.
class Economy {
  Economy._();

  /// Стоимость следующего уровня стата: экспонента с мягким основанием.
  static int upgradeCost(Stat stat, int currentLevel) {
    final base = switch (stat) {
      Stat.attack => 12.0,
      Stat.defense => 10.0,
      Stat.health => 8.0,
      Stat.speed => 15.0,
    };
    return (base * pow(1.18, currentLevel - 1)).ceil();
  }

  /// Бонус вида «+% ниток за бои».
  static int withBonus(num threads, Slipper s) =>
      (threads * (1 + s.kind.bonus(Bonus.income))).round();

  /// Нитки за победу на арене над тем, кто выше: растут с силой соперника.
  static int arenaReward(Slipper s, {required int opponentPower}) =>
      withBonus(15 + opponentPower * 0.15, s);

  /// Сундук дежурства наполняется за это время.
  static const Duration chestFillTime = Duration(hours: 8);

  /// Сколько ниток в полном сундуке: растёт с силой тапка.
  static int chestCapacity(Slipper s) => withBonus(40 + s.power * 0.5, s);
}
