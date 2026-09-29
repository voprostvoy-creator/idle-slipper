import 'dart:math';

import 'battle/combatant.dart';
import 'battle/skill_catalog.dart';
import 'battle/skills.dart';
import 'gems.dart';
import 'slipper_kind.dart';
import 'stars.dart';

/// Четыре характеристики тапка. Каждая качается отдельно.
enum Stat {
  attack('Удар', 'Уд', 'Урон за попадание'),
  defense('Прочность', 'Пр', 'Снижает входящий урон'),
  health('Здоровье', 'Зд', 'Запас здоровья'),
  speed('Скорость', 'Ск', 'Частота ходов и шанс уворота');

  const Stat(this.label, this.short, this.hint);
  final String label;
  final String short;
  final String hint;
}

/// Экземпляр тапка — и игрока, и соперника: вид из каталога + уровни статов.
/// Все производные величины считаются на лету с учётом бонусов вида.
class Slipper implements Combatant {
  Slipper({
    required this.name,
    this.kindId = SlipperCatalog.defaultId,
    Map<Stat, int>? levels,
    this.stars = 0,
    this.gems = const [],
  }) : levels = {for (final s in Stat.values) s: levels?[s] ?? 1};

  @override
  final String name;
  final String kindId;
  final Map<Stat, int> levels;

  /// Звёзды вида (0..5) — усиливают удар, прочность и здоровье.
  final int stars;

  double get _starMul => Stars.multiplier(stars);

  /// Гемы, вставленные в слоты этого вида.
  final List<Gem> gems;

  GemBonus get _gem => gems.isEmpty ? GemBonus.none : GemBonus(gems);

  SlipperKind get kind => SlipperCatalog.byId(kindId);

  int level(Stat s) => levels[s]!;

  // --- Производные боевые величины -------------------------------------

  /// Урон растёт линейно с небольшим ускорением, чтобы прокачка ощущалась.
  @override
  double get attack =>
      (10 + level(Stat.attack) * 4.0 + pow(level(Stat.attack), 1.3)) *
          kind.rarity.statMul *
          (1 + kind.bonus(Bonus.damage) + _gem.attackPct) *
          _starMul +
      _gem.attackFlat;

  /// Защита работает по формуле 100/(100+def) — никогда не даёт иммунитет.
  @override
  double get defense =>
      level(Stat.defense) *
          5.0 *
          kind.rarity.statMul *
          (1 + kind.bonus(Bonus.defense) + _gem.defensePct) *
          _starMul +
      _gem.defenseFlat;

  @override
  double get maxHp =>
      (100 + level(Stat.health) * 25.0) *
          kind.rarity.statMul *
          (1 + kind.bonus(Bonus.hp) + _gem.hpPct) *
          _starMul +
      _gem.hpFlat;

  /// Скорость определяет порядок и частоту ходов (см. BattleSim).
  @override
  double get speed =>
      (10 + kind.rarity.speedBonus + level(Stat.speed) * 2.0) * (1 + _gem.speedPct) +
      _gem.speedFlat;

  /// Шанс уворота, мягко ограниченный 35% (+ бонус вида).
  @override
  double get dodgeChance => min(
    0.6,
    0.35 * (1 - exp(-level(Stat.speed) / 40)) +
        kind.bonus(Bonus.dodge) +
        _gem.dodge,
  );

  /// Шанс крита растёт от атаки, потолок 40% (+ бонус вида).
  @override
  double get critChance => min(
    0.75,
    0.05 +
        0.35 * (1 - exp(-level(Stat.attack) / 50)) +
        kind.bonus(Bonus.crit) +
        _gem.crit,
  );

  /// Размер тапка на экране: 60% на старте, каждый уровень Здоровья
  /// съедает 1% оставшегося до 100% — растёт всегда, но не достигает предела.
  @override
  double get sizeFactor => 1 - 0.4 * pow(0.99, level(Stat.health) - 1);

  /// Суммарная «сила» — для подбора соперников и отображения.
  int get power => combatPower(this);

  int get totalLevel => levels.values.fold(0, (a, b) => a + b);

  // --- Combatant --------------------------------------------------------

  @override
  String get asset => kind.asset;

  @override
  AttackStyle get attackStyle => kind.attack;

  @override
  /// Скиллы открываются звёздами: ★1 — активный, ★3 — пассивный, ★5 — ульта.
  SkillSet get skills => SkillCatalog.forKind(kindId).unlockedAt(stars);

  /// Цвет ауры — по стату, который прокачан сильнее всех.
  static const _auraColors = <Stat, int>{
    Stat.attack: 0xFFFF9F43,
    Stat.defense: 0xFF5BC8FF,
    Stat.health: 0xFFFF6161,
    Stat.speed: 0xFF6BE07A,
  };

  @override
  AuraSpec? get aura {
    // На старте ауры нет, к ~70 суммарным уровням она на максимуме.
    final strength = ((totalLevel - Stat.values.length) / 66).clamp(0.0, 1.0);
    if (strength <= 0) return null;
    var best = Stat.values.first;
    for (final s in Stat.values) {
      if (level(s) > level(best)) best = s;
    }
    return AuraSpec(argb: _auraColors[best]!, strength: strength);
  }

  Slipper copyWith({
    String? name,
    String? kindId,
    Map<Stat, int>? levels,
    int? stars,
    List<Gem>? gems,
  }) => Slipper(
    name: name ?? this.name,
    kindId: kindId ?? this.kindId,
    levels: levels ?? Map.of(this.levels),
    stars: stars ?? this.stars,
    gems: gems ?? this.gems,
  );

  /// Снимок тапка: уровни, звёзды и вставленные гемы — всё, что влияет
  /// на бой. Его хранит сервер, и с ним сражаются другие игроки.
  Map<String, dynamic> toJson() => {
    'name': name,
    'kind': kindId,
    'levels': {for (final e in levels.entries) e.key.name: e.value},
    'stars': stars,
    'gems': [for (final g in gems) g.toJson()],
  };

  factory Slipper.fromJson(Map<String, dynamic> json) {
    final raw = (json['levels'] as Map?) ?? const {};
    final kind = json['kind'] as String? ?? SlipperCatalog.defaultId;
    return Slipper(
      name: json['name'] as String? ?? 'Тапок',
      // Неизвестный вид (например, из новой версии игры) — базовый тапок.
      kindId: SlipperCatalog.all.any((k) => k.id == kind) ? kind : SlipperCatalog.defaultId,
      levels: {for (final s in Stat.values) s: ((raw[s.name] as num?)?.toInt() ?? 1).clamp(1, 1000)},
      stars: ((json['stars'] as num?)?.toInt() ?? 0).clamp(0, Stars.max),
      gems: [
        for (final g in (json['gems'] as List? ?? const []).take(Gems.maxSlots))
          ?Gem.fromJson((g as Map).cast<String, dynamic>()),
      ],
    );
  }
}
