import 'dart:math';
import 'dart:ui';

import 'slipper_kind.dart';

/// Какую характеристику усиливает гем.
enum GemType {
  attack('Удар', Color(0xFFFF7A45)),
  defense('Прочность', Color(0xFF5BC8FF)),
  health('Здоровье', Color(0xFFFF5C7A)),
  speed('Скорость', Color(0xFF6BE07A)),
  crit('Крит', Color(0xFFFFC93C)),
  dodge('Уворот', Color(0xFFC77DFF));

  const GemType(this.label, this.color);
  final String label;
  final Color color;

  /// Крит и уворот — шансы: гем добавляет к ним проценты напрямую.
  bool get isChance => this == crit || this == dodge;
}

/// Гем: тип, редкость, уровень 1..[maxLevel]. Качается слиянием трёх
/// одинаковых в один уровнем выше.
class Gem {
  const Gem({required this.id, required this.type, required this.rarity, this.level = 1});

  static const maxLevel = 5;

  final int id;
  final GemType type;
  final Rarity rarity;
  final int level;

  /// Плоская прибавка (обычные и редкие) или проценты (эпические и выше).
  bool get isPercent => rarity.index >= Rarity.epic.index || type.isChance;

  /// Величина бонуса: для процентов — доля (0.03 = 3%), иначе — единицы стата.
  double get value {
    if (type.isChance) {
      const perLevel = [0.005, 0.01, 0.015, 0.02, 0.03];
      return perLevel[rarity.index] * level;
    }
    if (isPercent) {
      const perLevel = {Rarity.epic: 0.03, Rarity.legendary: 0.05, Rarity.mythic: 0.08};
      return perLevel[rarity]! * level;
    }
    final base = switch (type) {
      GemType.attack => 3.0,
      GemType.defense => 4.0,
      GemType.health => 20.0,
      GemType.speed => 1.5,
      _ => 0.0,
    };
    return base * (rarity == Rarity.rare ? 2 : 1) * level;
  }

  /// Подпись бонуса: «+6 к удару», «+9% здоровья», «+2% к шансу крита».
  String get bonusText {
    if (type.isChance) {
      return '+${_pct(value)}% к шансу ${type == GemType.crit ? 'крита' : 'уворота'}';
    }
    final what = switch (type) {
      GemType.attack => 'удара',
      GemType.defense => 'прочности',
      GemType.health => 'здоровья',
      GemType.speed => 'скорости',
      _ => '',
    };
    if (isPercent) return '+${_pct(value)}% $what';
    final n = value == value.roundToDouble() ? value.round().toString() : value.toStringAsFixed(1);
    return '+$n $what';
  }

  static String _pct(double v) {
    final p = v * 100;
    return p == p.roundToDouble() ? p.round().toString() : p.toStringAsFixed(1);
  }

  /// Можно ли слить с другим: тот же тип, редкость и уровень.
  bool sameAs(Gem o) => o.type == type && o.rarity == rarity && o.level == level;

  Gem copyWith({int? id, int? level}) =>
      Gem(id: id ?? this.id, type: type, rarity: rarity, level: level ?? this.level);

  Map<String, dynamic> toJson() =>
      {'id': id, 'type': type.name, 'rarity': rarity.name, 'level': level};

  static Gem? fromJson(Map<String, dynamic> j) {
    final type = GemType.values.where((t) => t.name == j['type']).firstOrNull;
    final rarity = Rarity.values.where((r) => r.name == j['rarity']).firstOrNull;
    if (type == null || rarity == null) return null;
    return Gem(
      id: (j['id'] as num).toInt(),
      type: type,
      rarity: rarity,
      level: ((j['level'] as num?)?.toInt() ?? 1).clamp(1, maxLevel),
    );
  }

  /// Случайный гем заданной редкости.
  static Gem random(Random rng, {required int id, required Rarity rarity}) =>
      Gem(id: id, type: GemType.values[rng.nextInt(GemType.values.length)], rarity: rarity);
}

/// Сумма бонусов вставленных гемов — её применяет тапок к своим статам.
class GemBonus {
  GemBonus(Iterable<Gem> gems) {
    for (final g in gems) {
      final v = g.value;
      switch (g.type) {
        case GemType.attack:
          g.isPercent ? attackPct += v : attackFlat += v;
        case GemType.defense:
          g.isPercent ? defensePct += v : defenseFlat += v;
        case GemType.health:
          g.isPercent ? hpPct += v : hpFlat += v;
        case GemType.speed:
          g.isPercent ? speedPct += v : speedFlat += v;
        case GemType.crit:
          crit += v;
        case GemType.dodge:
          dodge += v;
      }
    }
  }

  static final none = GemBonus(const []);

  double attackFlat = 0, attackPct = 0;
  double defenseFlat = 0, defensePct = 0;
  double hpFlat = 0, hpPct = 0;
  double speedFlat = 0, speedPct = 0;
  double crit = 0, dodge = 0;
}

class Gems {
  Gems._();

  /// Слоты под гемы открываются чётными звёздами: ★0 — 1, ★2 — 2, ★4 — 3.
  static int slotsFor(int stars) => stars >= 4 ? 3 : (stars >= 2 ? 2 : 1);

  static const maxSlots = 3;

  /// На какой звезде открывается слот [index] (0..2).
  static int slotStar(int index) => const [0, 2, 4][index];
}
