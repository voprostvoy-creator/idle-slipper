import 'dart:math';

import 'combatant.dart';
import 'skills.dart';

/// Кто действует: 0 — игрок, 1 — соперник.
enum Side { player, opponent }

extension SideX on Side {
  Side get other => this == Side.player ? Side.opponent : Side.player;
}

/// Состояние скиллов стороны на момент события — всё в долях 0..1,
/// чтобы экран рисовал шкалы и откаты, не зная правил их накопления.
class SideSnapshot {
  const SideSnapshot({
    required this.ult,
    required this.skillReady,
    this.burnTurns = 0,
    this.shieldTurns = 0,
    this.weakenTurns = 0,
    this.slowTurns = 0,
    this.hasteTurns = 0,
    this.formTurns = 0,
    this.stunned = false,
    this.barriered = false,
    this.evading = false,
  });

  /// Заряд ульты: 1 — сработает на ближайшем ходу.
  final double ult;

  /// Готовность активного скилла: 0 — только что применён, 1 — готов.
  final double skillReady;

  /// Сколько ходов осталось длящимся эффектам. UI держит значок ровно
  /// столько, сколько эффект действует в бою, и показывает этот остаток.
  final int burnTurns;
  final int shieldTurns;
  final int weakenTurns;
  final int slowTurns;
  final int hasteTurns;

  /// Сколько ходов ещё длится преображение (тёмная форма).
  final int formTurns;

  /// Эффекты без счёта ходов: пропустит ближайший ход, барьер на запасе
  /// поглощения, уклонение на зарядах.
  final bool stunned;
  final bool barriered;
  final bool evading;

  bool get burning => burnTurns > 0;
  bool get shielded => shieldTurns > 0;
  bool get weakened => weakenTurns > 0;
  bool get slowed => slowTurns > 0;
  bool get hasted => hasteTurns > 0;
  bool get transformed => formTurns > 0;
}

/// Одно событие боя. UI проигрывает их последовательно.
sealed class BattleEvent {
  const BattleEvent({required this.player, required this.opponent});

  final SideSnapshot player;
  final SideSnapshot opponent;

  SideSnapshot of(Side side) => side == Side.player ? player : opponent;
}

/// Объявление скилла перед его эффектом.
class SkillEvent extends BattleEvent {
  const SkillEvent({
    required this.side,
    required this.skill,
    required this.ultimate,
    required super.player,
    required super.opponent,
  });

  final Side side;

  /// Сам скилл — из него UI берёт название и понимает, что показывать.
  final ActiveSkill skill;

  /// true — ульта, false — обычный скилл по откату.
  final bool ultimate;

  String get name => skill.name;
}

class HitEvent extends BattleEvent {
  const HitEvent({
    required this.attacker,
    required this.damage,
    required this.crit,
    required this.targetHpAfter,
    required super.player,
    required super.opponent,
    this.thorns = false,
  });

  final Side attacker;
  final int damage;
  final bool crit;
  final double targetHpAfter;

  /// Урон от шипов: не удар, а ответ брони, поэтому боец не делает выпад.
  final bool thorns;
}

class DodgeEvent extends BattleEvent {
  const DodgeEvent({
    required this.attacker,
    required super.player,
    required super.opponent,
  });

  final Side attacker;
}

/// Лечение: вампиризм, реген или скилл.
class HealEvent extends BattleEvent {
  const HealEvent({
    required this.side,
    required this.amount,
    required this.hpAfter,
    required super.player,
    required super.opponent,
  });

  final Side side;
  final int amount;
  final double hpAfter;
}

/// Урон от поджога в начале своего хода.
class BurnEvent extends BattleEvent {
  const BurnEvent({
    required this.side,
    required this.damage,
    required this.hpAfter,
    required super.player,
    required super.opponent,
  });

  /// Кто горит.
  final Side side;
  final int damage;
  final double hpAfter;
}

/// Пропуск хода из-за оглушения.
class StunEvent extends BattleEvent {
  const StunEvent({
    required this.side,
    required super.player,
    required super.opponent,
  });

  /// Кто пропускает ход.
  final Side side;
}

class BattleResult {
  const BattleResult({
    required this.seed,
    required this.winner,
    required this.events,
    required this.playerMaxHp,
    required this.opponentMaxHp,
  });

  final int seed;
  final Side winner;
  final List<BattleEvent> events;
  final double playerMaxHp;
  final double opponentMaxHp;

  bool get playerWon => winner == Side.player;
}

/// Состояние бойца на время боя: то, что меняется от хода к ходу.
class _State {
  _State(this.who);

  final Combatant who;
  late double hp = who.maxHp;

