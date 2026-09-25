import 'dart:math';
import 'dart:ui';

import '../battle/combatant.dart';
import '../battle/skills.dart';
import '../slipper.dart';

/// Вид противника из сюжета: картинка, манера удара, скиллы и множители
/// к статам. Сами статы задаёт этап главы уровнями — как у тапков.
class EnemyKind {
  const EnemyKind({
    required this.id,
    required this.name,
    required this.attackStyle,
    required this.skills,
    required this.size,
    this.hp = 1,
    this.attack = 1,
    this.defense = 1,
    this.speed = 1,
  });

  final String id;
  final String name;
  final AttackStyle attackStyle;
  final SkillSet skills;

  /// Размер на экране; у тапка на старте 0.6.
  final double size;

  /// Множители к статам, посчитанным по формулам тапка.
  final double hp;
  final double attack;
  final double defense;
  final double speed;

  String get asset => 'assets/enemies/$id.webp';
}

/// Насекомое на конкретном этапе. Статы считаются по тем же формулам, что
/// у тапка, поэтому «сила» у них на одной шкале.
class Enemy implements Combatant {
  Enemy({
    required this.kind,
    required this.levels,
    String? name,
    this.elite = false,
    this.boss = false,
  }) : name = name ?? kind.name;

  final EnemyKind kind;
  final Map<Stat, int> levels;

  /// Элитный — усиленная версия того же насекомого: крупнее и с красной аурой.
  final bool elite;
  final bool boss;

  @override
  final String name;

  int _lv(Stat s) => levels[s] ?? 1;

  @override
  String get asset => kind.asset;

  @override
  AttackStyle get attackStyle => kind.attackStyle;

  @override
  double get attack =>
      (10 + _lv(Stat.attack) * 4.0 + pow(_lv(Stat.attack), 1.3)) * kind.attack;

  @override
  double get defense => _lv(Stat.defense) * 5.0 * kind.defense;

  @override
  double get maxHp => (100 + _lv(Stat.health) * 25.0) * kind.hp;

  @override
  double get speed => (10 + _lv(Stat.speed) * 2.0) * kind.speed;

  @override
  double get dodgeChance => 0.35 * (1 - exp(-_lv(Stat.speed) / 40));

  @override
  double get critChance => 0.05 + 0.35 * (1 - exp(-_lv(Stat.attack) / 50));

  @override
  double get sizeFactor => kind.size * (elite ? 1.12 : 1);

  @override
  AuraSpec? get aura => boss
      ? const AuraSpec(color: Color(0xFFFFC53D), strength: 0.85)
      : elite
          ? const AuraSpec(color: Color(0xFFFF4747), strength: 0.6)
          : null;

  @override
  SkillSet get skills => kind.skills;

  int get power => combatPower(this);
}

/// Все насекомые сюжета.
class EnemyCatalog {
  EnemyCatalog._();

  /// Быстрая и вёрткая, но хрупкая.
  static const fly = EnemyKind(
    id: 'fly',
    name: 'Муха',
    attackStyle: AttackStyle.blink,
    size: 0.55,
    hp: 0.7,
    attack: 0.9,
    defense: 0.6,
    speed: 1.25,
    skills: SkillSet(
      active: ActiveSkill(
        name: 'Мельтешение',
        description: 'Атака с уроном ×1.2, следующая атака противника мимо.',
        damageMul: 1.2,
        evadeTurns: 1,
      ),
      activeCooldown: 3,
      passive: PassiveSkill(
        name: 'Вёрткость',
        description: '+8% к шансу уворота.',
        dodgeBonus: 0.08,
      ),
      ultimate: ActiveSkill(
        name: 'Жужжащий рой',
        description: 'Три атаки по ×0.9.',
        damageMul: 0.9,
        hits: 3,
      ),
    ),
  );

