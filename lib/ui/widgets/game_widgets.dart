import 'dart:math';

import 'package:flutter/material.dart';

import '../theme.dart';

/// Фон: градиент + мелкая точечная текстура + виньетка.
class GameBackground extends StatelessWidget {
  const GameBackground({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [GameColors.bgTop, GameColors.bgBottom],
        ),
      ),
      child: CustomPaint(
        painter: _TexturePainter(),
        child: child,
      ),
    );
  }
}

class _TexturePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Ромбическая сетка из точек — читается как ткань/обои.
    final dot = Paint()..color = Colors.white.withValues(alpha: 0.045);
    const step = 22.0;
    for (var y = 0.0, row = 0; y < size.height; y += step, row++) {
      for (var x = row.isEven ? 0.0 : step / 2; x < size.width; x += step) {
        canvas.drawCircle(Offset(x, y), 1.6, dot);
      }
    }
    // Виньетка по краям.
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = RadialGradient(
          radius: 1.1,
          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.45)],
          stops: const [0.55, 1],
        ).createShader(Offset.zero & size),
    );
  }

  @override
  bool shouldRepaint(_TexturePainter old) => false;
}

/// Панель с толстой обводкой, внутренним бликом и тенью.
class GamePanel extends StatelessWidget {
  const GamePanel({
    super.key,
    required this.child,
    this.color = GameColors.panel,
    this.padding = const EdgeInsets.all(14),
    this.radius = 18,
    this.onTap,
  });

