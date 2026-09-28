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

/// Поле «Под диваном»: 6×8 клеток, каждый день новое. Раскладка зависит
/// только от даты — весь день одна и та же и не меняется от перезапуска.
class DigBoard {
  DigBoard._(this.cells);

  static const cols = 6;
  static const rows = 8;
  static const size = cols * rows;

  /// Взмахов тапком в день.
  static const swingsPerDay = 20;

  final List<DigCell> cells;

  factory DigBoard.forDay(DateTime now) {
    final day = DateTime.utc(now.year, now.month, now.day).millisecondsSinceEpoch ~/
        Duration.millisecondsPerDay;
    return DigBoard.seeded(day * 7919 + 13);
  }

  factory DigBoard.seeded(int seed) {
    final rng = Random(seed);
    DigCell cell(DigLoot loot, {Rarity? gem, int? layers}) =>
        DigCell(loot: loot, gemRarity: gem, layers: layers ?? (rng.nextDouble() < 0.3 ? 2 : 1));
    final cells = <DigCell>[
      // Клад: эпический гем под тремя слоями.
      cell(DigLoot.treasure, gem: Rarity.epic, layers: 3),
      for (var i = 0; i < 3; i++) cell(DigLoot.guard, gem: Rarity.rare, layers: 2),
      for (var i = 0; i < 2; i++) cell(DigLoot.gem, gem: Rarity.rare, layers: 2),
      for (var i = 0; i < 5; i++) cell(DigLoot.gem, gem: Rarity.common),
      for (var i = 0; i < 9; i++) cell(DigLoot.threads),
      for (var i = 0; i < 4; i++) cell(DigLoot.coins),
    ];
    while (cells.length < size) {
      cells.add(cell(DigLoot.empty));
    }
    cells.shuffle(rng);
    return DigBoard._(cells);
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