  /// Середнячок главы: ничего особенного, но живучий.
  static const cockroach = EnemyKind(
    id: 'cockroach',
    name: 'Таракан',
    attackStyle: AttackStyle.dash,
    size: 0.62,
    skills: SkillSet(
      active: ActiveSkill(
        name: 'Шмыг',
        description: 'Атака с уроном ×1.5 и +30% скорости (2 хода).',
        damageMul: 1.5,
        haste: 0.3,
        hasteTurns: 2,
      ),
      activeCooldown: 3,
      passive: PassiveSkill(
        name: 'Живучесть',
        description: '+2% здоровья каждый ход.',
        regenPercent: 0.02,
      ),
      ultimate: ActiveSkill(
        name: 'Тараканий натиск',
        description: 'Атака с уроном ×2.2.',
        damageMul: 2.2,
      ),
    ),
  );

  /// Лечится с каждого укола — его надо добивать быстро.
  static const mosquito = EnemyKind(
    id: 'mosquito',
    name: 'Комар',
    attackStyle: AttackStyle.lunge,
    size: 0.62,
    hp: 0.8,
    defense: 0.7,
    speed: 1.15,
    skills: SkillSet(
      active: ActiveSkill(
        name: 'Укус',
        description: 'Атака с уроном ×1.3, 60% урона возвращается здоровьем.',
        damageMul: 1.3,
        lifesteal: 0.6,
      ),
      activeCooldown: 3,
      passive: PassiveSkill(
        name: 'Жажда',
        description: '10% урона возвращается здоровьем.',
        lifesteal: 0.1,
      ),
      ultimate: ActiveSkill(
        name: 'Кровопийца',
        description: 'Атака с уроном ×2, весь урон возвращается здоровьем.',
        damageMul: 2,
        lifesteal: 1,
      ),
    ),
  );

  /// Танк: толстая броня, бьёт редко, но больно.
  static const rhinoBeetle = EnemyKind(
    id: 'rhino_beetle',
    name: 'Жук-носорог',
    attackStyle: AttackStyle.charge,
    size: 0.75,
    hp: 1.25,
    attack: 1.1,
    defense: 1.6,
    speed: 0.8,
    skills: SkillSet(
      active: ActiveSkill(
        name: 'Панцирь',
        description: 'Атака и барьер на 15% здоровья.',
        barrierPercent: 0.15,
      ),
      activeCooldown: 4,
      passive: PassiveSkill(
        name: 'Толстая броня',
        description: '+15 к защите.',
        defenseBonus: 15,
      ),
      ultimate: ActiveSkill(
        name: 'Таран рогом',
        description: 'Атака с уроном ×2.4, противник пропускает ход.',
        damageMul: 2.4,
        stun: true,
      ),
    ),
  );

  /// Босс первой главы.
  static const roachKing = EnemyKind(
    id: 'roach_king',
    name: 'Таракан-король',
    attackStyle: AttackStyle.stomp,
    // Картинка почти квадратная и в боксе 2:1 выходит узкой — босс
    // крупнее бокса, чтобы возвышался над тапком.
    size: 1.25,
    hp: 1.4,
    attack: 1.1,
    defense: 1.3,
    speed: 0.95,
    skills: SkillSet(
      active: ActiveSkill(
        name: 'Королевский указ',
        description: 'Атака с уроном ×1.4, противник слабеет на 25% (3 хода).',
        damageMul: 1.4,
        weaken: 0.25,
        weakenTurns: 3,
      ),
      activeCooldown: 3,
      passive: PassiveSkill(
        name: 'Королевская стать',
        description: '+10 к защите, +2% здоровья каждый ход.',
        defenseBonus: 10,
        regenPercent: 0.02,
      ),
      ultimate: ActiveSkill(
        name: 'Тронный топот',
        description:
            'Атака с уроном ×2.4, противник пропускает ход, барьер на 20% здоровья.',
        damageMul: 2.4,
        stun: true,
        barrierPercent: 0.2,
      ),
    ),
  );
}
