// Баланс «Обороны кухни»: простой бот строит тапки у тропы и улучшает их.
// flutter test test/tools/defense_balance_test.dart
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:idle_slipper/game/defense.dart';

/// Клетки рядом с тропой, сначала самые «выгодные» — у изгибов.
List<Cell> _spots() {
  final out = <(Cell, int)>[];
  for (var r = 0; r < DefenseMap.rows; r++) {
    for (var c = 0; c < DefenseMap.cols; c++) {
      final cell = (col: c, row: r);
      if (DefenseMap.path.contains(cell)) continue;
      var near = 0;
      for (final p in DefenseMap.path) {
        if ((p.col - c).abs() <= 1 && (p.row - r).abs() <= 1) near++;
      }
      if (near > 0) out.add((cell, near));
    }
  }
  out.sort((a, b) => b.$2.compareTo(a.$2));
  return [for (final e in out) e.$1];
}

int _play(List<String> kinds, int stars, int seed) {
  final g = DefenseGame(random: Random(seed));
  final spots = _spots();
  var k = 0;
  while (!g.over) {
    // Строим/улучшаем на все крошки.
    var spent = true;
    while (spent) {
      spent = false;
      final free = spots.where(g.canPlace).toList();
      final kind = kinds[k % kinds.length];
      if (free.isNotEmpty && g.towers.length < 8 && g.place(kind, free.first, stars: stars)) {
        k++;
        spent = true;
        continue;
      }
      final up = g.towers.where((t) => t.level < Tower.maxLevel).toList()
        ..sort((a, b) => a.upgradePrice.compareTo(b.upgradePrice));
      if (up.isNotEmpty && g.upgrade(up.first)) spent = true;
    }
    g.startWave();
    var t = 0.0;
    while (g.waveActive && t < 600) {
      g.step(1 / 30);
      t += 1 / 30;
    }
  }
  return g.cleared;
}

void main() {
  test('defense balance', () {
    final sets = {
      'только клетчатый': ['basic'],
      'клетчатый+слайд': ['basic', 'blue_slide'],
      'эпики': ['carbon_sport', 'purple_neon', 'blue_slide'],
      'легенда+эпики': ['red_spike', 'carbon_sport', 'purple_neon'],
      'мифики': ['rainbow', 'yin_yang', 'red_spike'],
    };
    for (final e in sets.entries) {
      for (final stars in [0, 3]) {
        final r = [for (var s = 0; s < 5; s++) _play(e.value, stars, s)];
        // ignore: avoid_print
        print('${e.key.padRight(18)} ★$stars → волн: $r');
      }
    }
  });
}
