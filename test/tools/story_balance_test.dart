// Таблица баланса сюжета: с какой прокачки тапок выигрывает бой главы.
// flutter test test/tools/story_balance_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_slipper/game/battle/battle_sim.dart';
import 'package:idle_slipper/game/slipper.dart';
import 'package:idle_slipper/game/story/chapters.dart';

void main() {
  test('баланс главы', () {
    for (final kindId in ['basic', 'blue_slide', 'red_spike']) {
      // ignore: avoid_print
      print('--- $kindId');
      for (final (i, stage) in StoryCatalog.chapters.last.stages.indexed) {
        final enemy = stage.enemy;
        String row = '';
        int? first;
        for (var lv = 18; lv <= 48; lv += 2) {
          final me = Slipper(
            name: 'я',
            kindId: kindId,
            levels: {for (final s in Stat.values) s: lv},
          );
          var wins = 0;
          for (var seed = 0; seed < 60; seed++) {
            if (BattleSim.run(me, enemy, seed: seed).playerWon) wins++;
          }
          final rate = wins / 60;
          if (first == null && rate >= 0.6) first = lv;
          row += '${(rate * 100).round()}'.padLeft(4);
        }
        final head = ' ${enemy.name.padRight(18)} сила ${enemy.power}'.padRight(28);
        // ignore: avoid_print
        print('${'${i + 1}'.padLeft(2)}$head 60%+ с ур.$first |$row');
      }
    }
  });
}