  /// Сколько своих ходов осталось до готовности активного скилла.
  int cooldown = 0;

  /// Заряд ульты, 0..1.
  double ult = 0;

  /// Сколько своих ходов ещё держится щит и насколько он режет урон.
  int shieldTurns = 0;
  double shield = 0;

  /// Барьер, поглощающий урон до того, как тот дойдёт до HP.
  double barrier = 0;

  /// Ослабление: насколько слабее бьёт и сколько своих ходов это длится.
  double weaken = 0;
  int weakenTurns = 0;

  /// Замедление и ускорение: доля скорости и сколько своих ходов действует.
  double slow = 0;
  int slowTurns = 0;
  double haste = 0;
  int hasteTurns = 0;

  /// Сколько ближайших атак по бойцу пройдут мимо.
  int evadeCharges = 0;

  /// Преображение: сколько своих ходов длится и что даёт.
  int formTurns = 0;
  double formDamage = 0;
  double formGuard = 0;
  double formSpeed = 0;

  /// Скорость с учётом замедления, ускорения и преображения.
  double get speedNow => (who.speed * (1 + haste + formSpeed - slow))
      .clamp(who.speed * 0.25, who.speed * 3);

  /// Поджог: сколько своих ходов гореть и по сколько урона за ход.
  int burnTurns = 0;
  double burnDamage = 0;

  /// Пропустить следующий ход.
  bool stunned = false;

  SkillSet get skills => who.skills;
  PassiveSkill get passive => who.skills.passive;

  bool get lowHp => hp < who.maxHp / 2;

  /// Множитель накопления ульты от пассивки.
  double get ultGain => 1 + passive.ultCharge;
}

/// Чистая функция боя: (боец, боец, seed) → результат.
/// Никаких зависимостей от Flutter, чтобы можно было гонять на сервере.
class BattleSim {
  BattleSim._();

  static const int _maxActions = 400;
  static const double _gaugeThreshold = 100;

  /// Сколько ульты копится за свой ход и за каждый процент урона.
  static const double _ultPerTurn = 0.1;
  static const double _ultPerDamageDealt = 0.4375;
  static const double _ultPerDamageTaken = 0.3125;

