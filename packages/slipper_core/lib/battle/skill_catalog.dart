import 'skills.dart';

/// Скиллы по видам тапков; открываются звёздами (★1, ★3, ★5).
///
/// У каждого свой почерк, и чем выше редкость, тем больше эффектов
/// в одном скилле: обычный лечится, редкий уворачивается и отвечает,
/// эпические танкуют и контролят, легендарный жжёт и травит,
/// мифические сочетают всё сразу.
class SkillCatalog {
  SkillCatalog._();

  static const _fallback = SkillSet(
    active: ActiveSkill(
      name: 'Сильный шлепок',
      description: 'Атака с уроном ×1.5.',
      damageMul: 1.5,
    ),
    activeCooldown: 4,
    passive: PassiveSkill(
      name: 'Стойкость',
      description: '+10 к защите.',
      defenseBonus: 10,
    ),
    ultimate: ActiveSkill(
      name: 'Размах',
      description: 'Атака с уроном ×2.5.',
      damageMul: 2.5,
    ),
  );

  static const _byKind = <String, SkillSet>{
    // Обычный — «домашний лекарь»: простые эффекты, держится лечением.
    'basic': SkillSet(
      active: ActiveSkill(
        name: 'Шлепок с оттяжкой',
        description: 'Атака с уроном ×1.6 и лечение на 8% здоровья.',
        damageMul: 1.6,
        healPercent: 0.08,
      ),
      activeCooldown: 4,
      passive: PassiveSkill(
        name: 'Бабушкина забота',
        description: '+3% здоровья каждый ход.',
        regenPercent: 0.03,
      ),
      ultimate: ActiveSkill(
        name: 'Бабушкин гнев',
        description: 'Атака с уроном ×2.2, противник пропускает ход.',
        damageMul: 2.2,
        stun: true,
      ),
    ),
    // Редкий — «скользкий»: замедляет, уворачивается и отвечает.
    'blue_slide': SkillSet(
      active: ActiveSkill(
        name: 'Подкат',
        description: 'Атака с уроном ×1.3 и −30% скорости противника (2 хода).',
        damageMul: 1.3,
        slow: 0.3,
        slowTurns: 2,
      ),
      activeCooldown: 3,
      passive: PassiveSkill(
        name: 'Скользкая подошва',
        description: '+10% к шансу уворота, после уворота 50% шанс ударить в ответ.',
        dodgeBonus: 0.1,
        dodgeCounterChance: 0.5,
      ),
      ultimate: ActiveSkill(
        name: 'Волна',
        description: 'Три атаки по ×1.0 и +40% скорости (3 хода).',
        damageMul: 1,
        hits: 3,
        haste: 0.4,
        hasteTurns: 3,
      ),
    ),
    // Эпический — «танк»: барьер, шипы, контратаки, мощный пробивной удар.
    'carbon_sport': SkillSet(
      active: ActiveSkill(
        name: 'Прыжковый удар',
        description: 'Атака с уроном ×1.5 и барьер на 20% здоровья.',
        damageMul: 1.5,
        barrierPercent: 0.2,
      ),
      activeCooldown: 4,
      passive: PassiveSkill(
        name: 'Карбоновая подошва',
        description: '+15 к защите, 10% урона возвращается атакующему, 15% шанс контратаки.',
        defenseBonus: 15,
        thorns: 0.1,
        counterChance: 0.15,
      ),
      ultimate: ActiveSkill(
        name: 'Метеорит',
        description: 'Атака с уроном ×2.6, игнорирует половину защиты, противник '
            'пропускает ход, с него снимаются щит, барьер и усиления.',
        damageMul: 2.6,
        pierce: 0.5,
        stun: true,
        dispel: true,
      ),
    ),
    // Эпический — «электрик»: немота, уязвимость от критов, кража ульты.
    'purple_neon': SkillSet(
      active: ActiveSkill(
        name: 'Разряд',
        description: 'Атака с уроном ×1.7, противник 2 хода не может применять скиллы.',
        damageMul: 1.7,
        silenceTurns: 2,
      ),
      activeCooldown: 4,
      passive: PassiveSkill(
        name: 'Перегрузка',
        description: '+15% к шансу крита, криты сильнее на 30% и делают противника '
            'уязвимым: +25% урона (2 хода).',
        critBonus: 0.15,
        critDamageBonus: 0.3,
        critVulnerable: 0.25,
      ),
      ultimate: ActiveSkill(
        name: 'Неоновая буря',
        description: 'Четыре атаки по ×1.1, −25% урона противника (3 хода), '
            'отнимает у него 30% шкалы ульты.',
        damageMul: 1.1,
        hits: 4,
        weaken: 0.25,
        weakenTurns: 3,
        ultSteal: 0.3,
      ),
    ),
    // Легендарный — «огонь и шипы»: яд, ярость, огненный разлом.
    'red_spike': SkillSet(
      active: ActiveSkill(
        name: 'Шипастый топот',
        description: 'Атака с уроном ×1.7 и 3 стопки яда (каждая — 2% здоровья за ход).',
        damageMul: 1.7,
        poisonStacks: 3,
      ),
      activeCooldown: 3,
      passive: PassiveSkill(
        name: 'Раскалённые шипы',
        description: '25% урона возвращается атакующему, каждый свой удар +6% урона (до 5 раз).',
        thorns: 0.25,
        rageStep: 0.06,
      ),
      ultimate: ActiveSkill(
        name: 'Адский разлом',
        description: 'Атака с уроном ×3, всегда крит, поджог на 3 хода, '
            'снимает с противника щит, барьер и усиления.',
        damageMul: 3,
        alwaysCrit: true,
        burnPercent: 0.3,
        burnTurns: 3,
        dispel: true,
      ),
    ),
    // Мифический — «хаос»: урон, уязвимость, вампиризм, контратаки.
    'rainbow': SkillSet(
      active: ActiveSkill(
        name: 'Призма',
        description: 'Атака с уроном ×1.8, игнорирует 40% защиты, противник уязвим: '
            '+25% урона (2 хода).',
        damageMul: 1.8,
        pierce: 0.4,
        vulnerable: 0.25,
        vulnerableTurns: 2,
      ),
      activeCooldown: 3,
      passive: PassiveSkill(
        name: 'Хаос',
        description: '+15% урона, +10% к шансу крита, 10% урона возвращается здоровьем, '
            '30% шанс контратаки.',
        damageBonus: 0.15,
        critBonus: 0.1,
        lifesteal: 0.1,
        counterChance: 0.3,
      ),
      ultimate: ActiveSkill(
        name: 'Спектральный залп',
        description: 'Пять атак по ×1.3, 25% урона возвращается здоровьем, '
            'снимает с себя вредные эффекты и даёт ещё один ход.',
        damageMul: 1.3,
        hits: 5,
        lifesteal: 0.25,
        cleanse: true,
        extraTurn: true,
      ),
    ),
    // Мифический — «равновесие»: очищение, второе дыхание, тёмная форма.
    'yin_yang': SkillSet(
      active: ActiveSkill(
        name: 'Равновесие',
        description: 'Атака с уроном ×1.5, лечение на 10% здоровья, снимает с себя '
            'вредные эффекты, −20% урона противника (2 хода).',
        damageMul: 1.5,
        healPercent: 0.1,
        cleanse: true,
        weaken: 0.2,
        weakenTurns: 2,
      ),
      activeCooldown: 3,
      passive: PassiveSkill(
        name: 'Гармония',
        description: 'Ульта копится на 60% быстрее. Второе дыхание: раз за бой '
            'не погибает и остаётся с 20% здоровья.',
        ultCharge: 0.6,
        revivePercent: 0.2,
      ),
      ultimate: ActiveSkill(
        name: 'Великий предел',
        description: 'Тёмная форма на 4 хода: +25% урона, −20% входящего урона, '
            '+20% скорости. Снимает с противника усиления, следующий удар '
            'по себе возвращает обратно.',
        damageMul: 1.2,
        formTurns: 4,
        formDamage: 0.25,
        formGuard: 0.2,
        formSpeed: 0.2,
        dispel: true,
        reflect: true,
      ),
    ),
  };

  static SkillSet forKind(String kindId) => _byKind[kindId] ?? _fallback;
}
