import 'dart:math';

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

/// Тапок — и игрока, и соперника. Хранит только уровни статов и внешность,
/// все производные величины считаются на лету.
class Slipper {
  Slipper({
    required this.name,
    required this.colorSeed,
    Map<Stat, int>? levels,
  }) : levels = {for (final s in Stat.values) s: levels?[s] ?? 1};

  final String name;

  /// Оттенок в градусах (0..360) — из него рисуется вся палитра тапка.
  final int colorSeed;
  final Map<Stat, int> levels;

  int level(Stat s) => levels[s]!;

  // --- Производные боевые величины -------------------------------------

  /// Урон растёт линейно с небольшим ускорением, чтобы прокачка ощущалась.
  double get attack => 10 + level(Stat.attack) * 4.0 + pow(level(Stat.attack), 1.3);

  /// Защита работает по формуле 100/(100+def) — никогда не даёт иммунитет.
  double get defense => level(Stat.defense) * 5.0;

  double get maxHp => 100 + level(Stat.health) * 25.0;

  /// Скорость определяет порядок и частоту ходов (см. BattleSim).
  double get speed => 10 + level(Stat.speed) * 2.0;

  /// Шанс уворота, мягко ограниченный 35%.
  double get dodgeChance => 0.35 * (1 - exp(-level(Stat.speed) / 40));

  /// Шанс крита растёт от атаки, потолок 40%.
  double get critChance => 0.05 + 0.35 * (1 - exp(-level(Stat.attack) / 50));

  /// Суммарная «сила» — для подбора соперников и отображения.
  int get power =>
      (attack * 3 + defense * 2 + maxHp / 5 + speed * 2).round();

  int get totalLevel => levels.values.fold(0, (a, b) => a + b);

  Slipper copyWith({String? name, int? colorSeed, Map<Stat, int>? levels}) =>
      Slipper(
        name: name ?? this.name,
        colorSeed: colorSeed ?? this.colorSeed,
        levels: levels ?? Map.of(this.levels),
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'colorSeed': colorSeed,
        'levels': {for (final e in levels.entries) e.key.name: e.value},
      };

  factory Slipper.fromJson(Map<String, dynamic> json) {
    final raw = (json['levels'] as Map?) ?? const {};
    return Slipper(
      name: json['name'] as String? ?? 'Тапок',
      colorSeed: json['colorSeed'] as int? ?? 30,
      levels: {
        for (final s in Stat.values) s: (raw[s.name] as int?) ?? 1,
      },
    );
  }
}
