import 'package:flutter/material.dart';

import '../game/gems.dart';
import 'theme.dart';

/// Название гема для подписей: «Эпический гем удара».
String gemTitle(Gem g) {
  final what = switch (g.type) {
    GemType.attack => 'удара',
    GemType.defense => 'прочности',
    GemType.health => 'здоровья',
    GemType.speed => 'скорости',
    GemType.crit => 'крита',
    GemType.dodge => 'уворота',
  };
  final adj = switch (g.rarity.index) {
    0 => 'Обычный',
    1 => 'Редкий',
    2 => 'Эпический',
    3 => 'Легендарный',
    _ => 'Мифический',
  };
  return '$adj гем $what';
}

/// Значок гема: огранённый камень цвета характеристики в рамке цвета
/// редкости, в углу — уровень.
class GemIcon extends StatelessWidget {
  const GemIcon({super.key, required this.gem, this.size = 48, this.showLevel = true});

  final Gem gem;
  final double size;
  final bool showLevel;

  @override
  Widget build(BuildContext context) {
    final badge = size * 0.36;
    return SizedBox.square(
      dimension: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          CustomPaint(size: Size.square(size), painter: _GemPainter(gem)),
          if (showLevel)
            Positioned(
              right: -badge * 0.15,
              bottom: -badge * 0.15,
              child: Container(
                width: badge,
                height: badge,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: GameColors.text,
                  border: Border.all(color: GameColors.outline, width: 1.5),
                ),
                child: Text(
                  '${gem.level}',
                  style: TextStyle(
                    color: GameColors.outline,
                    fontSize: badge * 0.62,
                    height: 1,
                    fontWeight: FontWeight.w900,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _GemPainter extends CustomPainter {
  _GemPainter(this.gem);
  final Gem gem;

  @override
  void paint(Canvas c, Size size) {
    final s = size.width;
    // Плашка с рамкой цвета редкости.
    final plate = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(s * 0.22));
    c.drawRRect(plate, Paint()..color = GameColors.outline);
    c.drawRRect(plate.deflate(s * 0.05), Paint()..color = GameColors.panelDark);
    c.drawRRect(
      plate.deflate(s * 0.09),
      Paint()
        ..color = gem.rarity.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.07,
    );

    // Сам камень: огранка «бриллиант».
    Offset p(double x, double y) => Offset(s * x, s * y);
    final stone = Path()
      ..moveTo(p(0.32, 0.24).dx, p(0.32, 0.24).dy)
      ..lineTo(p(0.68, 0.24).dx, p(0.68, 0.24).dy)
      ..lineTo(p(0.82, 0.42).dx, p(0.82, 0.42).dy)
      ..lineTo(p(0.5, 0.8).dx, p(0.5, 0.8).dy)
      ..lineTo(p(0.18, 0.42).dx, p(0.18, 0.42).dy)
      ..close();
    final color = gem.type.color;
    c.drawPath(
      stone,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color.lerp(color, Colors.white, 0.45)!, color, Color.lerp(color, Colors.black, 0.35)!],
        ).createShader(Offset.zero & size),
    );
    final facet = Paint()
      ..color = Color.lerp(color, Colors.black, 0.45)!.withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.025;
    c.drawLine(p(0.18, 0.42), p(0.82, 0.42), facet);
    c.drawPath(
      Path()
        ..moveTo(p(0.32, 0.24).dx, p(0.32, 0.24).dy)
        ..lineTo(p(0.4, 0.42).dx, p(0.4, 0.42).dy)
        ..lineTo(p(0.5, 0.8).dx, p(0.5, 0.8).dy)
        ..lineTo(p(0.6, 0.42).dx, p(0.6, 0.42).dy)
        ..lineTo(p(0.68, 0.24).dx, p(0.68, 0.24).dy),
      facet,
    );
    // Блик.
    c.drawLine(p(0.34, 0.3), p(0.44, 0.3), Paint()
      ..color = Colors.white.withValues(alpha: 0.85)
      ..strokeWidth = s * 0.045
      ..strokeCap = StrokeCap.round);
    c.drawPath(
      stone,
      Paint()
        ..color = GameColors.outline
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.045
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_GemPainter old) =>
      old.gem.type != gem.type || old.gem.rarity != gem.rarity;
}

/// Пустой или закрытый слот под гем.
class GemSlotBox extends StatelessWidget {
  const GemSlotBox({super.key, this.size = 48, this.lockedStar});

  final double size;

  /// Слот закрыт — на какой звезде откроется.
  final int? lockedStar;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: GameColors.panelDark,
        borderRadius: BorderRadius.circular(size * 0.22),
        border: Border.all(color: GameColors.outline, width: 2.5),
      ),
      child: lockedStar == null
          ? Icon(Icons.add_rounded, color: GameColors.textDim, size: size * 0.5)
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lock_rounded, color: GameColors.textDim, size: size * 0.34),
                Text(
                  '★$lockedStar',
                  style: TextStyle(
                    color: GameColors.gold,
                    fontSize: size * 0.22,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
              ],
            ),
    );
  }
}
