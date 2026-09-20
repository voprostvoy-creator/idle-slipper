import 'dart:math';

import 'package:flutter/material.dart';

import '../game/slipper.dart';

/// Выражение «лица» тапка.
enum SlipperMood { idle, attack, hurt, happy, dead }

/// Палитра тапка, выведенная из одного оттенка.
class SlipperPalette {
  SlipperPalette(int hue)
      : body = HSLColor.fromAHSL(1, hue.toDouble(), 0.6, 0.52).toColor(),
        bodyDark = HSLColor.fromAHSL(1, hue.toDouble(), 0.55, 0.36).toColor(),
        bodyLight = HSLColor.fromAHSL(1, hue.toDouble(), 0.65, 0.66).toColor(),
        insole = HSLColor.fromAHSL(1, (hue + 15) % 360.0, 0.35, 0.72).toColor(),
        insoleDark = HSLColor.fromAHSL(1, (hue + 15) % 360.0, 0.35, 0.6).toColor(),
        sole = HSLColor.fromAHSL(1, (hue + 10) % 360.0, 0.3, 0.22).toColor(),
        fur = HSLColor.fromAHSL(1, (hue + 30) % 360.0, 0.3, 0.9).toColor(),
        outline = HSLColor.fromAHSL(1, hue.toDouble(), 0.4, 0.12).toColor();

  final Color body;
  final Color bodyDark;
  final Color bodyLight;
  final Color insole;
  final Color insoleDark;
  final Color sole;
  final Color fur;
  final Color outline;
}

/// Рисует тапок в боксе 200×120 (логических единиц), масштабируя под size.
/// Вид сверху-сбоку, носок вправо; [flip] зеркалит для соперника.
class SlipperPainter extends CustomPainter {
  SlipperPainter({
    required this.slipper,
    this.mood = SlipperMood.idle,
    this.flip = false,
  }) : palette = SlipperPalette(slipper.colorSeed);

  final Slipper slipper;
  final SlipperMood mood;
  final bool flip;
  final SlipperPalette palette;

  static const double baseW = 200;
  static const double baseH = 120;

  /// Толщина подошвы (видимый «бортик» снизу).
  static const double _soleDepth = 9;

  /// Где начинается закрытый носок (по X) и насколько вырез вогнут.
  static const double _vampX = 96;
  static const double _vampCurve = 46;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = min(size.width / baseW, size.height / baseH);
    canvas.save();
    canvas.translate(
      (size.width - baseW * scale) / 2,
      (size.height - baseH * scale) / 2,
    );
    canvas.scale(scale);
    if (flip) {
      canvas.translate(baseW, 0);
      canvas.scale(-1, 1);
    }
    // Запас по краям под шипы и полосы скорости.
    canvas.translate(baseW * 0.07, baseH * 0.05);
    canvas.scale(0.86, 0.9);

    _drawShadow(canvas);
    _drawSpeedTrails(canvas);
    _drawSole(canvas);
    _drawInsole(canvas);
    _drawPatches(canvas);
    _drawVamp(canvas);
    _drawPlates(canvas);
    _drawFur(canvas);
    _drawSpikes(canvas);
    _drawFace(canvas);

