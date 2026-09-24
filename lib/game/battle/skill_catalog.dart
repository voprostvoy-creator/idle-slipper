import 'skills.dart';

/// Скиллы по видам тапков. Пока открыты сразу; позже будут выдаваться
/// за улучшение тапка копиями.
class SkillCatalog {
  SkillCatalog._();

  static const _fallback = SkillSet(
    active: ActiveSkill(
      name: 'Сильный шлепок',
      description: 'Следующая атака с уроном ×1.5.',
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
    // Обычный тапок: живучий середняк, лечится сам.
    'basic': SkillSet(
      active: ActiveSkill(
        name: 'Шлепок с оттяжкой',
        description: 'Следующая атака с уроном ×1.8.',
        damageMul: 1.8,
      ),
      activeCooldown: 4,
      passive: PassiveSkill(
        name: 'Домашний уют',
        description: '+3% здоровья каждый ход.',
        regenPercent: 0.03,
      ),
      ultimate: ActiveSkill(
        name: 'Бабушкин гнев',
        description: 'Атака с уроном ×3, противник пропускает ход.',
        damageMul: 3,
        stun: true,
      ),
    ),

    // Слайд: скользкий и вёрткий, берёт уворотами и частыми ударами.
    'blue_slide': SkillSet(
      active: ActiveSkill(
        name: 'Подкат',
        description: 'Атака с уроном ×1.6, −25% входящего урона на 2 хода.',
        damageMul: 1.6,
        shield: 0.25,
        shieldTurns: 2,
      ),
      activeCooldown: 3,
      passive: PassiveSkill(
        name: 'Скользкая подошва',
        description: '+7% к шансу уворота.',
        dodgeBonus: 0.07,
      ),
      ultimate: ActiveSkill(
        name: 'Град шлепков',
        description: 'Три атаки подряд с уроном ×1.2.',
        damageMul: 1.2,
        hits: 3,
      ),
    ),

    // Карбон: танк, держит удар и бьёт сверху.
    'carbon_sport': SkillSet(
      active: ActiveSkill(
        name: 'Прыжковый удар',
        description: 'Следующая атака с уроном ×2.',
        damageMul: 2,
      ),
      activeCooldown: 4,
      passive: PassiveSkill(
        name: 'Карбоновая подошва',
        description: '+35 к защите.',
        defenseBonus: 35,
      ),
      ultimate: ActiveSkill(
        name: 'Метеоритный удар',
        description: 'Атака с уроном ×3.2, противник пропускает ход.',
        damageMul: 3.2,
        stun: true,
      ),
    ),

    // Неон: критует и вытягивает здоровье, поджигает ульту.
    'purple_neon': SkillSet(
      active: ActiveSkill(
        name: 'Фазовый рывок',
        description: 'Атака с уроном ×1.7, 50% урона возвращается здоровьем.',
        damageMul: 1.7,
        lifesteal: 0.5,
      ),
      activeCooldown: 3,
      passive: PassiveSkill(
        name: 'Неоновый заряд',
        description: '+10% к шансу крита.',
        critBonus: 0.1,
      ),
      ultimate: ActiveSkill(
        name: 'Перегрузка',
        description: 'Атака с уроном ×2.6, поджог на 3 хода.',
        damageMul: 2.6,
        burnPercent: 0.3,
        burnTurns: 3,
      ),
    ),

    // Адский шип: наказывает за удары по себе и давит уроном.
    'red_spike': SkillSet(
      active: ActiveSkill(
        name: 'Тяжёлый топот',
        description: 'Следующая атака с уроном ×2.1.',
        damageMul: 2.1,
      ),
      activeCooldown: 3,
      passive: PassiveSkill(
        name: 'Шипы',
        description: '20% полученного урона возвращается атакующему.',
        thorns: 0.2,
      ),
      ultimate: ActiveSkill(
        name: 'Адский разлом',
        description: 'Атака с уроном ×3.5, поджог на 2 хода.',
        damageMul: 3.5,
        burnPercent: 0.35,
        burnTurns: 2,
      ),
    ),

    // Радужный: всё сразу, но честно — лишь у мифического тапка.
    'rainbow': SkillSet(
      active: ActiveSkill(
        name: 'Призматический луч',
        description: 'Атака с уроном ×2.2, 25% урона возвращается здоровьем.',
        damageMul: 2.2,
        lifesteal: 0.25,
      ),
      activeCooldown: 3,
      passive: PassiveSkill(
        name: 'Хаос',
        description: '+12% урона, +10% к шансу крита.',
        damageBonus: 0.12,
        critBonus: 0.1,
      ),
      ultimate: ActiveSkill(
        name: 'Спектральный залп',
        description: 'Четыре атаки с уроном ×1.4, 20% урона возвращается здоровьем.',
        damageMul: 1.4,
        hits: 4,
        lifesteal: 0.2,
      ),
    ),
  };

  static SkillSet forKind(String kindId) => _byKind[kindId] ?? _fallback;
}
