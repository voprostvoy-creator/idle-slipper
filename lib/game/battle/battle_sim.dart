import 'dart:math';

import '../slipper.dart';

/// Кто действует: 0 — игрок, 1 — соперник.
enum Side { player, opponent }

extension SideX on Side {
  Side get other => this == Side.player ? Side.opponent : Side.player;
}

/// Одно событие боя. UI проигрывает их последовательно.
sealed class BattleEvent {
  const BattleEvent();
}

class HitEvent extends BattleEvent {
  const HitEvent({
    required this.attacker,
    required this.damage,
    required this.crit,
    required this.targetHpAfter,
  });
  final Side attacker;
  final int damage;
  final bool crit;
  final double targetHpAfter;
}

class DodgeEvent extends BattleEvent {
  const DodgeEvent({required this.attacker});
  final Side attacker;
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

/// Чистая функция боя: (тапок, тапок, seed) → результат.
/// Никаких зависимостей от Flutter, чтобы можно было гонять на сервере.
class BattleSim {
  BattleSim._();

  static const int _maxActions = 300;
  static const double _gaugeThreshold = 100;

  static BattleResult run(Slipper player, Slipper opponent, {required int seed}) {
    final rng = Random(seed);
    final hp = [player.maxHp, opponent.maxHp];
    final fighters = [player, opponent];
    final gauge = [0.0, 0.0];
    final events = <BattleEvent>[];

    // Шкала действий: чем выше скорость, тем чаще заполняется.
    for (var actions = 0; actions < _maxActions; actions++) {
      // Продвигаем время до момента, когда кто-то готов действовать.
      while (gauge[0] < _gaugeThreshold && gauge[1] < _gaugeThreshold) {
        gauge[0] += fighters[0].speed;
        gauge[1] += fighters[1].speed;
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

      final attacker = fighters[who];
      final defender = fighters[1 - who];
      final side = Side.values[who];

      if (rng.nextDouble() < defender.dodgeChance) {
        events.add(DodgeEvent(attacker: side));
        continue;
      }

      final crit = rng.nextDouble() < attacker.critChance;
      final variance = 0.85 + rng.nextDouble() * 0.3;
      final mitigation = 100 / (100 + defender.defense);
      var dmg = attacker.attack * variance * mitigation;
      if (crit) dmg *= 1.75;
      final damage = max(1, dmg.round());

      hp[1 - who] = max(0.0, hp[1 - who] - damage);
      events.add(HitEvent(
        attacker: side,
        damage: damage,
        crit: crit,
        targetHpAfter: hp[1 - who],
      ));

      if (hp[1 - who] <= 0) {
        return BattleResult(
          seed: seed,
          winner: side,
          events: events,
          playerMaxHp: player.maxHp,
          opponentMaxHp: opponent.maxHp,
        );
      }
    }

    // Лимит ходов: побеждает тот, у кого больше процент здоровья.
    final winner = hp[0] / player.maxHp >= hp[1] / opponent.maxHp
        ? Side.player
        : Side.opponent;
    return BattleResult(
      seed: seed,
      winner: winner,
      events: events,
      playerMaxHp: player.maxHp,
      opponentMaxHp: opponent.maxHp,
    );
  }
}
