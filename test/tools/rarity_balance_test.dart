// Таблица баланса редкостей: доля побед строки над столбцом при равной
// прокачке. flutter test test/tools/rarity_balance_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_slipper/game/battle/battle_sim.dart';
import 'package:idle_slipper/game/slipper.dart';
import 'package:idle_slipper/game/slipper_kind.dart';

const _kinds = ['basic', 'blue_slide', 'carbon_sport', 'purple_neon', 'red_spike', 'rainbow', 'yin_yang'];

Slipper _s(String kind, int lv, int stars) =>
    Slipper(name: kind, kindId: kind, stars: stars, levels: {for (final s in Stat.values) s: lv});

double _rate(Slipper a, Slipper b, {int n = 300}) {
  var w = 0;
  for (var seed = 0; seed < n; seed++) {
    if (BattleSim.run(a, b, seed: seed).playerWon) w++;
  }
  return w / n;
}

void main() {
  test('rarity matrix', () {
    for (final stars in [0, 5]) {
      // ignore: avoid_print
      print('--- уровень 15, звёзд $stars (строка против столбца, % побед)');
      // ignore: avoid_print
      print('${''.padRight(13)}${_kinds.map((k) => (k.length > 6 ? k.substring(0, 6) : k).padLeft(7)).join()}');
      for (final a in _kinds) {
        final row = [
          for (final b in _kinds) a == b ? '   -  ' : '${(_rate(_s(a, 15, stars), _s(b, 15, stars)) * 100).round()}'.padLeft(7),
        ];
        // ignore: avoid_print
        print('${a.padRight(13)}${row.join()}');
      }
    }
    // Сколько уровней стоит редкость: при каком уровне обычный тапок
    // выигрывает у тапка этой редкости 15-го уровня хотя бы половину боёв.
    for (final stars in [0, 5]) {
      for (final k in _kinds.skip(1)) {
        int? need;
        for (var lv = 15; lv <= 60; lv++) {
          if (_rate(_s('basic', lv, stars), _s(k, 15, stars), n: 120) >= 0.5) {
            need = lv;
            break;
          }
        }
        // ignore: avoid_print
        print('звёзд $stars: ${SlipperCatalog.byId(k).rarity.label} $k ≈ обычный ур.$need');
      }
    }
  });
}
