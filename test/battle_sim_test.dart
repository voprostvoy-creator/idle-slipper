import 'package:flutter_test/flutter_test.dart';
import 'package:idle_slipper/game/battle/battle_sim.dart';
import 'package:idle_slipper/game/battle/combatant.dart';
import 'package:idle_slipper/game/battle/skill_catalog.dart';
import 'package:idle_slipper/game/battle/skills.dart';
import 'package:idle_slipper/game/opponents.dart';
import 'package:idle_slipper/game/slipper.dart';
import 'package:idle_slipper/game/slipper_kind.dart';

/// Боец без скиллов — чтобы проверять чистую механику ударов.
class _Dummy implements Combatant {
  _Dummy({required this.name, this.maxHp = 100});

  @override
  final String name;
  @override
  final double maxHp;

  @override
  double get attack => 20;
  @override
  double get defense => 0;
  @override
  double get speed => 10;
  @override
  double get dodgeChance => 0;
  @override
  double get critChance => 0;

  @override
  String get asset => 'assets/slippers/basic.png';
  @override
  AttackStyle get attackStyle => AttackStyle.lunge;
  @override
  double get sizeFactor => 1;
  @override
  AuraSpec? get aura => null;
  @override
  SkillSet get skills => SkillSet.none;
}

void main() {
  Slipper make(String name,
          {int atk = 1, int def = 1, int hp = 1, int spd = 1, String kind = 'basic'}) =>
      Slipper(name: name, kindId: kind, levels: {
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

  test('battle always ends with a winner and a lethal blow', () {
    final r = BattleSim.run(_Dummy(name: 'A'), _Dummy(name: 'B'), seed: 7);
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

  group('skills', () {
    test('every catalog slipper has three named skills', () {
      for (final k in SlipperCatalog.all) {
        final set = SkillCatalog.forKind(k.id);
        expect(set.isEmpty, isFalse, reason: k.id);
        expect(set.active.name, isNotEmpty, reason: k.id);
        expect(set.passive.name, isNotEmpty, reason: k.id);
        expect(set.ultimate.name, isNotEmpty, reason: k.id);
        expect(set.activeCooldown, greaterThan(0), reason: k.id);
      }
    });

    test('active skill and ultimate both fire during a fight', () {
      final a = make('A', atk: 6, def: 6, hp: 30, spd: 6);
      final b = make('B', atk: 6, def: 6, hp: 30, spd: 6, kind: 'blue_slide');
      final r = BattleSim.run(a, b, seed: 11);
      final skills = r.events.whereType<SkillEvent>();
      expect(skills.where((e) => !e.ultimate), isNotEmpty);
      expect(skills.where((e) => e.ultimate), isNotEmpty);
    });

    test('events carry ult charge and skill cooldown for both sides', () {
      final r = BattleSim.run(
        make('A', atk: 5, hp: 20),
        make('B', atk: 5, hp: 20),
        seed: 3,
      );
      for (final e in r.events) {
        for (final side in [e.player, e.opponent]) {
          expect(side.ult, inInclusiveRange(0, 1));
          expect(side.skillReady, inInclusiveRange(0, 1));
        }
      }
      // Ульта хоть раз доходит до полной шкалы.
      expect(r.events.any((e) => e.player.ult >= 1 || e.opponent.ult >= 1), isTrue);
      // И откат хоть раз уходит в ноль сразу после применения скилла.
      expect(r.events.any((e) => e.player.skillReady < 0.2), isTrue);
    });

    test('regen heals, thorns hurt the attacker, burn ticks', () {
      // Клетчатый лечится, адский шип колет шипами и поджигает ультой.
      final r = BattleSim.run(
        make('Heal', atk: 4, hp: 30, spd: 5),
        make('Spike', atk: 4, hp: 30, spd: 5, kind: 'red_spike'),
        seed: 5,
      );
      expect(r.events.whereType<HealEvent>(), isNotEmpty);
      expect(r.events.whereType<BurnEvent>(), isNotEmpty);
    });

    test('stun makes the victim skip a turn', () {
      final r = BattleSim.run(
        make('A', atk: 8, hp: 40, spd: 8),
        make('B', atk: 8, hp: 40, spd: 8, kind: 'carbon_sport'),
        seed: 9,
      );
      expect(r.events.whereType<StunEvent>(), isNotEmpty);
    });

    test('skills do not break determinism', () {
      for (final kind in SlipperCatalog.all) {
        final a = make('A', atk: 7, def: 5, hp: 12, spd: 7, kind: kind.id);
        final b = make('B', atk: 7, def: 5, hp: 12, spd: 7);
        final r1 = BattleSim.run(a, b, seed: 77);
        final r2 = BattleSim.run(a, b, seed: 77);
        expect(r1.winner, r2.winner, reason: kind.id);
        expect(r1.events.length, r2.events.length, reason: kind.id);
      }
    });

    test('lasting effects stay on across the opponent turns', () {
      // Неон поджигает ультой: горение должно держаться подряд,
      // а не гаснуть в ходы противника.
      final r = BattleSim.run(
        make('Neon', atk: 8, hp: 30, spd: 9, kind: 'purple_neon'),
        make('B', atk: 6, hp: 40, spd: 6),
        seed: 12,
      );
      final events = r.events;
      final first = events.indexWhere((e) => e.opponent.burning);
      expect(first, isNot(-1), reason: 'поджог так и не случился');
      // От начала горения и до его конца флаг не должен прерываться.
      final burning = events
          .skip(first)
          .takeWhile((e) => e.opponent.burning)
          .length;
      expect(burning, greaterThan(1), reason: 'горение видно лишь мгновение');
    });

    test('shield is reported as state while it holds', () {
      final r = BattleSim.run(
        make('A', atk: 7, hp: 30, spd: 7, kind: 'blue_slide'),
        make('B', atk: 7, hp: 30, spd: 7, kind: 'carbon_sport'),
        seed: 21,
      );
      final first = r.events.indexWhere((e) => e.player.shielded);
      expect(first, isNot(-1), reason: 'щит так и не поставился');
      expect(
        r.events.skip(first).takeWhile((e) => e.player.shielded).length,
        greaterThan(1),
        reason: 'щит виден лишь мгновение',
      );
    });

    test('stun is reported as state until the victim skips its turn', () {
      final r = BattleSim.run(
        make('A', atk: 8, hp: 40, spd: 8),
        make('B', atk: 8, hp: 40, spd: 8, kind: 'carbon_sport'),
        seed: 9,
      );
      final i = r.events.indexWhere((e) => e is StunEvent);
      expect(i, isNot(-1), reason: 'оглушения не случилось');
      final victim = (r.events[i] as StunEvent).side;
      // В момент пропуска хода флаг ещё горит — UI показывает звёзды.
      expect(r.events[i].of(victim).stunned, isTrue);
      // А дальше снят.
      expect(r.events[i + 1].of(victim).stunned, isFalse);
    });

    test('fighter without skills still fights', () {
      final r = BattleSim.run(_Dummy(name: 'A'), _Dummy(name: 'B', maxHp: 80), seed: 2);
      expect(r.events.whereType<SkillEvent>(), isEmpty);
      expect(r.events.whereType<HitEvent>(), isNotEmpty);
    });
  });
}
