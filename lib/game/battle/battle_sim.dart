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
    this.burning = false,
    this.shielded = false,
    this.stunned = false,
  });

  /// Заряд ульты: 1 — сработает на ближайшем ходу.
  final double ult;

  /// Готовность активного скилла: 0 — только что применён, 1 — готов.
  final double skillReady;

  /// Длящиеся эффекты: горит, под щитом, пропустит ход. UI держит их
  /// столько, сколько они держатся в бою, а не по своему таймеру.
  final bool burning;
  final bool shielded;
  final bool stunned;
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
  });

  final Side attacker;
  final int damage;
  final bool crit;
  final double targetHpAfter;
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
          skillReady: st.skills.isEmpty
              ? 0
              : ((st.skills.activeCooldown - st.cooldown) / st.skills.activeCooldown)
                  .clamp(0.0, 1.0),
          burning: st.burnTurns > 0,
          shielded: st.shieldTurns > 0,
          stunned: st.stunned,
        );

    void add(BattleEvent Function(SideSnapshot p, SideSnapshot o) make) {
      events.add(make(snap(fighters[0]), snap(fighters[1])));
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
        add((p, o) => BurnEvent(side: side, damage: dmg, hpAfter: me.hp, player: p, opponent: o));
        if (me.hp <= 0) return finish(side.other);
      }

      // --- Оглушение ---
      if (me.stunned) {
        // Снимок берём до сброса, иначе звёзды оглушения не попадут в событие.
        add((p, o) => StunEvent(side: side, player: p, opponent: o));
        me.stunned = false;
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
            add((p, o) => HealEvent(side: side, amount: gained, hpAfter: me.hp, player: p, opponent: o));
          }
        }
      }

      final hits = skill?.hits ?? 1;
      final damageMul = skill?.damageMul ?? 1;
      var dealtTotal = 0.0;

      for (var h = 0; h < hits; h++) {
        final dodge = (foe.who.dodgeChance + foe.passive.dodgeBonus).clamp(0.0, 0.85);
        if (rng.nextDouble() < dodge) {
          add((p, o) => DodgeEvent(attacker: side, player: p, opponent: o));
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
              player: p,
              opponent: o,
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
                player: p,
                opponent: o,
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
            add((p, o) => HealEvent(side: side, amount: gained, hpAfter: me.hp, player: p, opponent: o));
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
