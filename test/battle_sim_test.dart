import 'package:flutter_test/flutter_test.dart';
import 'package:idle_slipper/game/battle/battle_sim.dart';
import 'package:idle_slipper/game/opponents.dart';
import 'package:idle_slipper/game/slipper.dart';

void main() {
  Slipper make(String name, {int atk = 1, int def = 1, int hp = 1, int spd = 1}) =>
      Slipper(name: name, levels: {
        Stat.attack: atk,
        Stat.defense: def,
        Stat.health: hp,
        Stat.speed: spd,
      });

  test('same seed gives identical battle', () {
    final a = make('A', atk: 5, hp: 3);
    final b = make('B', def: 4, spd: 6);
    final r1 = BattleSim.run(a, b, seed: 42);
    final r2 = BattleSim.run(a, b, seed: 42);
    expect(r1.winner, r2.winner);
    expect(r1.events.length, r2.events.length);
  });

  test('battle always ends with a winner and consistent hp', () {
    final r = BattleSim.run(make('A'), make('B'), seed: 7);
    expect(r.events, isNotEmpty);
    final lastHit = r.events.whereType<HitEvent>().last;
    expect(lastHit.targetHpAfter, 0);
    expect(lastHit.attacker, r.winner);
  });

  test('much stronger slipper wins overwhelmingly', () {
    final strong = make('S', atk: 20, def: 20, hp: 20, spd: 20);
    final weak = make('W');
    var wins = 0;
    for (var seed = 0; seed < 100; seed++) {
      if (BattleSim.run(strong, weak, seed: seed).playerWon) wins++;
    }
    expect(wins, greaterThan(95));
  });

  test('mirror match is close to 50/50', () {
    final a = make('A', atk: 8, def: 8, hp: 8, spd: 8);
    final b = make('B', atk: 8, def: 8, hp: 8, spd: 8);
    var wins = 0;
    for (var seed = 0; seed < 400; seed++) {
      if (BattleSim.run(a, b, seed: seed).playerWon) wins++;
    }
    expect(wins, inInclusiveRange(150, 250));
  });

  test('opponent generator is deterministic and scales with player', () {
    final me = make('Me', atk: 10, def: 10, hp: 10, spd: 10);
    final o1 = OpponentGenerator.generate(player: me, rating: 1000, seed: 3);
    final o2 = OpponentGenerator.generate(player: me, rating: 1000, seed: 3);
    expect(o1.map((o) => o.slipper.name), o2.map((o) => o.slipper.name));
    expect(o1.length, 3);
    expect(o1[0].slipper.totalLevel, lessThan(o1[2].slipper.totalLevel));
  });
}
