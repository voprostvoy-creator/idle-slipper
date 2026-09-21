import 'dart:math';

import 'slipper_kind.dart';

/// Четыре характеристики тапка. Каждая качается отдельно.
enum Stat {
  attack('Удар', 'Уд', 'Урон за попадание'),
  defense('Подошва', 'По', 'Снижает входящий урон'),
  health('Прочность', 'Пр', 'Запас здоровья'),
  speed('Скорость', 'Ск', 'Частота ходов и шанс уворота');

  const Stat(this.label, this.short, this.hint);
  final String label;
  final String short;
  final String hint;
}

/// Экземпляр тапка — и игрока, и соперника: вид из каталога + уровни статов.
/// Все производные величины считаются на лету с учётом бонусов вида.
class Slipper {
  Slipper({
    required this.name,
    this.kindId = SlipperCatalog.defaultId,
    Map<Stat, int>? levels,
  }) : levels = {for (final s in Stat.values) s: levels?[s] ?? 1};

  final String name;
  final String kindId;
  final Map<Stat, int> levels;

  SlipperKind get kind => SlipperCatalog.byId(kindId);

  int level(Stat s) => levels[s]!;

  // --- Производные боевые величины -------------------------------------

  /// Урон растёт линейно с небольшим ускорением, чтобы прокачка ощущалась.
  double get attack =>
      (10 + level(Stat.attack) * 4.0 + pow(level(Stat.attack), 1.3)) *
      (1 + kind.bonus(Bonus.damage));

  /// Защита работает по формуле 100/(100+def) — никогда не даёт иммунитет.
  double get defense => level(Stat.defense) * 5.0 * (1 + kind.bonus(Bonus.defense));

  double get maxHp => (100 + level(Stat.health) * 25.0) * (1 + kind.bonus(Bonus.hp));

  /// Скорость определяет порядок и частоту ходов (см. BattleSim).
  double get speed => 10 + level(Stat.speed) * 2.0;

  /// Шанс уворота, мягко ограниченный 35% (+ бонус вида).
  double get dodgeChance =>
      min(0.6, 0.35 * (1 - exp(-level(Stat.speed) / 40)) + kind.bonus(Bonus.dodge));

  /// Шанс крита растёт от атаки, потолок 40% (+ бонус вида).
  double get critChance =>
      min(0.75, 0.05 + 0.35 * (1 - exp(-level(Stat.attack) / 50)) + kind.bonus(Bonus.crit));

  /// Суммарная «сила» — для подбора соперников и отображения.
  int get power =>
      (attack * 3 + defense * 2 + maxHp / 5 + speed * 2).round();

  int get totalLevel => levels.values.fold(0, (a, b) => a + b);

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
