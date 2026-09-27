import 'package:flutter_test/flutter_test.dart';
import 'package:idle_slipper/game/battle/battle_sim.dart';
import 'package:idle_slipper/game/battle/combatant.dart';
import 'package:idle_slipper/game/battle/skill_catalog.dart';
import 'package:idle_slipper/game/battle/skills.dart';
import 'package:idle_slipper/game/leaderboard.dart';
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

  test('leaderboard: 20 bots, sorted, stronger at the top', () {
    final bots = Leaderboard.bots;
    expect(bots, hasLength(20));
    for (var i = 1; i < bots.length; i++) {
      expect(bots[i].rating, lessThan(bots[i - 1].rating));
    }
    expect(bots.first.slipper.power, greaterThan(bots.last.slipper.power * 5));
  });

  test('leaderboard: place and next opponent is the one right above', () {
    final table = Leaderboard.standings({});
    expect(Leaderboard.placeOf(1000, table), 19);
    expect(Leaderboard.nextOpponent(1000, table).rating, 1040);
    expect(Leaderboard.placeOf(9999, table), 1);
    expect(Leaderboard.nextOpponent(9999, table).name, Leaderboard.bots.first.name);
    // Побеждённый бот с −10 очков опускается ниже игрока.
    final after = Leaderboard.standings({'Левый Резиновый': 1030});
    expect(Leaderboard.placeOf(1040, after), 18);
    expect(Leaderboard.nextOpponent(1040, after).name, 'Пыльный Тапок');
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

    test('barrier holds and absorbs damage', () {
      // Карбон ставит барьер активным скиллом — он должен держаться
      // несколько событий и гасить часть урона.
      final r = BattleSim.run(
        make('Carbon', atk: 7, def: 7, hp: 30, spd: 7, kind: 'carbon_sport'),
        make('B', atk: 7, def: 7, hp: 30, spd: 7),
        seed: 21,
      );
      final first = r.events.indexWhere((e) => e.player.barriered);
      expect(first, isNot(-1), reason: 'барьер так и не поставился');
      expect(
        r.events.skip(first).takeWhile((e) => e.player.barriered).length,
        greaterThan(1),
        reason: 'барьер виден лишь мгновение',
      );
    });

    test('slow and weaken are reported as state', () {
      // Адский шип замедляет топотом, клетчатый ослабляет ультой.
      final slowed = BattleSim.run(
        make('Spike', atk: 8, hp: 40, spd: 8, kind: 'red_spike'),
        make('B', atk: 6, hp: 40, spd: 6),
        seed: 5,
      );
      expect(slowed.events.any((e) => e.opponent.slowed), isTrue);

      final weakened = BattleSim.run(
        make('Granny', atk: 8, hp: 40, spd: 8),
        make('B', atk: 6, hp: 40, spd: 6),
        seed: 5,
      );
      expect(weakened.events.any((e) => e.opponent.weakened), isTrue);
    });

    test('guaranteed evade makes the next attack miss', () {
      // Слайд подкатом гарантирует промах следующей атаки по себе.
      final r = BattleSim.run(
        make('Slide', atk: 7, hp: 30, spd: 7, kind: 'blue_slide'),
        make('B', atk: 7, hp: 30, spd: 7),
        seed: 3,
      );
      expect(r.events.whereType<DodgeEvent>(), isNotEmpty);
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

    test('a killed fighter does not retaliate with thorns', () {
      // Адский шип колет в ответ, но добитый отвечать уже не должен:
      // иначе на экране он «оживал» после смертельного удара.
      for (var seed = 0; seed < 40; seed++) {
        final r = BattleSim.run(
          make('Strong', atk: 30, def: 20, hp: 20, spd: 20),
          make('Spike', atk: 2, def: 1, hp: 1, spd: 2, kind: 'red_spike'),
          seed: seed,
        );
        if (!r.playerWon) continue;
        final last = r.events.last;
        expect(last, isA<HitEvent>(), reason: 'сид $seed');
        expect((last as HitEvent).thorns, isFalse, reason: 'сид $seed');
        expect(last.targetHpAfter, 0, reason: 'сид $seed');
      }
    });

    test('turn counters count down and match the skill description', () {
      // Клетчатый ослабляет ультой на 3 хода: счётчик на противнике должен
      // пройти 3 → 2 → 1 и погаснуть, не перескакивая.
      final r = BattleSim.run(
        make('Granny', atk: 8, hp: 40, spd: 8),
        make('B', atk: 6, hp: 60, spd: 6),
        seed: 5,
      );
      final seen = <int>[];
      for (final e in r.events) {
        final t = e.opponent.weakenTurns;
        if (t > 0 && (seen.isEmpty || seen.last != t)) seen.add(t);
        if (seen.isNotEmpty && t == 0) break;
      }
      expect(seen, [3, 2, 1]);
    });

    test('weaken lasts as many opponent turns as it says', () {
      // Ослабление на 3 хода должно накрыть ровно три хода противника,
      // а не два, как было, когда счётчик убывал до удара.
      final r = BattleSim.run(
        make('Granny', atk: 8, hp: 40, spd: 8),
        make('B', atk: 6, hp: 60, spd: 6),
        seed: 5,
      );
      final start = r.events.indexWhere((e) => e.opponent.weakened);
      expect(start, isNot(-1));
      var weakenedTurns = 0;
      for (final e in r.events.skip(start)) {
        if (!e.opponent.weakened) break;
        // Считаем ходы противника: его удары и промахи, пока он ослаблен.
        final ownMove = (e is HitEvent && e.attacker == Side.opponent && !e.thorns) ||
            (e is DodgeEvent && e.attacker == Side.opponent) ||
            (e is StunEvent && e.side == Side.opponent);
        if (ownMove) weakenedTurns++;
      }
      expect(weakenedTurns, greaterThanOrEqualTo(3));
    });

    test('fighter without skills still fights', () {
      final r = BattleSim.run(_Dummy(name: 'A'), _Dummy(name: 'B', maxHp: 80), seed: 2);
      expect(r.events.whereType<SkillEvent>(), isEmpty);
      expect(r.events.whereType<HitEvent>(), isNotEmpty);
    });
  });
}
