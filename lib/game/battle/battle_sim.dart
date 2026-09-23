import 'dart:math';

import 'combatant.dart';
import 'skills.dart';

/// Кто действует: 0 — игрок, 1 — соперник.
enum Side { player, opponent }

extension SideX on Side {
  Side get other => this == Side.player ? Side.opponent : Side.player;
}

/// Одно событие боя. UI проигрывает их последовательно.
///
/// Каждое событие несёт заряд ульт обеих сторон (0..1), чтобы экран мог
/// рисовать шкалы, не зная правил их накопления.
sealed class BattleEvent {
  const BattleEvent({required this.ultPlayer, required this.ultOpponent});

  final double ultPlayer;
  final double ultOpponent;
}

/// Объявление скилла перед его эффектом.
class SkillEvent extends BattleEvent {
  const SkillEvent({
    required this.side,
    required this.name,
    required this.ultimate,
    required super.ultPlayer,
    required super.ultOpponent,
  });

  final Side side;
  final String name;

  /// true — ульта, false — обычный скилл по откату.
  final bool ultimate;
}

class HitEvent extends BattleEvent {
  const HitEvent({
    required this.attacker,
    required this.damage,
    required this.crit,
    required this.targetHpAfter,
    required super.ultPlayer,
    required super.ultOpponent,
  });

  final Side attacker;
  final int damage;
  final bool crit;
  final double targetHpAfter;
}

class DodgeEvent extends BattleEvent {
  const DodgeEvent({
    required this.attacker,
    required super.ultPlayer,
    required super.ultOpponent,
  });

  final Side attacker;
}

