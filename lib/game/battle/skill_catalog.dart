import 'dart:ui';

import 'combatant.dart';
import 'skills.dart';

/// Скиллы по видам тапков. Пока открыты сразу; позже будут выдаваться
/// за улучшение тапка копиями.
///
/// У каждого свой почерк: кто-то давит уроном, кто-то контролит,
/// кто-то живёт с чужого здоровья. Манера удара и росчерк задаются здесь же,
/// чтобы скилл читался в бою, а не только в цифрах.
class SkillCatalog {
  SkillCatalog._();

  static const _fallback = SkillSet(
    active: ActiveSkill(
      name: 'Сильный шлепок',
      description: 'Атака с уроном ×1.5.',
      damageMul: 1.5,
      vfx: SkillVfx.slash,
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
      vfx: SkillVfx.burst,
    ),
  );

  static const _byKind = <String, SkillSet>{
    // Клетчатый: держится за счёт лечения и переживает чужие серии.
    'basic': SkillSet(
      active: ActiveSkill(
        name: 'Шлепок с оттяжкой',
        description: 'Атака с уроном ×1.7 и лечение на 10% здоровья.',
        damageMul: 1.7,
        healPercent: 0.1,
        style: AttackStyle.lunge,
        vfx: SkillVfx.slash,
        vfxColor: Color(0xFFFFE28A),
      ),
      activeCooldown: 4,
      passive: PassiveSkill(
        name: 'Домашний уют',
        description: '+3% здоровья каждый ход, +20% урона ниже половины HP.',
        regenPercent: 0.03,
        lowHpDamageBonus: 0.2,
      ),
      ultimate: ActiveSkill(
        name: 'Бабушкин гнев',
        description:
            'Атака с уроном ×2.6, противник пропускает ход и слабеет на 25% (3 хода).',
        damageMul: 2.6,
        stun: true,
        weaken: 0.25,
        weakenTurns: 3,
        style: AttackStyle.slam,
        vfx: SkillVfx.shockwave,
        vfxColor: Color(0xFFFFC93C),
      ),
    ),

    // Слайд: не столько бьёт, сколько не даёт попасть по себе.
    'blue_slide': SkillSet(
      active: ActiveSkill(
        name: 'Подкат',
        description: 'Атака с уроном ×1.4, следующая атака противника мимо.',
        damageMul: 1.4,
        evadeTurns: 1,
        style: AttackStyle.dash,
        vfx: SkillVfx.slash,
        vfxColor: Color(0xFF5BC8FF),
      ),
      activeCooldown: 3,
      passive: PassiveSkill(
        name: 'Скользкая подошва',
        description: '+7% к шансу уворота.',
        dodgeBonus: 0.07,
      ),
      ultimate: ActiveSkill(
        name: 'Град шлепков',
        description: 'Три атаки по ×1.2 и +40% скорости на 3 хода.',
        damageMul: 1.2,
        hits: 3,
        haste: 0.4,
        hasteTurns: 3,
        style: AttackStyle.dash,
        vfx: SkillVfx.blades,
        vfxColor: Color(0xFF5BC8FF),
      ),
    ),

    // Карбон: танк, который копит защиту и продавливает её у чужих.
    'carbon_sport': SkillSet(
      active: ActiveSkill(
        name: 'Прыжковый удар',
        description: 'Атака с уроном ×1.7 и барьер на 18% здоровья.',
        damageMul: 1.7,
        barrierPercent: 0.18,
        style: AttackStyle.slam,
        vfx: SkillVfx.shockwave,
        vfxColor: Color(0xFF5BC8FF),
      ),
      activeCooldown: 4,
      passive: PassiveSkill(
        name: 'Карбоновая подошва',
        description: '+35 к защите, 10% урона возвращается атакующему.',
        defenseBonus: 35,
        thorns: 0.1,
      ),
      ultimate: ActiveSkill(
        name: 'Метеоритный удар',
        description:
            'Атака с уроном ×2.8, игнорирует половину защиты, противник пропускает ход.',
        damageMul: 2.8,
        pierce: 0.5,
        stun: true,
        style: AttackStyle.meteor,
        vfx: SkillVfx.burst,
        vfxColor: Color(0xFFFF9F43),
      ),
    ),

    // Неон: живёт с чужого здоровья и душит уроном по времени.
    'purple_neon': SkillSet(
      active: ActiveSkill(
        name: 'Фазовый рывок',
        description: 'Атака с уроном ×1.6, 60% урона возвращается здоровьем.',
        damageMul: 1.6,
        lifesteal: 0.6,
        style: AttackStyle.blink,
        vfx: SkillVfx.drain,
        vfxColor: Color(0xFFC77DFF),
      ),
      activeCooldown: 3,
      passive: PassiveSkill(
        name: 'Неоновый заряд',
        description: '+10% к шансу крита, криты бьют сильнее на 40%.',
        critBonus: 0.1,
        critDamageBonus: 0.4,
      ),
      ultimate: ActiveSkill(
        name: 'Перегрузка',
        description:
            'Атака с уроном ×2.2, поджог на 3 хода и −25% урона противника (3 хода).',
        damageMul: 2.2,
        burnPercent: 0.35,
        burnTurns: 3,
        weaken: 0.25,
        weakenTurns: 3,
        style: AttackStyle.blink,
        vfx: SkillVfx.gloom,
        vfxColor: Color(0xFFC77DFF),
      ),
    ),

    // Адский шип: контроль темпа — замедляет и добивает.
    'red_spike': SkillSet(
      active: ActiveSkill(
        name: 'Тяжёлый топот',
        description: 'Атака с уроном ×1.9 и −35% скорости противника (2 хода).',
        damageMul: 1.9,
        slow: 0.35,
        slowTurns: 2,
        style: AttackStyle.slam,
        vfx: SkillVfx.shockwave,
        vfxColor: Color(0xFFFF6161),
      ),
      activeCooldown: 3,
      passive: PassiveSkill(
        name: 'Шипы',
        description:
            '20% полученного урона возвращается атакующему, добивание ниже 25% HP бьёт вдвое.',
        thorns: 0.2,
        executeThreshold: 0.25,
      ),
      ultimate: ActiveSkill(
        name: 'Адский разлом',
        description:
            'Атака с уроном ×3, всегда крит, игнорирует 40% защиты и поджигает на 2 хода.',
        damageMul: 3,
        alwaysCrit: true,
        pierce: 0.4,
        burnPercent: 0.3,
        burnTurns: 2,
        style: AttackStyle.charge,
        vfx: SkillVfx.burst,
        vfxColor: Color(0xFFFF6161),
      ),
    ),

    // Радужный: мифический — берёт всем понемногу и ходит вне очереди.
    'rainbow': SkillSet(
      active: ActiveSkill(
        name: 'Призматический луч',
        description: 'Атака с уроном ×2, игнорирует половину защиты.',
        damageMul: 2,
        pierce: 0.5,
        style: AttackStyle.laser,
        vfx: SkillVfx.slash,
        vfxColor: Color(0xFF4FD8FF),
      ),
      activeCooldown: 3,
      passive: PassiveSkill(
        name: 'Хаос',
        description: '+12% урона, +10% к шансу крита, 8% урона возвращается здоровьем.',
        damageBonus: 0.12,
        critBonus: 0.1,
        lifesteal: 0.08,
      ),
      ultimate: ActiveSkill(
        name: 'Спектральный залп',
        description: 'Четыре атаки по ×1.3 с вампиризмом и сразу ещё один ход.',
        damageMul: 1.3,
        hits: 4,
        lifesteal: 0.2,
        extraTurn: true,
        style: AttackStyle.laser,
        vfx: SkillVfx.blades,
        vfxColor: Color(0xFFB06BFF),
      ),
    ),
  };

  static SkillSet forKind(String kindId) => _byKind[kindId] ?? _fallback;
}