    canvas.restore();
  }

  Paint get _outline => Paint()
    ..color = palette.outline
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3
    ..strokeJoin = StrokeJoin.round;

  // --- Геометрия -------------------------------------------------------

  /// Контур «следа»: пятка слева, носок справа.
  static Path _footprint() => Path()
    ..moveTo(14, 38)
    ..cubicTo(45, 24, 110, 18, 150, 20)
    ..cubicTo(186, 22, 199, 44, 197, 60)
    ..cubicTo(195, 80, 182, 96, 150, 96)
    ..cubicTo(110, 96, 45, 88, 14, 78)
    ..cubicTo(0, 72, 0, 44, 14, 38)
    ..close();

  /// Область носка: всё правее вогнутой линии выреза, пересечённое со следом.
  static Path _vampRegion({double shift = 0}) {
    final x = _vampX + shift;
    final region = Path()
      ..moveTo(x, -10)
      ..lineTo(260, -10)
      ..lineTo(260, 130)
      ..lineTo(x, 130)
      ..cubicTo(x + _vampCurve, 100, x + _vampCurve, 20, x, -10)
      ..close();
    return Path.combine(PathOperation.intersect, _footprint(), region);
  }

  /// Точка на кривой выреза при t∈[0,1] (сверху вниз).
  static Offset _openingPoint(double t, {double shift = 0}) {
    final x = _vampX + shift;
    return _cubic(Offset(x, -10), Offset(x + _vampCurve, 20),
        Offset(x + _vampCurve, 100), Offset(x, 130), t);
  }

  // --- Части тапка -----------------------------------------------------

  void _drawShadow(Canvas c) {
    c.drawOval(
      const Rect.fromLTWH(6, 62, 192, 52),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.28)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
  }

  void _drawSole(Canvas c) {
    final depth = _soleDepth + _tier(slipper.level(Stat.defense), maxTier: 3) * 2;
    final fp = _footprint();
    // Бортик подошвы — тот же контур, сдвинутый вниз.
    c.save();
    c.translate(0, depth);
    c.drawPath(fp, Paint()..color = palette.sole);
    c.drawPath(fp, _outline);
    c.restore();
    // Рифление на бортике — только в полосе между стелькой и низом подошвы.
    final band = Path.combine(
      PathOperation.difference,
      fp.shift(Offset(0, depth)),
      fp,
    );
    c.save();
    c.clipPath(band);
    final groove = Paint()
      ..color = Colors.black.withValues(alpha: 0.35)
      ..strokeWidth = 2;
    for (var x = 30.0; x < 190; x += 14) {
      c.drawLine(Offset(x, 60), Offset(x - 3, 96 + depth), groove);
    }
    c.restore();
  }

  void _drawInsole(Canvas c) {
    final fp = _footprint();
    c.drawPath(fp, Paint()..color = palette.insole);
    // Тень от носка, падающая внутрь.
    c.save();
    c.clipPath(fp);
    c.drawPath(
      _vampRegion(shift: -14),
      Paint()..color = palette.insoleDark,
    );
    c.restore();
    // Строчка по краю стельки.
    c.save();
    c.clipPath(fp);
    final stitch = Paint()
      ..color = palette.outline.withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    _drawDashed(c, _inset(fp, 6), stitch, dash: 5, gap: 4);
    c.restore();
    c.drawPath(fp, _outline);
  }

  void _drawVamp(Canvas c) {
    final vamp = _vampRegion();
    c.drawPath(
      vamp,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [palette.bodyLight, palette.body, palette.bodyDark],
          stops: const [0, 0.5, 1],
        ).createShader(const Rect.fromLTWH(90, 18, 110, 80)),
    );
    // Блик на носке.
    c.save();
    c.clipPath(vamp);
    c.drawOval(
      const Rect.fromLTWH(140, 26, 44, 18),
      Paint()..color = Colors.white.withValues(alpha: 0.22),
    );
    c.restore();
    c.drawPath(vamp, _outline);
  }

  /// Меховая опушка по краю выреза.
  void _drawFur(Canvas c) {
    final fill = Paint()..color = palette.fur;
    final shade = Paint()..color = palette.fur.withValues(alpha: 0.6);
    for (var i = 0; i <= 8; i++) {
      final t = 0.2 + i * (0.6 / 8);
      final p = _openingPoint(t);
      final r = 5.5 + (i.isEven ? 1.2 : 0);
      c.drawCircle(p + const Offset(2, 1), r, shade);
      c.drawCircle(p, r, fill);
      c.drawCircle(p, r, _outline..strokeWidth = 2);
    }
  }

  // --- Детали от прокачки ----------------------------------------------

  static int _tier(int level, {int per = 5, int maxTier = 6}) =>
      min(maxTier, level ~/ per);

  /// Удар: шипы вокруг носка, торчат наружу.
  void _drawSpikes(Canvas c) {
    final n = _tier(slipper.level(Stat.attack));
    if (n == 0) return;
    final fill = Paint()..color = const Color(0xFFE6E9EE);
    final shade = Paint()..color = const Color(0xFF9AA3B0);
    // Дуга носка: верхняя и нижняя кубики контура.
    const top = (Offset(150, 20), Offset(186, 22), Offset(199, 44), Offset(197, 60));
    const bottom = (Offset(197, 60), Offset(195, 80), Offset(182, 96), Offset(150, 96));
    final len = 12.0 + min(3, n) * 2;
    for (var i = 0; i < n; i++) {
      // Распределяем шипы по дуге от верха носка до низа.
      final u = n == 1 ? 0.5 : i / (n - 1);
      final (p, d) = u < 0.5
          ? (
              _cubic(top.$1, top.$2, top.$3, top.$4, 0.35 + u * 2 * 0.65),
              _cubicTangent(top.$1, top.$2, top.$3, top.$4, 0.35 + u * 2 * 0.65),
            )
          : (
              _cubic(bottom.$1, bottom.$2, bottom.$3, bottom.$4, (u - 0.5) * 2 * 0.65),
              _cubicTangent(bottom.$1, bottom.$2, bottom.$3, bottom.$4, (u - 0.5) * 2 * 0.65),
            );
      final tangent = d / d.distance;
      final normal = Offset(tangent.dy, -tangent.dx);
      final tip = p + normal * len;
      final a = p - tangent * 5;
      final b = p + tangent * 5;
      final spike = Path()..moveTo(a.dx, a.dy)..lineTo(tip.dx, tip.dy)..lineTo(b.dx, b.dy)..close();
      final half = Path()..moveTo(p.dx, p.dy)..lineTo(tip.dx, tip.dy)..lineTo(b.dx, b.dy)..close();
      c.drawPath(spike, fill);
      c.drawPath(half, shade);
      c.drawPath(spike, _outline..strokeWidth = 2);
    }
  }

  /// Подошва: броневые пластины на носке (толщина подошвы растёт отдельно).
  void _drawPlates(Canvas c) {
    final n = _tier(slipper.level(Stat.defense));
    if (n == 0) return;
    final plate = Paint()..color = const Color(0xFFB0B8C4);
    final plateDark = Paint()..color = const Color(0xFF7E8794);
    final rivet = Paint()..color = const Color(0xFF3A3F47);
    const spots = [
      Offset(178, 58), Offset(160, 84), Offset(160, 32),
      Offset(132, 88), Offset(132, 28), Offset(120, 58),
    ];
    c.save();
    c.clipPath(_vampRegion());
    for (var i = 0; i < n; i++) {
      final o = spots[i];
      final r = RRect.fromRectAndRadius(
        Rect.fromCenter(center: o, width: 22, height: 18),
        const Radius.circular(4),
      );
      c.drawRRect(r.shift(const Offset(0, 3)), plateDark);
      c.drawRRect(r, plate);
      c.drawRRect(r, _outline..strokeWidth = 2);
      for (final d in const [Offset(-7, -5), Offset(7, -5), Offset(-7, 5), Offset(7, 5)]) {
        c.drawCircle(o + d, 1.8, rivet);
      }
    }
    c.restore();
  }

  /// Прочность: заплатки на стельке у пятки.
  void _drawPatches(Canvas c) {
    final n = _tier(slipper.level(Stat.health), maxTier: 3);
    if (n == 0) return;
    final patch = Paint()..color = palette.bodyDark;
    final stitch = Paint()
      ..color = const Color(0xFFF5F5DC)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    const spots = [Offset(40, 58), Offset(70, 40), Offset(68, 78)];
    c.save();
    c.clipPath(_footprint());
    for (var i = 0; i < n; i++) {
      final o = spots[i];
      c.save();
      c.translate(o.dx, o.dy);
      c.rotate(-0.4 + i * 0.5);
      final r = RRect.fromRectAndRadius(
        const Rect.fromLTWH(-11, -8, 22, 16),
        const Radius.circular(3),
      );
      c.drawRRect(r, patch);
      c.drawRRect(r, _outline..strokeWidth = 2);
      for (var k = -7; k <= 7; k += 5) {
        c.drawLine(Offset(k.toDouble(), -9), Offset(k + 2.0, -6), stitch);
        c.drawLine(Offset(k.toDouble(), 9), Offset(k + 2.0, 6), stitch);
      }
      c.restore();
    }
    c.restore();
  }

  /// Скорость: полосы движения за пяткой.
  void _drawSpeedTrails(Canvas c) {
    final n = _tier(slipper.level(Stat.speed), maxTier: 3);
    if (n == 0) return;
    final paint = Paint()
      ..color = palette.bodyLight
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    final shade = Paint()
      ..color = palette.outline
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < n; i++) {
      final y = 46.0 + i * 14;
      final len = 30.0 - i * 6;
      c.drawLine(Offset(4 - len, y), Offset(6, y), shade);
      c.drawLine(Offset(4 - len, y), Offset(6, y), paint);
    }
  }

  // --- Лицо ------------------------------------------------------------

  void _drawFace(Canvas c) {
    // Глаза на носке, «смотрят» вправо — в сторону соперника.
    const eyes = [Offset(152, 44), Offset(152, 72)];
    final white = Paint()..color = Colors.white;
    final black = Paint()..color = const Color(0xFF1B1B1B);
    final stroke = Paint()
      ..color = const Color(0xFF1B1B1B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    switch (mood) {
      case SlipperMood.dead:
        for (final e in eyes) {
          c.drawLine(e + const Offset(-6, -6), e + const Offset(6, 6), stroke);
          c.drawLine(e + const Offset(-6, 6), e + const Offset(6, -6), stroke);
        }
      case SlipperMood.hurt:
        for (final e in eyes) {
          c.drawLine(e + const Offset(-7, 0), e + const Offset(7, 0), stroke);
        }
      case SlipperMood.happy:
        for (final e in eyes) {
          c.drawArc(Rect.fromCircle(center: e, radius: 7), pi, pi, false, stroke);
        }
      case SlipperMood.idle:
      case SlipperMood.attack:
        for (final e in eyes) {
          c.drawCircle(e, 8.5, white);
          c.drawCircle(e, 8.5, stroke);
          c.drawCircle(e + const Offset(3, 0), 3.8, black);
          c.drawCircle(e + const Offset(4.5, -1.5), 1.2, white);
        }
        if (mood == SlipperMood.attack) {
          // Злые брови — сходятся к носку.
          c.drawLine(const Offset(140, 30), const Offset(158, 36), stroke);
          c.drawLine(const Offset(140, 86), const Offset(158, 80), stroke);
        }
    }
  }

  // --- Утилиты ---------------------------------------------------------

  static Offset _cubic(Offset p0, Offset p1, Offset p2, Offset p3, double t) {
    final u = 1 - t;
    return p0 * (u * u * u) + p1 * (3 * u * u * t) + p2 * (3 * u * t * t) + p3 * (t * t * t);
  }

  static Offset _cubicTangent(Offset p0, Offset p1, Offset p2, Offset p3, double t) {
    final u = 1 - t;
    return (p1 - p0) * (3 * u * u) + (p2 - p1) * (6 * u * t) + (p3 - p2) * (3 * t * t);
  }

  /// Уменьшенная копия контура вокруг его центра — для внутренней строчки.
  static Path _inset(Path p, double by) {
    final b = p.getBounds();
    final sx = (b.width - by * 2) / b.width;
    final sy = (b.height - by * 2) / b.height;
    return p.transform((Matrix4.identity()
          ..translateByDouble(b.center.dx, b.center.dy, 0, 1)
          ..scaleByDouble(sx, sy, 1, 1)
          ..translateByDouble(-b.center.dx, -b.center.dy, 0, 1))
        .storage);
  }

  static void _drawDashed(Canvas c, Path p, Paint paint,
      {required double dash, required double gap}) {
    for (final m in p.computeMetrics()) {
      var d = 0.0;
      while (d < m.length) {
        c.drawPath(m.extractPath(d, min(d + dash, m.length)), paint);
        d += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(SlipperPainter old) =>
      old.slipper != slipper || old.mood != mood || old.flip != flip;
}

/// Виджет-обёртка с лёгким «дыханием» в покое.
class SlipperView extends StatefulWidget {
  const SlipperView({
    super.key,
    required this.slipper,
    this.mood = SlipperMood.idle,
    this.flip = false,
    this.animate = true,
    this.width = 200,
  });

  final Slipper slipper;
  final SlipperMood mood;
  final bool flip;
  final bool animate;
  final double width;

  @override
  State<SlipperView> createState() => _SlipperViewState();
}

class _SlipperViewState extends State<SlipperView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final height = widget.width * SlipperPainter.baseH / SlipperPainter.baseW;
    final painter = CustomPaint(
      size: Size(widget.width, height),
      painter: SlipperPainter(
        slipper: widget.slipper,
        mood: widget.mood,
        flip: widget.flip,
      ),
    );
    if (!widget.animate) return painter;
    return AnimatedBuilder(
      animation: _c,
      builder: (_, child) {
        final t = Curves.easeInOut.transform(_c.value);
        return Transform.translate(
          offset: Offset(0, -3 * t),
          child: Transform.scale(
            scaleY: 1 - 0.02 * t,
            alignment: Alignment.bottomCenter,
            child: child,
          ),
        );
      },
      child: painter,
    );
  }
}
