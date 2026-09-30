import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:idle_slipper/game/battle/battle_sim.dart';
import 'package:idle_slipper/game/slipper.dart';
import 'package:idle_slipper/game/slipper_kind.dart';
import 'package:idle_slipper/game/story/chapters.dart';

Slipper _even(int lv) =>
    Slipper(name: 'я', levels: {for (final s in Stat.values) s: lv});

double _winRate(Slipper me, Stage stage) {
  var wins = 0;
  for (var seed = 0; seed < 40; seed++) {
    if (BattleSim.run(me, stage.enemy, seed: seed).playerWon) wins++;
  }
  return wins / 40;
}

void main() {
  const chapter = StoryCatalog.chapter1;

  test('в главе 10 боёв, босс последний и даёт тапок', () {
    expect(chapter.stages, hasLength(10));
    expect(chapter.stages.last.boss, isTrue);
    expect(chapter.stages.where((s) => s.boss), hasLength(1));
    final reward = chapter.stages.last.rewardKindId;
    expect(reward, isNotNull);
    expect(SlipperCatalog.byId(reward!).id, reward);
  });

  test('картинки противников на месте', () {
    for (final c in StoryCatalog.chapters) {
      for (final stage in c.stages) {
        expect(File(stage.enemy.asset).existsSync(), isTrue, reason: stage.enemy.asset);
      }
    }
  });

  test('повтор даёт треть ниток', () {
    expect(chapter.stages.first.replayThreads, (chapter.stages.first.threads / 3).round());
  });

  test('первый бой проходится без прокачки, босс — нет', () {
    expect(_winRate(_even(1), chapter.stages.first), greaterThan(0.5));
    expect(_winRate(_even(1), chapter.stages.last), 0);
  });

  test('прокачанный тапок проходит всю главу', () {
    for (final stage in chapter.stages) {
      expect(_winRate(_even(12), stage), greaterThan(0.9), reason: stage.enemy.name);
    }
  });

  test('глава 2: 10 боёв, босс даёт тапок, продолжает первую по сложности', () {
    const c2 = StoryCatalog.chapter2;
    expect(c2.stages, hasLength(10));
    expect(c2.stages.last.boss, isTrue);
    expect(c2.stages.last.rewardKindId, isNotNull);
    // Первый бой главы 2 не проще босса главы 1.
    expect(_winRate(_even(9), c2.stages.first), lessThan(0.5));
    expect(_winRate(_even(30), c2.stages.last), greaterThan(0.9));
  });

  test('глава 3: 10 боёв, босс даёт тапок, продолжает вторую по сложности', () {
    const c3 = StoryCatalog.chapter3;
    expect(c3.stages, hasLength(10));
    expect(c3.stages.last.rewardKindId, isNotNull);
    expect(_winRate(_even(17), c3.stages.first), lessThan(0.5));
    expect(_winRate(_even(50), c3.stages.last), greaterThan(0.9));
  });
}
