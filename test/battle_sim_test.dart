import 'package:flutter_test/flutter_test.dart';
import 'package:idle_slipper/game/battle/battle_sim.dart';
import 'package:idle_slipper/game/battle/combatant.dart';
import 'package:idle_slipper/game/battle/skill_catalog.dart';
import 'package:idle_slipper/game/battle/skills.dart';
import 'package:idle_slipper/game/leaderboard.dart';
import 'package:idle_slipper/game/slipper.dart';
import 'package:idle_slipper/game/slipper_kind.dart';

/// Боец без скиллов — чтобы проверять чистую механику ударов.
/// С [skills] — чтобы проверить отдельный эффект.
class _Dummy implements Combatant {
  _Dummy({required this.name, this.maxHp = 100, this.skills = SkillSet.none, this.speed = 10});

  @override
  final String name;
  @override
  final double maxHp;

  @override
  double get attack => 20;
  @override
  double get defense => 0;
  @override
  final double speed;
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
  final SkillSet skills;
}

/// Набор с одним активным скиллом каждый ход и пассивкой.
SkillSet _set({ActiveSkill? active, PassiveSkill? passive}) => SkillSet(
      active: active ?? SkillSet.none.active,
      activeCooldown: 1,
      passive: passive ?? SkillSet.none.passive,
      ultimate: SkillSet.none.ultimate,
    );