  static BattleResult run(Combatant player, Combatant opponent, {required int seed}) {
    final rng = Random(seed);
    final fighters = [_State(player), _State(opponent)];
    final gauge = [0.0, 0.0];
    final events = <BattleEvent>[];

    SideSnapshot snap(_State st) => SideSnapshot(
          ult: st.ult,
          skillReady: !st.skills.hasActive
              ? 0
              : ((st.skills.activeCooldown - st.cooldown) / st.skills.activeCooldown)
                  .clamp(0.0, 1.0),
          burnTurns: st.burnTurns,
          shieldTurns: st.shieldTurns,
          weakenTurns: st.weakenTurns,
          slowTurns: st.slowTurns,
          hasteTurns: st.hasteTurns,
          formTurns: st.formTurns,
          stunned: st.stunned,
          barriered: st.barrier > 0,
          evading: st.evadeCharges > 0,
        );

    void add(BattleEvent Function(SideSnapshot p, SideSnapshot o) make) {
      events.add(make(snap(fighters[0]), snap(fighters[1])));
    }

    /// Конец хода бойца: вредные эффекты на нём убывают только теперь,
    /// после того как он успел под ними подействовать.
    void endTurn(_State st) {
      if (st.weakenTurns > 0) {
        st.weakenTurns--;
        if (st.weakenTurns == 0) st.weaken = 0;
      }
      if (st.slowTurns > 0) {
        st.slowTurns--;
        if (st.slowTurns == 0) st.slow = 0;
      }
    }

    BattleResult finish(Side winner) => BattleResult(
          seed: seed,
          winner: winner,
          events: events,
          playerMaxHp: player.maxHp,
          opponentMaxHp: opponent.maxHp,
        );

    for (var actions = 0; actions < _maxActions; actions++) {
      // Продвигаем время до момента, когда кто-то готов действовать.
      while (gauge[0] < _gaugeThreshold && gauge[1] < _gaugeThreshold) {
        gauge[0] += fighters[0].speedNow;
        gauge[1] += fighters[1].speedNow;
      }

      // При одновременной готовности ход отдаётся тому, у кого шкала полнее;
      // при равенстве — случайно (детерминированно через rng).
      final int who;
      if (gauge[0] >= _gaugeThreshold && gauge[1] >= _gaugeThreshold) {
        who = gauge[0] == gauge[1] ? rng.nextInt(2) : (gauge[0] > gauge[1] ? 0 : 1);
      } else {
        who = gauge[0] >= _gaugeThreshold ? 0 : 1;
      }
      gauge[who] -= _gaugeThreshold;

      final me = fighters[who];
      final foe = fighters[1 - who];
      final side = Side.values[who];

      // --- Начало хода: поджог ---
      if (me.burnTurns > 0) {
        final dmg = max(1, me.burnDamage.round());
        me.hp = max(0.0, me.hp - dmg);
        me.burnTurns--;
        add((p, o) => BurnEvent(side: side, damage: dmg, hpAfter: me.hp, player: p, opponent: o));
        if (me.hp <= 0) return finish(side.other);
      }

      // --- Оглушение ---
      if (me.stunned) {
        // Снимок берём до сброса, иначе звёзды оглушения не попадут в событие.
        add((p, o) => StunEvent(side: side, player: p, opponent: o));
        me.stunned = false;
        // Пропущенный ход — всё равно ход: вредные эффекты на нём убывают.
        endTurn(me);
        continue;
      }

      // --- Реген из пассивки ---
      if (me.passive.regenPercent > 0 && me.hp < me.who.maxHp) {
        final heal = me.who.maxHp * me.passive.regenPercent;
        final before = me.hp;
        me.hp = min(me.who.maxHp, me.hp + heal);
        final gained = (me.hp - before).round();
        if (gained > 0) {
          add((p, o) => HealEvent(side: side, amount: gained, hpAfter: me.hp, player: p, opponent: o));
        }
      }

      // Щит и прочие длящиеся эффекты живут ходами своего владельца.
      if (me.shieldTurns > 0) {
        me.shieldTurns--;
        if (me.shieldTurns == 0) me.shield = 0;
      }
      if (me.hasteTurns > 0) {
        me.hasteTurns--;
        if (me.hasteTurns == 0) me.haste = 0;
      }
      if (me.formTurns > 0) {
        me.formTurns--;
        if (me.formTurns == 0) {
          me.formDamage = 0;
          me.formGuard = 0;
          me.formSpeed = 0;
        }
      }

      // --- Выбор действия: ульта → скилл по откату → обычный удар ---
      ActiveSkill? skill;
      var isUltimate = false;
      if (me.skills.hasUltimate && me.ult >= 1) {
        skill = me.skills.ultimate;
        isUltimate = true;
        me.ult = 0;
      } else if (me.skills.hasActive && me.cooldown <= 0) {
        skill = me.skills.active;
        me.cooldown = me.skills.activeCooldown;
      }
      // Откат активного идёт и в ходы, занятые ультой, — иначе частые ульты
      // морозили бы его навсегда.
      if (skill == null || isUltimate) {
        if (me.cooldown > 0) me.cooldown--;
      }

      if (skill != null) {
        add((p, o) => SkillEvent(
              side: side,
              skill: skill!,
              ultimate: isUltimate,
              player: p,
              opponent: o,
            ));
        // Всё, что действует на себя, применяется до ударов.
        if (skill.shield > 0) {
          me.shield = skill.shield;
          me.shieldTurns = skill.shieldTurns;
        }
        if (skill.barrierPercent > 0) {
          me.barrier = me.who.maxHp * skill.barrierPercent;
        }
        if (skill.hasteTurns > 0) {
          me.haste = skill.haste;
          me.hasteTurns = skill.hasteTurns;
        }
        if (skill.evadeTurns > 0) me.evadeCharges = skill.evadeTurns;
        if (skill.formTurns > 0) {
          me.formTurns = skill.formTurns;
          me.formDamage = skill.formDamage;
          me.formGuard = skill.formGuard;
          me.formSpeed = skill.formSpeed;
        }
        if (skill.healPercent > 0) {
          final before = me.hp;
          me.hp = min(me.who.maxHp, me.hp + me.who.maxHp * skill.healPercent);
          final gained = (me.hp - before).round();
          if (gained > 0) {
            add((p, o) => HealEvent(side: side, amount: gained, hpAfter: me.hp, player: p, opponent: o));
          }
        }
      }

      final hits = skill?.hits ?? 1;
      final damageMul = skill?.damageMul ?? 1;
      var dealtTotal = 0.0;

      for (var h = 0; h < hits; h++) {
        // Гарантированный промах от скилла уклонения тратится первым.
        if (foe.evadeCharges > 0) {
          foe.evadeCharges--;
          add((p, o) => DodgeEvent(attacker: side, player: p, opponent: o));
          continue;
        }

        final dodge = (foe.who.dodgeChance + foe.passive.dodgeBonus).clamp(0.0, 0.85);
        if (rng.nextDouble() < dodge) {
          add((p, o) => DodgeEvent(attacker: side, player: p, opponent: o));
          continue;
        }

        final critChance = (me.who.critChance + me.passive.critBonus).clamp(0.0, 0.95);
        final crit = (skill?.alwaysCrit ?? false) || rng.nextDouble() < critChance;
        final variance = 0.85 + rng.nextDouble() * 0.3;
        // Пробитие срезает часть защиты цели.
        final pierce = skill?.pierce ?? 0;
        final defense = (foe.who.defense + foe.passive.defenseBonus) * (1 - pierce);
        final mitigation =
            100 / (100 + defense) * (1 - foe.shield) * (1 - foe.formGuard);

        var raw = me.who.attack *
            (1 + me.passive.damageBonus + me.formDamage - me.weaken);
        if (me.lowHp) raw *= 1 + me.passive.lowHpDamageBonus;
        // Добивание: по еле живой цели удар проходит вдвое сильнее.
        if (me.passive.executeThreshold > 0 &&
            foe.hp / foe.who.maxHp <= me.passive.executeThreshold) {
          raw *= 2;
        }
        var dmg = raw * variance * mitigation * damageMul;
        if (crit) dmg *= 1.75 + me.passive.critDamageBonus;
        var damage = max(1, dmg.round());

        // Барьер съедает урон до того, как тот дойдёт до здоровья.
        if (foe.barrier > 0) {
          final absorbed = min(foe.barrier, damage.toDouble());
          foe.barrier -= absorbed;
          damage = max(0, damage - absorbed.round());
          if (damage == 0) {
            add((p, o) => HitEvent(
                  attacker: side,
                  damage: 0,
                  crit: false,
                  targetHpAfter: foe.hp,
                  player: p,
                  opponent: o,
                ));
            continue;
          }
        }

        foe.hp = max(0.0, foe.hp - damage);
        dealtTotal += damage;

        // Заряд ульты: бьющему за нанесённый урон, цели — за полученный.
        me.ult = min(1, me.ult + me.ultGain * _ultPerDamageDealt * damage / max(1, foe.who.maxHp));
        foe.ult = min(1, foe.ult + foe.ultGain * _ultPerDamageTaken * damage / max(1, foe.who.maxHp));

        add((p, o) => HitEvent(
              attacker: side,
              damage: damage,
              crit: crit,
              targetHpAfter: foe.hp,
              player: p,
              opponent: o,
            ));

        // Добитый противник шипами уже не отвечает — иначе он «оживал»
        // на экране после смертельного удара.
        if (foe.hp <= 0) return finish(side);

        // Шипы: часть урона возвращается атакующему.
        if (foe.passive.thorns > 0 && me.hp > 0) {
          final back = max(1, (damage * foe.passive.thorns).round());
          me.hp = max(0.0, me.hp - back);
          add((p, o) => HitEvent(
                attacker: side.other,
                damage: back,
                crit: false,
                targetHpAfter: me.hp,
                thorns: true,
                player: p,
                opponent: o,
              ));
          if (me.hp <= 0) return finish(side.other);
        }
      }

      // --- После ударов: вампиризм и поджог ---
      if (dealtTotal > 0) {
        final steal = me.passive.lifesteal + (skill?.lifesteal ?? 0);
        if (steal > 0 && me.hp < me.who.maxHp) {
          final before = me.hp;
          me.hp = min(me.who.maxHp, me.hp + dealtTotal * steal);
          final gained = (me.hp - before).round();
          if (gained > 0) {
            add((p, o) => HealEvent(side: side, amount: gained, hpAfter: me.hp, player: p, opponent: o));
          }
        }
        if (skill != null && skill.burnTurns > 0) {
          foe.burnTurns = skill.burnTurns;
          foe.burnDamage = dealtTotal * skill.burnPercent;
        }
      }

      if (skill != null) {
        if (skill.stun) foe.stunned = true;
        if (skill.weakenTurns > 0 && dealtTotal > 0) {
          foe.weaken = skill.weaken;
          foe.weakenTurns = skill.weakenTurns;
        }
        if (skill.slowTurns > 0 && dealtTotal > 0) {
          foe.slow = skill.slow;
          foe.slowTurns = skill.slowTurns;
        }
        // Дополнительный ход: шкала сразу заполняется заново.
        if (skill.extraTurn) gauge[who] += _gaugeThreshold;
      }

      // Ход прошёл — немного ульты за сам факт действия.
      me.ult = min(1, me.ult + me.ultGain * _ultPerTurn);
      endTurn(me);
    }

    // Лимит ходов: побеждает тот, у кого больше процент здоровья.
    final winner = fighters[0].hp / player.maxHp >= fighters[1].hp / opponent.maxHp
        ? Side.player
        : Side.opponent;
    return finish(winner);
  }
}
