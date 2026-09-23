import 'skills.dart';

/// Скиллы по видам тапков. Пока открыты сразу; позже будут выдаваться
/// за улучшение тапка копиями.
class SkillCatalog {
  SkillCatalog._();

  static const _fallback = SkillSet(
    active: ActiveSkill(
      name: 'Сильный шлепок',
      description: 'Удар в полтора раза сильнее обычного.',
      damageMul: 1.5,
    ),
    activeCooldown: 4,
    passive: PassiveSkill(
      name: 'Стойкость',
      description: 'Немного больше защиты.',
      defenseBonus: 10,
    ),
    ultimate: ActiveSkill(
      name: 'Размах',
      description: 'Мощный удар с двойным уроном.',
      damageMul: 2.5,
    ),
  );

  static const _byKind = <String, SkillSet>{
    // Обычный тапок: живучий середняк, лечится сам.
    'basic': SkillSet(
      active: ActiveSkill(
        name: 'Шлепок с оттяжкой',
        description: 'Замах через плечо: урон ×1.8.',
        damageMul: 1.8,
      ),
      activeCooldown: 4,
      passive: PassiveSkill(
        name: 'Домашний уют',
        description: 'Восстанавливает 3% здоровья каждый ход.',
        regenPercent: 0.03,
      ),
      ultimate: ActiveSkill(
        name: 'Бабушкин гнев',
        description: 'Урон ×3 и противник пропускает ход.',
        damageMul: 3,
        stun: true,
      ),
    ),

    // Слайд: скользкий и вёрткий, берёт уворотами и частыми ударами.
    'blue_slide': SkillSet(
      active: ActiveSkill(
        name: 'Подкат',
        description: 'Урон ×1.6 и 25% защиты на два хода.',
        damageMul: 1.6,
        shield: 0.25,
        shieldTurns: 2,
      ),
      activeCooldown: 3,
      passive: PassiveSkill(
        name: 'Скользкая подошва',
        description: 'Ещё +7% к шансу уворота.',
        dodgeBonus: 0.07,
      ),
      ultimate: ActiveSkill(
        name: 'Град шлепков',
        description: 'Три быстрых удара подряд по ×1.2.',
        damageMul: 1.2,
        hits: 3,
      ),
    ),

    // Карбон: танк, держит удар и бьёт сверху.
    'carbon_sport': SkillSet(
      active: ActiveSkill(
        name: 'Прыжковый удар',
        description: 'Удар сверху: урон ×2.',
        damageMul: 2,
      ),
      activeCooldown: 4,
      passive: PassiveSkill(
        name: 'Карбоновая подошва',
        description: 'Жёсткая подошва добавляет защиты.',
        defenseBonus: 35,
      ),
      ultimate: ActiveSkill(
        name: 'Метеоритный удар',
        description: 'Урон ×3.2, противник пропускает ход.',
        damageMul: 3.2,
        stun: true,
      ),
    ),

    // Неон: критует и вытягивает здоровье, поджигает ульту.
    'purple_neon': SkillSet(
      active: ActiveSkill(
        name: 'Фазовый рывок',
        description: 'Урон ×1.7, половина возвращается здоровьем.',
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
        description: 'Урон ×2.6 и поджог на три хода.',
        damageMul: 2.6,
        burnPercent: 0.3,
        burnTurns: 3,
      ),
    ),

    // Адский шип: наказывает за удары по себе и давит уроном.
    'red_spike': SkillSet(
      active: ActiveSkill(
        name: 'Тяжёлый топот',
        description: 'Три шага и удар: урон ×2.1.',
        damageMul: 2.1,
      ),
      activeCooldown: 3,
      passive: PassiveSkill(
        name: 'Шипы',
        description: 'Возвращает атакующему 20% полученного урона.',
        thorns: 0.2,
      ),
      ultimate: ActiveSkill(
        name: 'Адский разлом',
        description: 'Урон ×3.5 и поджог на два хода.',
        damageMul: 3.5,
        burnPercent: 0.35,
        burnTurns: 2,
      ),
    ),

    // Радужный: всё сразу, но честно — лишь у мифического тапка.
    'rainbow': SkillSet(
      active: ActiveSkill(
        name: 'Призматический луч',
        description: 'Урон ×2.2, четверть возвращается здоровьем.',
        damageMul: 2.2,
        lifesteal: 0.25,
      ),
      activeCooldown: 3,
      passive: PassiveSkill(
        name: 'Хаос',
        description: '+12% урона и +10% к шансу крита.',
        damageBonus: 0.12,
        critBonus: 0.1,
      ),
      ultimate: ActiveSkill(
        name: 'Спектральный залп',
        description: 'Четыре луча по ×1.4 с вампиризмом.',
        damageMul: 1.4,
        hits: 4,
        lifesteal: 0.2,
      ),
    ),
  };

  static SkillSet forKind(String kindId) => _byKind[kindId] ?? _fallback;
}
