import 'dart:ui';

/// Редкость тапка. Чем выше — тем сильнее бонус и реже выпадает из кейса.
enum Rarity {
  common('Обычный', Color(0xFFB9B0C4)),
  rare('Редкий', Color(0xFF5BC8FF)),
  epic('Эпический', Color(0xFFC77DFF)),
  legendary('Легендарный', Color(0xFFFFC93C));

  const Rarity(this.label, this.color);
  final String label;
  final Color color;
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
      name: 'Домашний тапок',
      rarity: Rarity.common,
      asset: 'assets/slippers/basic.png',
      anchors: SlipperAnchors(
        ridge: [
          Offset(0.40, 0.19),
          Offset(0.48, 0.07),
          Offset(0.59, 0.02),
          Offset(0.70, 0.03),
          Offset(0.79, 0.12),
        ],
        side: [Offset(0.50, 0.51), Offset(0.60, 0.53), Offset(0.70, 0.52)],
        heel: Offset(0.34, 0.28),
        sole: Rect.fromLTRB(0.21, 0.67, 0.83, 0.72),
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
        sole: Rect.fromLTRB(0.15, 0.80, 0.85, 0.87),
      ),
      bonuses: {Bonus.dodge: 0.05},
    ),
  ];

  static final Map<String, SlipperKind> _byId = {for (final k in all) k.id: k};

  static SlipperKind byId(String id) => _byId[id] ?? _byId[defaultId]!;
}
