import 'dart:ui';

/// Редкость тапка: пять ступеней, от обычного до мифического.
/// Чем выше — тем сильнее бонус и реже выпадает из кейса.
enum Rarity {
  common('Обычный', Color(0xFFB9B0C4), 75),
  rare('Редкий', Color(0xFF5BC8FF), 300),
  epic('Эпический', Color(0xFFC77DFF), 800),
  legendary('Легендарный', Color(0xFFFFC93C), 2500),
  mythic('Мифический', Color(0xFFFF5FA2), 8000);

  const Rarity(this.label, this.color, this.sellPrice);
  final String label;
  final Color color;

  /// Сколько ниток дают за продажу такого тапка.
  final int sellPrice;

  /// Ступень редкости для подписи вида «3/5».
  String get tier => '${index + 1}/${Rarity.values.length}';
}

/// Тип бонуса. Значение — доля: 0.10 = +10%.
enum Bonus {
  damage('Урон'),
  defense('Защита'),
  hp('Здоровье'),
  crit('Шанс крита'),
  dodge('Шанс уворота'),
  income('Доход');

  const Bonus(this.label);
  final String label;

  String format(double v) {
    final pct = (v * 100).round();
    return '${pct >= 0 ? '+' : ''}$pct% $label';
  }
}

/// Вид тапка из каталога: картинка, редкость, бонусы.
class SlipperKind {
  const SlipperKind({
    required this.id,
    required this.name,
    required this.rarity,
    required this.asset,
    this.bonuses = const {},
  });

  final String id;
  final String name;
  final Rarity rarity;

  /// Путь к PNG: прозрачный фон, вид сбоку, носок вправо, 1200×600 (2:1).
  final String asset;
  final Map<Bonus, double> bonuses;

  double bonus(Bonus b) => bonuses[b] ?? 0;
}

/// Каталог всех тапков. Чтобы добавить новый:
/// 1) прогнать PNG через `tool/normalize_slipper.py` — он положит его
///    в `assets/slippers/<id>.png`;
/// 2) добавить сюда запись с именем, редкостью и бонусами.
class SlipperCatalog {
  SlipperCatalog._();

  static const String defaultId = 'basic';

  static const List<SlipperKind> all = [
    SlipperKind(
      id: 'basic',
      name: 'Бабушкин клетчатый',
      rarity: Rarity.common,
      asset: 'assets/slippers/basic.png',
    ),
    SlipperKind(
      id: 'blue_slide',
      name: 'Синий слайд',
      rarity: Rarity.rare,
      asset: 'assets/slippers/blue_slide.png',
      bonuses: {Bonus.dodge: 0.05},
    ),
    SlipperKind(
      id: 'carbon_sport',
      name: 'Карбон-спорт',
      rarity: Rarity.epic,
      asset: 'assets/slippers/carbon_sport.png',
      bonuses: {Bonus.damage: 0.08, Bonus.dodge: 0.04},
    ),
    SlipperKind(
      id: 'purple_neon',
      name: 'Неон',
      rarity: Rarity.epic,
      asset: 'assets/slippers/purple_neon.png',
      bonuses: {Bonus.crit: 0.06, Bonus.income: 0.08},
    ),
    SlipperKind(
      id: 'red_spike',
      name: 'Адский шип',
      rarity: Rarity.legendary,
      asset: 'assets/slippers/red_spike.png',
      bonuses: {Bonus.damage: 0.18, Bonus.crit: 0.08, Bonus.hp: 0.08},
    ),
    SlipperKind(
      id: 'rainbow',
      name: 'Радужный хаос',
      rarity: Rarity.mythic,
      asset: 'assets/slippers/rainbow.png',
      bonuses: {
        Bonus.damage: 0.25,
        Bonus.crit: 0.15,
        Bonus.hp: 0.15,
        Bonus.income: 0.1,
      },
    ),
  ];

  static final Map<String, SlipperKind> _byId = {for (final k in all) k.id: k};

  static SlipperKind byId(String id) => _byId[id] ?? _byId[defaultId]!;

  static List<SlipperKind> byRarity(Rarity r) =>
      [for (final k in all) if (k.rarity == r) k];
}
