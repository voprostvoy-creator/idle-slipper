import 'dart:ui';

/// Редкость тапка. Чем выше — тем сильнее бонус и реже выпадает из кейса.
enum Rarity {
  common('Обычный', Color(0xFFB9B0C4), 60, 0.15),
  rare('Редкий', Color(0xFF5BC8FF), 28, 0.6),
  epic('Эпический', Color(0xFFC77DFF), 10, 1.6),
  legendary('Легендарный', Color(0xFFFFC93C), 2, 6.0);

  const Rarity(this.label, this.color, this.weight, this.sellFactor);
  final String label;
  final Color color;

  /// Вес при розыгрыше кейса (нормализуется по тем видам, что есть в каталоге).
  final int weight;

  /// Цена продажи как доля от цены кейса: обычный уходит в сильный минус.
  final double sellFactor;
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

/// Точки крепления аксессуаров прокачки. Координаты — доли размера PNG
/// (0..1 по ширине и высоте), тапок смотрит вправо.
class SlipperAnchors {
  const SlipperAnchors({
    required this.ridge,
    required this.side,
    required this.heel,
    required this.sole,
  });

  /// Верхний контур от пятки к носку — сюда вешаются шипы.
  /// Нужно минимум 2 точки, направление шипа считается по соседним.
  final List<Offset> ridge;

  /// Точки на боку — пластины и бинты.
  final List<Offset> side;

  /// Откуда вырывается пламя (задняя кромка).
  final Offset heel;

  /// Полоса подошвы для подсветки.
  final Rect sole;
}

/// Вид тапка из каталога: картинка, редкость, бонус, якоря.
class SlipperKind {
  const SlipperKind({
    required this.id,
    required this.name,
    required this.rarity,
    required this.asset,
    required this.anchors,
    this.bonuses = const {},
  });

  final String id;
  final String name;
  final Rarity rarity;

  /// Путь к PNG: прозрачный фон, вид сбоку, носок вправо, желательно 1200×600 (2:1).
  final String asset;
  final SlipperAnchors anchors;
  final Map<Bonus, double> bonuses;

  double bonus(Bonus b) => bonuses[b] ?? 0;
}

/// Каталог всех тапков. Чтобы добавить новый:
/// 1) положить PNG в `assets/slippers/<id>.png`;
/// 2) добавить запись сюда, подобрать якоря (см. SlipperAnchors).
class SlipperCatalog {
  SlipperCatalog._();

  static const String defaultId = 'basic';

  static const List<SlipperKind> all = [
    SlipperKind(
      id: 'basic',
      name: 'Бабушкин клетчатый',
      rarity: Rarity.common,
      asset: 'assets/slippers/basic.png',
      anchors: SlipperAnchors(
        ridge: [
          Offset(0.54, 0.31),
          Offset(0.58, 0.20),
          Offset(0.62, 0.17),
          Offset(0.70, 0.26),
          Offset(0.78, 0.33),
        ],
        side: [Offset(0.57, 0.66), Offset(0.65, 0.62), Offset(0.73, 0.66)],
        heel: Offset(0.07, 0.62),
        sole: Rect.fromLTRB(0.20, 0.79, 0.80, 0.91),
      ),
    ),
    SlipperKind(
      id: 'blue_slide',
      name: 'Синий слайд',
      rarity: Rarity.rare,
      asset: 'assets/slippers/blue_slide.png',
      anchors: SlipperAnchors(
        ridge: [
          Offset(0.54, 0.29),
          Offset(0.60, 0.18),
          Offset(0.66, 0.23),
          Offset(0.72, 0.31),
          Offset(0.78, 0.40),
        ],
        side: [Offset(0.55, 0.66), Offset(0.63, 0.60), Offset(0.71, 0.64)],
        heel: Offset(0.07, 0.62),
        sole: Rect.fromLTRB(0.18, 0.80, 0.82, 0.92),
      ),
      bonuses: {Bonus.dodge: 0.05},
    ),
    SlipperKind(
      id: 'carbon_sport',
      name: 'Карбон-спорт',
      rarity: Rarity.epic,
      asset: 'assets/slippers/carbon_sport.png',
      anchors: SlipperAnchors(
        ridge: [
          Offset(0.54, 0.32),
          Offset(0.58, 0.26),
          Offset(0.62, 0.22),
          Offset(0.68, 0.27),
          Offset(0.76, 0.35),
        ],
        side: [Offset(0.57, 0.62), Offset(0.64, 0.58), Offset(0.71, 0.62)],
        heel: Offset(0.07, 0.62),
        sole: Rect.fromLTRB(0.18, 0.80, 0.82, 0.92),
      ),
      bonuses: {Bonus.damage: 0.08, Bonus.dodge: 0.04},
    ),
  ];

  static final Map<String, SlipperKind> _byId = {for (final k in all) k.id: k};

  static SlipperKind byId(String id) => _byId[id] ?? _byId[defaultId]!;
}