  final Widget child;
  final Color color;
  final EdgeInsets padding;
  final double radius;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(radius);
    final light = Color.lerp(color, Colors.white, 0.18)!;
    final dark = Color.lerp(color, Colors.black, 0.25)!;
    return Container(
      decoration: BoxDecoration(
        borderRadius: r,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [light, color, dark],
          stops: const [0, 0.35, 1],
        ),
        border: Border.all(color: GameColors.outline, width: 3),
        boxShadow: const [
          BoxShadow(color: Color(0x66000000), offset: Offset(0, 5), blurRadius: 6),
        ],
      ),
      // Внутренний блик по верхнему краю.
      foregroundDecoration: BoxDecoration(
        borderRadius: r,
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.22), width: 2),
        ),
      ),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: r,
        child: InkWell(
          onTap: onTap,
          borderRadius: r,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// Объёмная «мультяшная» кнопка: нижняя тёмная плита + верхняя крышка,
/// при нажатии крышка проседает.
class GameButton extends StatefulWidget {
  const GameButton({
    super.key,
    required this.child,
    this.onPressed,
    this.color = GameColors.gold,
    this.height = 46,
    this.minWidth = 0,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
  });

  final Widget child;
  final VoidCallback? onPressed;
  final Color color;
  final double height;
  final double minWidth;
  final EdgeInsets padding;

  @override
  State<GameButton> createState() => _GameButtonState();
}

class _GameButtonState extends State<GameButton> {
  bool _down = false;
  static const _lift = 5.0;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final color = enabled ? widget.color : const Color(0xFF6E6478);
    final light = Color.lerp(color, Colors.white, 0.35)!;
    final dark = Color.lerp(color, Colors.black, 0.45)!;
    final offset = _down && enabled ? _lift - 1 : 0.0;
    final r = BorderRadius.circular(14);

    return GestureDetector(
      onTapDown: enabled ? (_) => setState(() => _down = true) : null,
      onTapUp: enabled ? (_) => setState(() => _down = false) : null,
      onTapCancel: enabled ? () => setState(() => _down = false) : null,
      onTap: widget.onPressed,
      child: Stack(
        // passthrough: в Expanded кнопка растягивается, в Row — по содержимому.
        fit: StackFit.passthrough,
        children: [
          // Нижняя плита.
          Positioned.fill(
            top: _lift,
            child: Container(
              decoration: BoxDecoration(
                color: dark,
                borderRadius: r,
                border: Border.all(color: GameColors.outline, width: 3),
              ),
            ),
          ),
          // Крышка — именно она задаёт размер кнопки.
          Padding(
            padding: const EdgeInsets.only(bottom: _lift),
            child: AnimatedSlide(
              duration: const Duration(milliseconds: 60),
              offset: Offset(0, offset / widget.height),
              child: Container(
                height: widget.height,
                constraints: BoxConstraints(minWidth: widget.minWidth),
                padding: widget.padding,
                decoration: BoxDecoration(
                  borderRadius: r,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [light, color],
                  ),
                  border: Border.all(color: GameColors.outline, width: 3),
                ),
                child: DefaultTextStyle.merge(
                  style: TextStyle(
                    color: enabled ? GameColors.outline : const Color(0xFFB9B0C4),
                    fontVariations: const [FontVariation('wght', 900)],
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                  child: IconTheme.merge(
                    data: IconThemeData(
                      color: enabled ? GameColors.outline : const Color(0xFFB9B0C4),
                      size: 18,
                    ),
                    child: Center(widthFactor: 1, child: widget.child),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Текст с обводкой — для заголовков и цифр поверх графики.
class StrokeText extends StatelessWidget {
  const StrokeText(
    this.text, {
    super.key,
    this.size = 22,
    this.color = GameColors.text,
    this.stroke = GameColors.outline,
    this.strokeWidth = 4,
    this.weight = 900,
    this.align = TextAlign.center,
  });

  final String text;
  final double size;
  final Color color;
  final Color stroke;
  final double strokeWidth;
  final double weight;
  final TextAlign align;

  @override
  Widget build(BuildContext context) {
    final base = TextStyle(
      fontFamily: 'Nunito',
      fontSize: size,
      fontVariations: [FontVariation('wght', weight)],
      fontWeight: FontWeight.w900,
      height: 1.1,
    );
    return Stack(
      children: [
        Text(
          text,
          textAlign: align,
          style: base.copyWith(
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = strokeWidth
              ..strokeJoin = StrokeJoin.round
              ..color = stroke,
          ),
        ),
        Text(text, textAlign: align, style: base.copyWith(color: color)),
      ],
    );
  }
}

/// Полоса (HP, прогресс) с обводкой и бликом.
class GameBar extends StatelessWidget {
  const GameBar({
    super.key,
    required this.value,
    this.color = GameColors.green,
    this.height = 18,
    this.label,
    this.alignEnd = false,
  });

  final double value;
  final Color color;
  final double height;
  final String? label;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(height / 2);
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: GameColors.panelDark,
        borderRadius: r,
        border: Border.all(color: GameColors.outline, width: 2.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedFractionallySizedBox(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
            alignment: alignEnd ? Alignment.centerRight : Alignment.centerLeft,
            widthFactor: value.clamp(0.0, 1.0),
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color.lerp(color, Colors.white, 0.35)!,
                    color,
                    Color.lerp(color, Colors.black, 0.25)!,
                  ],
                  stops: const [0, 0.45, 1],
                ),
              ),
            ),
          ),
          if (label != null)
            Center(
              child: StrokeText(label!, size: height * 0.62, strokeWidth: 2.5),
            ),
        ],
      ),
    );
  }
}

/// Золотая монетка.
class CoinIcon extends StatelessWidget {
  const CoinIcon({super.key, this.size = 22});
  final double size;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: _CoinPainter());
}

class _CoinPainter extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    final r = s.width / 2;
    final center = Offset(r, r);
    c.drawCircle(center, r, Paint()..color = GameColors.outline);
    c.drawCircle(
      center,
      r - 1.5,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.3, -0.4),
          colors: [GameColors.goldLight, GameColors.gold, GameColors.goldDark],
          stops: [0, 0.55, 1],
        ).createShader(Rect.fromCircle(center: center, radius: r)),
    );
    c.drawCircle(
      center,
      r * 0.62,
      Paint()
        ..color = GameColors.goldDark.withValues(alpha: 0.7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.14,
    );
    // Звёздочка в центре.
    final star = Path();
    for (var i = 0; i < 10; i++) {
      final a = -pi / 2 + i * pi / 5;
      final rad = i.isEven ? r * 0.42 : r * 0.18;
      final p = center + Offset(cos(a), sin(a)) * rad;
      i == 0 ? star.moveTo(p.dx, p.dy) : star.lineTo(p.dx, p.dy);
    }
    star.close();
    c.drawPath(star, Paint()..color = GameColors.goldDark);
  }

  @override
  bool shouldRepaint(_CoinPainter old) => false;
}