/// Лечение: вампиризм, реген или скилл.
class HealEvent extends BattleEvent {
  const HealEvent({
    required this.side,
    required this.amount,
    required this.hpAfter,
    required super.ultPlayer,
    required super.ultOpponent,
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
    required super.ultPlayer,
    required super.ultOpponent,
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
    required super.ultPlayer,
    required super.ultOpponent,
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

  /// Поджог: сколько своих ходов гореть и по сколько урона за ход.
  int burnTurns = 0;
  double burnDamage = 0;

  /// Пропустить следующий ход.
  bool stunned = false;

  SkillSet get skills => who.skills;
  PassiveSkill get passive => who.skills.passive;

  bool get lowHp => hp < who.maxHp / 2;
}

/// Чистая функция боя: (боец, боец, seed) → результат.
/// Никаких зависимостей от Flutter, чтобы можно было гонять на сервере.
class BattleSim {
  BattleSim._();

  static const int _maxActions = 400;
  static const double _gaugeThreshold = 100;

  /// Сколько ульты копится за свой ход и за каждый процент урона.
  static const double _ultPerTurn = 0.08;
  static const double _ultPerDamageDealt = 0.35;
  static const double _ultPerDamageTaken = 0.25;

  static BattleResult run(Combatant player, Combatant opponent, {required int seed}) {
    final rng = Random(seed);
    final fighters = [_State(player), _State(opponent)];
    final gauge = [0.0, 0.0];
    final events = <BattleEvent>[];

    void add(BattleEvent Function(double ultP, double ultO) make) {
      events.add(make(fighters[0].ult, fighters[1].ult));
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
        gauge[0] += fighters[0].who.speed;
        gauge[1] += fighters[1].who.speed;
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
        add((p, o) => BurnEvent(side: side, damage: dmg, hpAfter: me.hp, ultPlayer: p, ultOpponent: o));
        if (me.hp <= 0) return finish(side.other);
      }

      // --- Оглушение ---
      if (me.stunned) {
        me.stunned = false;
        add((p, o) => StunEvent(side: side, ultPlayer: p, ultOpponent: o));
        continue;
      }

      // --- Реген из пассивки ---
      if (me.passive.regenPercent > 0 && me.hp < me.who.maxHp) {
        final heal = me.who.maxHp * me.passive.regenPercent;
        final before = me.hp;
        me.hp = min(me.who.maxHp, me.hp + heal);
        final gained = (me.hp - before).round();
        if (gained > 0) {
          add((p, o) => HealEvent(side: side, amount: gained, hpAfter: me.hp, ultPlayer: p, ultOpponent: o));
        }
      }

      // Щит живёт своими ходами владельца.
      if (me.shieldTurns > 0) {
        me.shieldTurns--;
        if (me.shieldTurns == 0) me.shield = 0;
      }

      // --- Выбор действия: ульта → скилл по откату → обычный удар ---
      ActiveSkill? skill;
      var isUltimate = false;
      if (!me.skills.isEmpty && me.ult >= 1) {
        skill = me.skills.ultimate;
        isUltimate = true;
        me.ult = 0;
      } else if (!me.skills.isEmpty && me.cooldown <= 0) {
        skill = me.skills.active;
        me.cooldown = me.skills.activeCooldown;
      } else if (me.cooldown > 0) {
        me.cooldown--;
      }

      if (skill != null) {
        add((p, o) => SkillEvent(
              side: side,
              name: skill!.name,
              ultimate: isUltimate,
              ultPlayer: p,
              ultOpponent: o,
            ));
        // Щит и лечение от скилла применяются до ударов.
        if (skill.shield > 0) {
          me.shield = skill.shield;
          me.shieldTurns = skill.shieldTurns;
        }
        if (skill.healPercent > 0) {
          final before = me.hp;
          me.hp = min(me.who.maxHp, me.hp + me.who.maxHp * skill.healPercent);
          final gained = (me.hp - before).round();
          if (gained > 0) {
            add((p, o) => HealEvent(side: side, amount: gained, hpAfter: me.hp, ultPlayer: p, ultOpponent: o));
          }
        }
      }

      final hits = skill?.hits ?? 1;
      final damageMul = skill?.damageMul ?? 1;
      var dealtTotal = 0.0;

      for (var h = 0; h < hits; h++) {
        final dodge = (foe.who.dodgeChance + foe.passive.dodgeBonus).clamp(0.0, 0.85);
        if (rng.nextDouble() < dodge) {
          add((p, o) => DodgeEvent(attacker: side, ultPlayer: p, ultOpponent: o));
          continue;
        }

        final critChance = (me.who.critChance + me.passive.critBonus).clamp(0.0, 0.95);
        final crit = rng.nextDouble() < critChance;
        final variance = 0.85 + rng.nextDouble() * 0.3;
        final defense = foe.who.defense + foe.passive.defenseBonus;
        final mitigation = 100 / (100 + defense) * (1 - foe.shield);

        var raw = me.who.attack * (1 + me.passive.damageBonus);
        if (me.lowHp) raw *= 1 + me.passive.lowHpDamageBonus;
        var dmg = raw * variance * mitigation * damageMul;
        if (crit) dmg *= 1.75;
        final damage = max(1, dmg.round());

        foe.hp = max(0.0, foe.hp - damage);
        dealtTotal += damage;

        // Заряд ульты: бьющему за нанесённый урон, цели — за полученный.
        me.ult = min(1, me.ult + _ultPerDamageDealt * damage / max(1, foe.who.maxHp));
        foe.ult = min(1, foe.ult + _ultPerDamageTaken * damage / max(1, foe.who.maxHp));

        add((p, o) => HitEvent(
              attacker: side,
              damage: damage,
              crit: crit,
              targetHpAfter: foe.hp,
              ultPlayer: p,
              ultOpponent: o,
            ));

        // Шипы: часть урона возвращается атакующему.
        if (foe.passive.thorns > 0 && me.hp > 0) {
          final back = max(1, (damage * foe.passive.thorns).round());
          me.hp = max(0.0, me.hp - back);
          add((p, o) => HitEvent(
                attacker: side.other,
                damage: back,
                crit: false,
                targetHpAfter: me.hp,
                ultPlayer: p,
                ultOpponent: o,
              ));
          if (me.hp <= 0) return finish(side.other);
        }

        if (foe.hp <= 0) return finish(side);
      }

      // --- После ударов: вампиризм и поджог ---
      if (dealtTotal > 0) {
        final steal = me.passive.lifesteal + (skill?.lifesteal ?? 0);
        if (steal > 0 && me.hp < me.who.maxHp) {
          final before = me.hp;
          me.hp = min(me.who.maxHp, me.hp + dealtTotal * steal);
          final gained = (me.hp - before).round();
          if (gained > 0) {
            add((p, o) => HealEvent(side: side, amount: gained, hpAfter: me.hp, ultPlayer: p, ultOpponent: o));
          }
        }
        if (skill != null && skill.burnTurns > 0) {
          foe.burnTurns = skill.burnTurns;
          foe.burnDamage = dealtTotal * skill.burnPercent;
        }
      }

      if (skill != null && skill.stun) foe.stunned = true;

      // Ход прошёл — немного ульты за сам факт действия.
      me.ult = min(1, me.ult + _ultPerTurn);
    }

    // Лимит ходов: побеждает тот, у кого больше процент здоровья.
    final winner = fighters[0].hp / player.maxHp >= fighters[1].hp / opponent.maxHp
        ? Side.player
        : Side.opponent;
    return finish(winner);
  }
}
