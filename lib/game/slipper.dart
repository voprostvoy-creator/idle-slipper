import 'dart:math';
import 'dart:ui';

import 'battle/combatant.dart';
import 'battle/skill_catalog.dart';
import 'battle/skills.dart';
import 'slipper_kind.dart';

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
  }) : levels = {for (final s in Stat.values) s: levels?[s] ?? 1};

  @override
  final String name;
  final String kindId;
  final Map<Stat, int> levels;

  SlipperKind get kind => SlipperCatalog.byId(kindId);

  int level(Stat s) => levels[s]!;

  // --- Производные боевые величины -------------------------------------

  /// Урон растёт линейно с небольшим ускорением, чтобы прокачка ощущалась.
  @override
  double get attack =>
      (10 + level(Stat.attack) * 4.0 + pow(level(Stat.attack), 1.3)) *
      (1 + kind.bonus(Bonus.damage));

  /// Защита работает по формуле 100/(100+def) — никогда не даёт иммунитет.
  @override
  double get defense => level(Stat.defense) * 5.0 * (1 + kind.bonus(Bonus.defense));

  @override
  double get maxHp => (100 + level(Stat.health) * 25.0) * (1 + kind.bonus(Bonus.hp));

  /// Скорость определяет порядок и частоту ходов (см. BattleSim).
  @override
  double get speed => 10 + level(Stat.speed) * 2.0;

  /// Шанс уворота, мягко ограниченный 35% (+ бонус вида).
  @override
  double get dodgeChance =>
      min(0.6, 0.35 * (1 - exp(-level(Stat.speed) / 40)) + kind.bonus(Bonus.dodge));

  /// Шанс крита растёт от атаки, потолок 40% (+ бонус вида).
  @override
  double get critChance =>
      min(0.75, 0.05 + 0.35 * (1 - exp(-level(Stat.attack) / 50)) + kind.bonus(Bonus.crit));

  /// Размер тапка на экране: 60% на старте, каждый уровень Здоровья
  /// съедает 1% оставшегося до 100% — растёт всегда, но не достигает предела.
  @override
  double get sizeFactor => 1 - 0.4 * pow(0.99, level(Stat.health) - 1);

  /// Суммарная «сила» — для подбора соперников и отображения.
  int get power =>
      (attack * 3 + defense * 2 + maxHp / 5 + speed * 2).round();

  int get totalLevel => levels.values.fold(0, (a, b) => a + b);

  // --- Combatant --------------------------------------------------------

  @override
  String get asset => kind.asset;

  @override
  AttackStyle get attackStyle => kind.attack;

  @override
  SkillSet get skills => SkillCatalog.forKind(kindId);

  /// Цвет ауры — по стату, который прокачан сильнее всех.
  static const _auraColors = {
    Stat.attack: Color(0xFFFF9F43),
    Stat.defense: Color(0xFF5BC8FF),
    Stat.health: Color(0xFFFF6161),
    Stat.speed: Color(0xFF6BE07A),
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
    return AuraSpec(color: _auraColors[best]!, strength: strength);
  }

  Slipper copyWith({String? name, String? kindId, Map<Stat, int>? levels}) =>
      Slipper(
        name: name ?? this.name,
        kindId: kindId ?? this.kindId,
        levels: levels ?? Map.of(this.levels),
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'kind': kindId,
        'levels': {for (final e in levels.entries) e.key.name: e.value},
      };

  factory Slipper.fromJson(Map<String, dynamic> json) {
    final raw = (json['levels'] as Map?) ?? const {};
    return Slipper(
      name: json['name'] as String? ?? 'Тапок',
      kindId: json['kind'] as String? ?? SlipperCatalog.defaultId,
      levels: {
        for (final s in Stat.values) s: (raw[s.name] as int?) ?? 1,
      },
    );
  }
}