/// Фон боя: арт арены под затемнением, чтобы текст поверх читался.
class ArenaBackground extends StatelessWidget {
  const ArenaBackground({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: GameColors.bgBottom,
        image: DecorationImage(
          image: AssetImage('assets/ui/arena_bg.jpg'),
          fit: BoxFit.cover,
        ),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              GameColors.bgBottom.withValues(alpha: 0.82),
              GameColors.bgBottom.withValues(alpha: 0.25),
              GameColors.bgBottom.withValues(alpha: 0.88),
            ],
            stops: const [0, 0.45, 1],
          ),
        ),
        child: child,
      ),
    );
  }
}

/// Катушка ниток — основная валюта.
class ThreadIcon extends StatelessWidget {
  const ThreadIcon({super.key, this.size = 22});
  final double size;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: _ThreadPainter());
}

class _ThreadPainter extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    final w = s.width;
    final h = s.height;
    final outline = Paint()
      ..color = GameColors.outline
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.09
      ..strokeCap = StrokeCap.round;

    // Тело катушки — намотанная нить.
    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.22, h * 0.14, w * 0.56, h * 0.72),
      Radius.circular(w * 0.14),
    );
    c.drawRRect(body, Paint()..color = GameColors.thread);
    c.save();
    c.clipRRect(body);
    c.drawRect(
      Rect.fromLTWH(w * 0.22, h * 0.14, w * 0.16, h * 0.72),
      Paint()..color = GameColors.threadLight,
    );
    c.drawRect(
      Rect.fromLTWH(w * 0.62, h * 0.14, w * 0.18, h * 0.72),
      Paint()..color = GameColors.threadDark,
    );
    // Витки нити.
    final winding = Paint()
      ..color = GameColors.threadDark.withValues(alpha: 0.65)
      ..strokeWidth = w * 0.05;
    for (var i = 1; i < 5; i++) {
      final y = h * (0.14 + 0.72 * i / 5);
      c.drawLine(Offset(w * 0.22, y), Offset(w * 0.78, y + h * 0.05), winding);
    }
    c.restore();

    // Фланцы сверху и снизу.
    for (final y in [h * 0.06, h * 0.78]) {
      final flange = RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.12, y, w * 0.76, h * 0.16),
        Radius.circular(w * 0.07),
      );
      c.drawRRect(flange, Paint()..color = GameColors.threadLight);
      c.drawRRect(flange, outline);
    }

    // Свободный кончик нити.
    c.drawPath(
      Path()
        ..moveTo(w * 0.78, h * 0.35)
        ..quadraticBezierTo(w * 1.02, h * 0.42, w * 0.9, h * 0.62),
      Paint()
        ..color = GameColors.thread
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.08
        ..strokeCap = StrokeCap.round,
    );
    c.drawRRect(body, outline);
  }

  @override
  bool shouldRepaint(_ThreadPainter old) => false;
}

/// Коврик под тапком.
class Rug extends StatelessWidget {
  const Rug({super.key, required this.width, this.aspect = 0.34});
  final double width;
  final double aspect;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size(width, width * aspect), painter: _RugPainter());
}

