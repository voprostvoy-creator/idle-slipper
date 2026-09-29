import 'dart:math';

import 'slipper_kind.dart';

/// Что лежит под клеткой «Под диваном».
enum DigLoot { empty, threads, coins, gem, guard, treasure }

class DigCell {
  const DigCell({required this.loot, required this.layers, this.gemRarity});

  final DigLoot loot;

  /// Сколько слоёв пыли над находкой.
  final int layers;

  /// Редкость гема: у самого гема, у клада и у награды стража.
  final Rarity? gemRarity;

  /// Даёт гем — такие клетки считаются в подсказке-«блеске».
  bool get shines => gemRarity != null;
}

/// Поле «Под диваном»: 6×6 клеток, каждый день новое. Под каждой клеткой
/// что-то лежит — случайно. Раскладка зависит только от даты: весь день
/// одна и та же и не меняется от перезапуска. Клетка — один взмах.
class DigBoard {
  DigBoard._(this.cells);

  static const cols = 6;
  static const rows = 6;
  static const size = cols * rows;

  /// Взмахов тапком в день без заданий; ещё столько же дают задания дня.
  static const swingsPerDay = 10;

  /// Сколько находок каждого вида на сотню клеток — веса случайного выбора.
  static const _weights = [
    (DigLoot.threads, null, 38),
    (DigLoot.coins, Rarity.common, 24),
    (DigLoot.gem, Rarity.common, 20),
    (DigLoot.gem, Rarity.rare, 7),
    (DigLoot.guard, Rarity.rare, 8),
    (DigLoot.treasure, Rarity.epic, 3),
  ];

  final List<DigCell> cells;

  factory DigBoard.forDay(DateTime now) {
    final day = DateTime.utc(now.year, now.month, now.day).millisecondsSinceEpoch ~/
        Duration.millisecondsPerDay;
    return DigBoard.seeded(day * 7919 + 13);
  }

  factory DigBoard.seeded(int seed) {
    final rng = Random(seed);
    final total = _weights.fold(0, (a, w) => a + w.$3);
    DigCell pick() {
      var roll = rng.nextInt(total);
      for (final (loot, rarity, weight) in _weights) {
        roll -= weight;
        if (roll < 0) {
          // У монет редкость не нужна — это не гем.
          final gem = loot == DigLoot.coins || loot == DigLoot.threads ? null : rarity;
          return DigCell(loot: loot, layers: 1, gemRarity: gem);
        }
      }
      return const DigCell(loot: DigLoot.threads, layers: 1);
    }

    return DigBoard._([for (var i = 0; i < size; i++) pick()]);
  }

  /// Подсказка на расчищенной клетке: сколько соседних клеток «блестят»,
  /// то есть прячут гем (сам гем, клад или страж с гемом).
  int hintAt(int index) {
    final r = index ~/ cols;
    final c = index % cols;
    var n = 0;
    for (var dr = -1; dr <= 1; dr++) {
      for (var dc = -1; dc <= 1; dc++) {
        if (dr == 0 && dc == 0) continue;
        final rr = r + dr;
        final cc = c + dc;
        if (rr < 0 || rr >= rows || cc < 0 || cc >= cols) continue;
        if (cells[rr * cols + cc].shines) n++;
      }
    }
    return n;
  }
}