void main() {
  Slipper make(String name,
          {int atk = 1,
          int def = 1,
          int hp = 1,
          int spd = 1,
          String kind = 'basic',
          // Все скиллы открыты — тесты проверяют их механику.
          int stars = 5}) =>
      Slipper(name: name, kindId: kind, stars: stars, levels: {
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

  test('dark form: ultimate transforms for 4 turns, counting down', () {
    final yy = Slipper(
        name: 'yy', kindId: 'yin_yang', stars: 5, levels: {for (final s in Stat.values) s: 15});
    final foe = Slipper(name: 'o', kindId: 'carbon_sport', levels: {for (final s in Stat.values) s: 15});
    for (var seed = 0; seed < 50; seed++) {
      final r = BattleSim.run(yy, foe, seed: seed);
      final seq = <int>[];
      for (final e in r.events) {
        final f = e.player.formTurns;
        if (f > 0 && (seq.isEmpty || seq.last != f)) seq.add(f);
      }
      if (seq.length >= 3) {
        expect(seq.take(3), [4, 3, 2]);
        return;
      }
    }
    fail('тёмная форма не продержалась 3 хода ни в одном бою');
  });

  test('skills unlock with stars: ★1 active, ★3 passive, ★5 ultimate', () {
    SkillSet at(int stars) => make('a', stars: stars).skills;
    expect(at(0).isEmpty, isTrue);
    expect([at(1).hasActive, at(1).hasPassive, at(1).hasUltimate], [true, false, false]);
    expect([at(2).hasActive, at(2).hasPassive, at(2).hasUltimate], [true, false, false]);
    expect([at(3).hasActive, at(3).hasPassive, at(3).hasUltimate], [true, true, false]);
    expect([at(4).hasActive, at(4).hasPassive, at(4).hasUltimate], [true, true, false]);
    expect([at(5).hasActive, at(5).hasPassive, at(5).hasUltimate], [true, true, true]);
  });

  test('locked skills never fire in battle', () {
    final a = make('A', atk: 10, def: 10, hp: 10, spd: 10, stars: 0);
    final b = make('B', atk: 10, def: 10, hp: 10, spd: 10, stars: 0);
    for (var seed = 0; seed < 20; seed++) {
      expect(BattleSim.run(a, b, seed: seed).events.whereType<SkillEvent>(), isEmpty);
    }
  });

  group('new effects', () {
    test('poison ticks by stacks and fades', () {
      final r = BattleSim.run(
        _Dummy(name: 'A', skills: _set(active: const ActiveSkill(name: 'Яд', description: '', poisonStacks: 3))),
        _Dummy(name: 'B', maxHp: 1000),
        seed: 1,
      );
      final ticks = r.events.whereType<BurnEvent>().where((e) => e.poison).toList();
      expect(ticks, isNotEmpty);
      expect(r.events.any((e) => e.opponent.poisonStacks > 0), isTrue);
    });

    test('silence blocks the victim skills', () {
      final r = BattleSim.run(
        _Dummy(name: 'A', speed: 30, skills: _set(active: const ActiveSkill(name: 'Немота', description: '', silenceTurns: 3))),
        _Dummy(name: 'B', skills: _set(active: const ActiveSkill(name: 'Удар', description: '', damageMul: 2))),
        seed: 1,
      );
      // B медленнее: A успевает наложить немоту раньше первого хода B.
      final firstOpponentSkill = r.events.indexWhere((e) => e is SkillEvent && e.side == Side.opponent);
      final firstSilence = r.events.indexWhere((e) => e.opponent.silenced);
      expect(firstSilence, isNot(-1));
      expect(firstOpponentSkill == -1 || firstOpponentSkill > firstSilence + 1, isTrue);
    });

    test('second wind saves once', () {
      final r = BattleSim.run(
        _Dummy(name: 'A', maxHp: 1000),
        _Dummy(name: 'B', maxHp: 60, skills: _set(passive: const PassiveSkill(name: 'Второе дыхание', description: '', revivePercent: 0.5))),
        seed: 1,
      );
      final revived = r.events.whereType<HealEvent>().where((e) => e.side == Side.opponent);
      expect(revived, hasLength(1));
      expect(revived.first.hpAfter, closeTo(30, 0.001));
    });

    test('reflect returns the next hit to the attacker', () {
      final r = BattleSim.run(
        _Dummy(name: 'A', maxHp: 1000),
        _Dummy(name: 'B', maxHp: 1000, speed: 30, skills: _set(active: const ActiveSkill(name: 'Зеркало', description: '', reflect: true))),
        seed: 1,
      );
      expect(r.events.any((e) => e is HitEvent && e.attacker == Side.opponent && e.thorns), isTrue);
    });

    test('counter hits back sometimes', () {
      final r = BattleSim.run(
        _Dummy(name: 'A', maxHp: 1000),
        _Dummy(name: 'B', maxHp: 1000, skills: _set(passive: const PassiveSkill(name: 'Ответ', description: '', counterChance: 1))),
        seed: 1,
      );
      // При шансе 100% за каждым ударом A сразу идёт удар B.
      final hits = r.events.whereType<HitEvent>().toList();
      final i = hits.indexWhere((e) => e.attacker == Side.player);
      expect(hits[i + 1].attacker, Side.opponent);
    });

    test('dispel strips the barrier', () {
      final r = BattleSim.run(
        _Dummy(name: 'A', maxHp: 1000, speed: 10, skills: _set(active: const ActiveSkill(name: 'Развеять', description: '', dispel: true))),
        _Dummy(name: 'B', maxHp: 1000, speed: 20, skills: _set(active: const ActiveSkill(name: 'Барьер', description: '', barrierPercent: 0.9))),
        seed: 1,
      );
      // Событие скилла пишется до эффекта — смотрим на следующее, удар.
      final i = r.events.indexWhere((e) => e is SkillEvent && e.side == Side.player);
      expect(r.events[i].opponent.barriered, isTrue);
      expect(r.events[i + 1].opponent.barriered, isFalse);
    });
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
      // Адский шип поджигает ультой: горение должно держаться подряд,
      // а не гаснуть в ходы противника.
      final r = BattleSim.run(
        make('Spike', atk: 8, hp: 30, spd: 9, kind: 'red_spike'),
        make('B', atk: 6, hp: 200, def: 20, spd: 6),
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
      // Синий слайд замедляет подкатом, Неон ослабляет ультой.
      final slowed = BattleSim.run(
        make('Slide', atk: 8, hp: 40, spd: 8, kind: 'blue_slide'),
        make('B', atk: 6, hp: 200, def: 20, spd: 6),
        seed: 5,
      );
      expect(slowed.events.any((e) => e.opponent.slowed), isTrue);

      final weakened = BattleSim.run(
        make('Neon', atk: 8, hp: 40, spd: 8, kind: 'purple_neon'),
        make('B', atk: 6, hp: 200, def: 20, spd: 6),
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
      // Неон ослабляет ультой на 3 хода: счётчик на противнике должен
      // пройти 3 → 2 → 1 и погаснуть, не перескакивая.
      final r = BattleSim.run(
        make('Neon', atk: 8, hp: 40, spd: 8, kind: 'purple_neon'),
        make('B', atk: 6, hp: 200, def: 20, spd: 6),
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
        make('Neon', atk: 8, hp: 40, spd: 8, kind: 'purple_neon'),
        make('B', atk: 6, hp: 200, def: 20, spd: 6),
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