/// Ковёр в восточном стиле: кайма с узором, медальон и ромбы по полю.
class _RugPainter extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    // Бахрома торчит за края ковра, поэтому полотно чуть уже.
    const fringe = 10.0;
    final rect = Rect.fromLTRB(fringe, 4, s.width - fringe, s.height - 4);
    final rr = RRect.fromRectAndRadius(rect, const Radius.circular(10));
    final outline = Paint()
      ..color = GameColors.outline
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    _drawFringe(c, rect, fringe);

    // Тень и основа.
    c.drawRRect(rr.shift(const Offset(0, 5)), Paint()..color = const Color(0x55000000));
    c.drawRRect(rr, Paint()..color = GameColors.rug);

    c.save();
    c.clipRRect(rr);
    _drawBorder(c, rect);
    final field = rect.deflate(rect.height * 0.17);
    c.drawRRect(
      RRect.fromRectAndRadius(field, const Radius.circular(6)),
      Paint()..color = GameColors.rugDark,
    );
    _drawField(c, field);
    // Общее затемнение к низу — ковёр не выглядит плоской заливкой.
    c.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.white.withValues(alpha: 0.06), Colors.black.withValues(alpha: 0.22)],
        ).createShader(rect),
    );
    c.restore();
    c.drawRRect(rr, outline);
  }

  /// Кайма: синяя полоса с «зубчиками» и кремовой ниткой.
  void _drawBorder(Canvas c, Rect rect) {
    final band = rect.height * 0.17;
    c.drawRRect(
      RRect.fromRectAndRadius(rect.deflate(band * 0.45), const Radius.circular(8)),
      Paint()
        ..color = GameColors.rugBorder
        ..style = PaintingStyle.stroke
        ..strokeWidth = band * 0.9,
    );
    // Зубчики по кайме.
    final tooth = Paint()..color = GameColors.rugStripe;
    final step = band * 1.15;
    for (var x = rect.left + step * 0.6; x < rect.right - step * 0.3; x += step) {
      for (final y in [rect.top + band * 0.45, rect.bottom - band * 0.45]) {
        c.drawPath(
          Path()
            ..moveTo(x, y - band * 0.26)
            ..lineTo(x + band * 0.3, y)
            ..lineTo(x, y + band * 0.26)
            ..lineTo(x - band * 0.3, y)
            ..close(),
          tooth,
        );
      }
    }
    // Тонкая кремовая нитка по внутреннему краю.
    c.drawRRect(
      RRect.fromRectAndRadius(rect.deflate(band), const Radius.circular(6)),
      Paint()
        ..color = GameColors.rugCream
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  /// Поле: центральный медальон и ряд ромбов по бокам.
  void _drawField(Canvas c, Rect field) {
    final cx = field.center.dx;
    final cy = field.center.dy;
    final r = field.height * 0.42;

    // Медальон — вложенные ромбы.
    _diamond(c, Offset(cx, cy), r * 2.1, r, GameColors.rugTeal);
    _diamond(c, Offset(cx, cy), r * 1.5, r * 0.72, GameColors.rugStripe);
    _diamond(c, Offset(cx, cy), r * 0.85, r * 0.42, GameColors.rugCream);
    // Лучи медальона.
    final ray = Paint()
      ..color = GameColors.rugCream
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    for (final d in const [Offset(-1, 0), Offset(1, 0)]) {
      c.drawLine(
        Offset(cx + d.dx * r * 1.1, cy),
        Offset(cx + d.dx * r * 1.9, cy),
        ray,
      );
    }

    // Ромбики по бокам, пока влезают.
    final gap = r * 1.5;
    for (var x = cx - r * 2.6; x > field.left + r * 0.5; x -= gap) {
      _sideMotif(c, Offset(x, cy), r);
    }
    for (var x = cx + r * 2.6; x < field.right - r * 0.5; x += gap) {
      _sideMotif(c, Offset(x, cy), r);
    }
  }

  void _sideMotif(Canvas c, Offset o, double r) {
    _diamond(c, o, r * 0.9, r * 0.55, GameColors.rugStripe);
    _diamond(c, o, r * 0.45, r * 0.28, GameColors.rugTeal);
  }

  void _diamond(Canvas c, Offset o, double w, double h, Color color) {
    c.drawPath(
      Path()
        ..moveTo(o.dx, o.dy - h)
        ..lineTo(o.dx + w / 2, o.dy)
        ..lineTo(o.dx, o.dy + h)
        ..lineTo(o.dx - w / 2, o.dy)
        ..close(),
      Paint()..color = color,
    );
  }

  void _drawFringe(Canvas c, Rect rect, double len) {
    final paint = Paint()
      ..color = GameColors.rugCream
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    final shade = Paint()
      ..color = GameColors.outline
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    for (var y = rect.top + 8; y < rect.bottom - 4; y += 9) {
      for (final (x, dir) in [(rect.left, -1.0), (rect.right, 1.0)]) {
        final end = Offset(x + dir * len, y + 2);
        c.drawLine(Offset(x, y), end, shade);
        c.drawLine(Offset(x, y), end, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_RugPainter old) => false;
}

/// Цветная плашка-ярлык («Разминка», «ур. 5»).
class GameBadge extends StatelessWidget {
  const GameBadge({super.key, required this.text, this.color = GameColors.blue});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: GameColors.outline, width: 2),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: GameColors.outline,
          fontSize: 12,
          fontVariations: [FontVariation('wght', 900)],
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}
