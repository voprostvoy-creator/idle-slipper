import 'dart:math';

import 'slipper.dart';

/// Все числа экономики в одном месте, чтобы балансировать не бегая по коду.
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

  /// Пассивный доход в секунду: растёт от общего уровня тапка и рейтинга.
  static double incomePerSecond(Slipper s, int rating) {
    final fromLevels = 0.5 + s.totalLevel * 0.35;
    final fromRating = max(0, rating - 1000) * 0.01;
    return fromLevels + fromRating;
  }

  /// Награда за бой. Проигрыш тоже что-то даёт, чтобы не было обидно.
  static int battleReward({required bool won, required int opponentPower}) {
    final base = 20 + opponentPower * 0.6;
    return (won ? base : base * 0.25).round();
  }

  /// Максимум офлайн-накопления — 8 часов.
  static const Duration maxOffline = Duration(hours: 8);

  /// Тап по тапку даёт мгновенные монеты — привычная idle-механика.
  static int tapReward(Slipper s) => 1 + s.totalLevel ~/ 4;
}
