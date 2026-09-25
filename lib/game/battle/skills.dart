/// Скиллы бойцов. Все срабатывают сами: активный — по откату, ульта —
/// по накопленной шкале, пассивный работает постоянно.
///
/// Ручного нажатия нет намеренно: бой считается целиком заранее
/// (`BattleSim`), а соперник — снимок чужого тапка, за которым никто не сидит.
library;

/// Разовый эффект — активный скилл или ульта.
class ActiveSkill {
  const ActiveSkill({
    required this.name,
    required this.description,
    this.damageMul = 1,
    this.hits = 1,
    this.stun = false,
    this.healPercent = 0,
    this.shield = 0,
    this.shieldTurns = 0,
    this.burnPercent = 0,
    this.burnTurns = 0,
    this.lifesteal = 0,
    this.pierce = 0,
    this.weaken = 0,
    this.weakenTurns = 0,
    this.slow = 0,
    this.slowTurns = 0,
    this.haste = 0,
    this.hasteTurns = 0,
    this.barrierPercent = 0,
    this.evadeTurns = 0,
    this.extraTurn = false,
    this.alwaysCrit = false,
  });

  final String name;
  final String description;

  /// Во сколько раз сильнее обычного удара.
  final double damageMul;

  /// Сколько ударов наносится подряд.
  final int hits;

  /// Противник пропускает следующий ход.
  final bool stun;

  /// Лечение, доля от максимума HP.
  final double healPercent;

  /// Снижение входящего урона и на сколько своих ходов оно держится.
  final double shield;
  final int shieldTurns;

  /// Поджог: доля нанесённого урона, которая капает противнику каждый его ход.
  final double burnPercent;
  final int burnTurns;

  /// Доля нанесённого урона, возвращаемая себе как лечение.
  final double lifesteal;

  /// Какую часть защиты цели удар игнорирует.
  final double pierce;

  /// Ослабление: насколько слабее бьёт противник и сколько его ходов это длится.
  final double weaken;
  final int weakenTurns;

  /// Замедление противника: доля его скорости и длительность в его ходах.
  final double slow;
  final int slowTurns;

  /// Ускорение себя: доля скорости и длительность в своих ходах.
  final double haste;
  final int hasteTurns;

  /// Барьер, поглощающий урон: доля от своего максимума HP.
  final double barrierPercent;

  /// Сколько следующих атак по бойцу гарантированно пройдут мимо.
  final int evadeTurns;

  /// Боец ходит ещё раз сразу после этого хода.
  final bool extraTurn;

  /// Удары скилла всегда критуют.
  final bool alwaysCrit;
}

/// Постоянный эффект — работает весь бой без срабатываний.
class PassiveSkill {
  const PassiveSkill({
    required this.name,
    required this.description,
    this.damageBonus = 0,
    this.critBonus = 0,
    this.critDamageBonus = 0,
    this.dodgeBonus = 0,
    this.defenseBonus = 0,
    this.lifesteal = 0,
    this.thorns = 0,
    this.regenPercent = 0,
    this.lowHpDamageBonus = 0,
    this.executeThreshold = 0,
  });

  final String name;
  final String description;

  /// Прибавки к боевым величинам: доли (0.1 = +10%).
  final double damageBonus;
  final double critBonus;

  /// Насколько сильнее обычного бьёт крит.
  final double critDamageBonus;

  final double dodgeBonus;

  /// Прибавка к защите в её единицах (не доля).
  final double defenseBonus;

  /// Вампиризм с каждого удара.
  final double lifesteal;

  /// Доля полученного урона, возвращаемая атакующему.
  final double thorns;

  /// Восстановление HP каждый свой ход, доля от максимума.
  final double regenPercent;

  /// Дополнительный урон, когда своих HP меньше половины.
  final double lowHpDamageBonus;

  /// Добивание: если у цели осталось меньше этой доли HP, удар удваивается.
  final double executeThreshold;
}

/// Набор из трёх скиллов бойца.
class SkillSet {
  const SkillSet({
    required this.active,
    required this.activeCooldown,
    required this.passive,
    required this.ultimate,
  });

  /// Пустой набор — для противников без скиллов.
  static const none = SkillSet(
    active: ActiveSkill(name: '', description: ''),
    activeCooldown: 9999,
    passive: PassiveSkill(name: '', description: ''),
    ultimate: ActiveSkill(name: '', description: ''),
  );

  final ActiveSkill active;

  /// Через сколько своих ходов активный скилл готов снова.
  final int activeCooldown;

  final PassiveSkill passive;

  /// Срабатывает, когда шкала ульты заполнится (см. `BattleSim`).
  final ActiveSkill ultimate;

  bool get isEmpty => active.name.isEmpty;
}
