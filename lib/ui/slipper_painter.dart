import 'dart:math';

import 'package:flutter/material.dart';

import '../game/slipper.dart';

/// Выражение «лица» тапка.
enum SlipperMood { idle, attack, hurt, happy, dead }

/// Палитра тапка, выведенная из одного оттенка.
class SlipperPalette {
  SlipperPalette(int hue)
      : body = HSLColor.fromAHSL(1, hue.toDouble(), 0.72, 0.5).toColor(),
        bodyDark = HSLColor.fromAHSL(1, hue.toDouble(), 0.65, 0.34).toColor(),
        bodyLight = HSLColor.fromAHSL(1, hue.toDouble(), 0.75, 0.66).toColor(),
        accent = HSLColor.fromAHSL(1, (hue + 40) % 360.0, 0.8, 0.6).toColor(),
        heel = HSLColor.fromAHSL(1, hue.toDouble(), 0.5, 0.28).toColor();

  final Color body;
  final Color bodyDark;
  final Color bodyLight;

  /// Контрастная полоса на носке.
  final Color accent;

  /// Задник (пяточная часть) — темнее корпуса.
  final Color heel;

  static const cream = Color(0xFFF4EAD3);
  static const creamDark = Color(0xFFD9CBAA);
  static const outsole = Color(0xFF2C2433);
  static const outsoleLight = Color(0xFF4A3F55);
  static const fur = Color(0xFFFBF6EA);
  static const furShade = Color(0xFFD8CDB4);
  static const outline = Color(0xFF17111D);
  static const metal = Color(0xFFD7DCE3);
  static const metalDark = Color(0xFF8C95A3);
}

/// Рисует тапок в боксе 200×130 (логических единиц), масштабируя под size.
/// Вид сбоку, носок вправо; [flip] зеркалит для соперника.
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
  static const double baseH = 130;

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
    // Запас по краям под шипы и пламя.
    canvas.translate(baseW * 0.09, baseH * 0.06);
    canvas.scale(0.82, 0.88);

    _drawShadow(canvas);
    _drawFlames(canvas);
    _drawSole(canvas);
    _drawFootbed(canvas);
    _drawVamp(canvas);
    _drawOpening(canvas);
    _drawPatches(canvas);
    _drawPlates(canvas);
    _drawSpikes(canvas);
    _drawFace(canvas);

    canvas.restore();
  }

  static Paint _stroke([double w = 4]) => Paint()
    ..color = SlipperPalette.outline
    ..style = PaintingStyle.stroke
    ..strokeWidth = w
    ..strokeJoin = StrokeJoin.round
    ..strokeCap = StrokeCap.round;

  static int _tier(int level, {int per = 5, int maxTier = 6}) =>
      min(maxTier, level ~/ per);

  // --- Геометрия -------------------------------------------------------

  /// Промежуточная подошва (светлая платформа); [raise] делает её выше.
  static Path _midsole(double raise) => Path()
    ..moveTo(8, 88 - raise)
    ..cubicTo(60, 86 - raise, 130, 84 - raise, 162, 84 - raise)
    ..cubicTo(190, 84 - raise, 201, 90 - raise, 200, 100 - raise)
    ..lineTo(200, 106)
    ..lineTo(8, 106)
    ..quadraticBezierTo(1, 106, 1, 97)
    ..quadraticBezierTo(1, 88 - raise, 8, 88 - raise)
    ..close();

  /// Подмётка с протектором: плита + «лаги» снизу.
  static Path _outsole() {
    var p = Path()
      ..addRRect(RRect.fromRectAndRadius(
        const Rect.fromLTRB(1, 103, 200, 114),
        const Radius.circular(5),
      ));
    for (var x = 8.0; x < 192; x += 17) {
      p = Path.combine(
        PathOperation.union,
        p,
        Path()
          ..addRRect(RRect.fromRectAndRadius(
            Rect.fromLTWH(x, 110, 11, 9),
            const Radius.circular(3),
          )),
      );
    }
    return p;
  }

  /// Верх — большая пухлая «шапка» закрытого носка, пятка открыта.
  static Path _vamp() => Path()
    ..moveTo(54, 90)
    ..cubicTo(50, 52, 78, 22, 120, 22)
    ..cubicTo(160, 22, 190, 42, 197, 70)
    ..cubicTo(200, 80, 199, 88, 197, 90)
    ..close();

  /// Вырез под ногу на задней грани шапки — тёмный наклонный овал.
  static const _openingCenter = Offset(78, 56);
  static const _openingRadii = Size(12, 24);
  static const _openingTilt = -0.28;

  /// Мысок — светлая накладка на носке.
  static Path _toeCap() => Path.combine(
        PathOperation.intersect,
        _vamp(),
        Path()
          ..moveTo(166, 20)
          ..lineTo(220, 20)
          ..lineTo(220, 100)
          ..lineTo(176, 100)
          ..cubicTo(160, 80, 160, 40, 166, 20)
          ..close(),
      );


  // --- Части тапка -----------------------------------------------------

  void _drawShadow(Canvas c) {
    c.drawOval(
      const Rect.fromLTWH(-4, 104, 214, 26),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
  }

  void _drawSole(Canvas c) {
    final defTier = _tier(slipper.level(Stat.defense), maxTier: 3);
    final out = _outsole();
    final raise = defTier * 4.0;
    final mid = _midsole(raise);

    // Подмётка.
    c.drawPath(out, Paint()..color = SlipperPalette.outsole);
    c.save();
    c.clipPath(out);
    c.drawRect(const Rect.fromLTRB(0, 103, 200, 107), Paint()..color = SlipperPalette.outsoleLight);
    c.restore();
    c.drawPath(out, _stroke());

    // Платформа, у прокачанной подошвы — выше.
    c.drawPath(mid, Paint()..color = SlipperPalette.cream);
    c.save();
    c.clipPath(mid);
    // Тень под верхом.
    c.drawRect(Rect.fromLTRB(0, 84 - raise, 200, 91 - raise), Paint()..color = SlipperPalette.creamDark);
    // Светящиеся вставки от скорости.
    final spdTier = _tier(slipper.level(Stat.speed), maxTier: 3);
    if (spdTier >= 2) {
      final glow = Paint()..color = const Color(0xFF4FE3FF);
      for (var x = 30.0; x < 180; x += 40) {
        c.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(x, 94, 24, 6), const Radius.circular(3)),
          glow,
        );
      }
    }
    c.restore();
    c.drawPath(mid, _stroke());
  }

  /// Открытая пятка: виден край стельки.
  void _drawFootbed(Canvas c) {
    final raise = _tier(slipper.level(Stat.defense), maxTier: 3) * 4.0;
    final bed = Path()
      ..addOval(Rect.fromLTRB(4, 80 - raise, 96, 94 - raise));
    c.save();
    c.clipRect(const Rect.fromLTRB(0, 0, 70, 200));
    c.drawPath(bed, Paint()..color = SlipperPalette.creamDark);
    c.drawPath(bed, _stroke(3));
    c.restore();
  }

  /// Вырез: тёмный овал с меховым ободком.
  void _drawOpening(Canvas c) {
    c.save();
    c.translate(_openingCenter.dx, _openingCenter.dy);
    c.rotate(_openingTilt);
    final rect = Rect.fromCenter(
      center: Offset.zero,
      width: _openingRadii.width * 2,
      height: _openingRadii.height * 2,
    );
    c.drawOval(rect, Paint()..color = SlipperPalette.outline.withValues(alpha: 0.9));
    // Меховой ободок — кольцо из кружков.
    final fill = Paint()..color = SlipperPalette.fur;
    final shade = Paint()..color = SlipperPalette.furShade;
    const n = 11;
    for (var i = 0; i < n; i++) {
      final a = -pi / 2 + i * 2 * pi / n;
      final p = Offset(
        cos(a) * (_openingRadii.width + 2),
        sin(a) * (_openingRadii.height + 1),
      );
      final r = 6.0 + (i.isEven ? 1.5 : 0);
      c.drawCircle(p + const Offset(1.5, 2), r, shade);
      c.drawCircle(p, r, fill);
      c.drawCircle(p, r, _stroke(3));
    }
    c.restore();
  }

  void _drawVamp(Canvas c) {
    final vamp = _vamp();
    c.drawPath(vamp, Paint()..color = palette.body);
    c.save();
    c.clipPath(vamp);
    // Тень у подошвы.
    c.drawRect(const Rect.fromLTRB(0, 74, 200, 92), Paint()..color = palette.bodyDark);
    // Блик по верху.
    c.drawPath(
      Path()
        ..moveTo(84, 36)
        ..cubicTo(100, 26, 134, 22, 166, 32)
        ..lineTo(164, 40)
        ..cubicTo(134, 30, 104, 34, 88, 44)
        ..close(),
      Paint()..color = Colors.white.withValues(alpha: 0.28),
    );
    // Контрастная косая полоса.
    c.drawPath(
      Path()
        ..moveTo(100, 24)
        ..lineTo(116, 22)
        ..lineTo(152, 92)
        ..lineTo(134, 92)
        ..close(),
      Paint()..color = palette.accent,
    );
    c.drawPath(
      Path()
        ..moveTo(100, 24)
        ..lineTo(116, 22)
        ..lineTo(152, 92)
        ..lineTo(134, 92)
        ..close(),
      _stroke(3),
    );
    c.restore();

    // Мысок: тканевый или металлический (Подошва 10+).
    final cap = _toeCap();
    final metalCap = _tier(slipper.level(Stat.defense)) >= 2;
    c.drawPath(cap, Paint()..color = metalCap ? SlipperPalette.metal : SlipperPalette.cream);
    c.save();
    c.clipPath(cap);
    c.drawRect(
      const Rect.fromLTRB(0, 74, 200, 92),
      Paint()..color = metalCap ? SlipperPalette.metalDark : SlipperPalette.creamDark,
    );
    if (metalCap) {
      final rivet = Paint()..color = SlipperPalette.outline;
      for (final o in const [Offset(176, 48), Offset(190, 62), Offset(184, 80)]) {
        c.drawCircle(o, 2.2, rivet);
      }
    }
    c.restore();
    c.drawPath(cap, _stroke());
    c.drawPath(vamp, _stroke());
  }

  // --- Детали от прокачки ----------------------------------------------

  /// Удар: стальные шипы на заднике и верху носка.
  void _drawSpikes(Canvas c) {
    final n = _tier(slipper.level(Stat.attack));
    if (n == 0) return;
    // (точка основания, направление в градусах, длина)
    const spots = [
      (Offset(122, 22), -95.0, 20.0),
      (Offset(96, 28), -115.0, 18.0),
      (Offset(148, 24), -78.0, 18.0),
      (Offset(76, 42), -135.0, 16.0),
      (Offset(170, 34), -60.0, 16.0),
      (Offset(60, 66), -160.0, 14.0),
    ];
    for (var i = 0; i < n; i++) {
      final (base, deg, len) = spots[i];
      final a = deg * pi / 180;
      final dir = Offset(cos(a), sin(a));
      final side = Offset(-dir.dy, dir.dx);
      final tip = base + dir * len;
      final l = base + side * 6;
      final r = base - side * 6;
      final spike = Path()..moveTo(l.dx, l.dy)..lineTo(tip.dx, tip.dy)..lineTo(r.dx, r.dy)..close();
      final half = Path()..moveTo(base.dx, base.dy)..lineTo(tip.dx, tip.dy)..lineTo(r.dx, r.dy)..close();
      // Тёмное основание-«гнездо».
      c.drawCircle(base, 7, Paint()..color = SlipperPalette.outsoleLight);
      c.drawCircle(base, 7, _stroke(3));
      c.drawPath(spike, Paint()..color = SlipperPalette.metal);
      c.drawPath(half, Paint()..color = SlipperPalette.metalDark);
      c.drawPath(spike, _stroke(3));
    }
  }

  /// Подошва: клёпаные пластины на носке.
  void _drawPlates(Canvas c) {
    final n = min(3, _tier(slipper.level(Stat.defense)));
    if (n == 0) return;
    const spots = [Offset(100, 78), Offset(124, 82), Offset(148, 80)];
    final rivet = Paint()..color = SlipperPalette.outline;
    c.save();
    c.clipPath(_vamp());
    for (var i = 0; i < n; i++) {
      final o = spots[i];
      final r = RRect.fromRectAndRadius(
        Rect.fromCenter(center: o, width: 22, height: 16),
        const Radius.circular(3),
      );
      c.drawRRect(r.shift(const Offset(0, 2)), Paint()..color = SlipperPalette.metalDark);
      c.drawRRect(r, Paint()..color = SlipperPalette.metal);
      c.drawRRect(r, _stroke(3));
      for (final d in const [Offset(-7, -4), Offset(7, -4), Offset(-7, 4), Offset(7, 4)]) {
        c.drawCircle(o + d, 1.7, rivet);
      }
    }
    c.restore();
  }

  /// Прочность: перекрещенные бинты.
  void _drawPatches(Canvas c) {
    final n = _tier(slipper.level(Stat.health), maxTier: 3);
    if (n == 0) return;
    const spots = [Offset(96, 74), Offset(104, 42), Offset(172, 42)];
    final band = Paint()..color = SlipperPalette.cream;
    for (var i = 0; i < n; i++) {
      final o = spots[i];
      for (final ang in [-0.6, 0.6]) {
        c.save();
        c.translate(o.dx, o.dy);
        c.rotate(ang);
        final r = RRect.fromRectAndRadius(
          const Rect.fromLTWH(-12, -4, 24, 8),
          const Radius.circular(2),
        );
        c.drawRRect(r, band);
        c.drawRRect(r, _stroke(2.5));
        c.restore();
      }
    }
  }

  /// Скорость: пламя из пятки.
  void _drawFlames(Canvas c) {
    final n = _tier(slipper.level(Stat.speed), maxTier: 3);
    if (n == 0) return;
    final len = 28.0 + n * 12;
    const x0 = 62.0;
    Path flame(double scale, double dy) => Path()
      ..moveTo(x0, 40 + dy)
      ..cubicTo(x0 - 24 * scale, 34 + dy, x0 - len * 0.5 * scale, 26 + dy, x0 - len * scale, 20 + dy)
      ..cubicTo(x0 - len * 0.55 * scale, 34 + dy, x0 - len * 0.7 * scale, 42 + dy, x0 - len * 0.9 * scale, 48 + dy)
      ..cubicTo(x0 - len * 0.5 * scale, 46 + dy, x0 - len * 0.4 * scale, 56 + dy, x0 - len * 0.55 * scale, 68 + dy)
      ..cubicTo(x0 - len * 0.25 * scale, 60 + dy, x0 - 20 * scale, 64 + dy, x0, 66 + dy)
      ..close();
    final outer = flame(1, 0);
    c.drawPath(outer, Paint()..color = const Color(0xFFFF6A1F));
    c.drawPath(flame(0.62, 6), Paint()..color = const Color(0xFFFFC533));
    c.drawPath(flame(0.3, 10), Paint()..color = const Color(0xFFFFF3B0));
    c.drawPath(outer, _stroke(3.5));
  }

  // --- Лицо ------------------------------------------------------------

  void _drawFace(Canvas c) {
    const eyes = [Offset(120, 54), Offset(150, 50)];
    final white = Paint()..color = Colors.white;
    final black = Paint()..color = SlipperPalette.outline;
    final s = _stroke(3.5);

    switch (mood) {
      case SlipperMood.dead:
        for (final e in eyes) {
          c.drawLine(e + const Offset(-7, -7), e + const Offset(7, 7), s);
          c.drawLine(e + const Offset(-7, 7), e + const Offset(7, -7), s);
        }
      case SlipperMood.hurt:
        for (final e in eyes) {
          c.drawLine(e + const Offset(-8, 0), e + const Offset(8, 0), s);
        }
      case SlipperMood.happy:
        for (final e in eyes) {
          c.drawArc(Rect.fromCircle(center: e, radius: 8), pi, pi, false, s);
        }
        _drawMouth(c, smile: true);
      case SlipperMood.idle:
      case SlipperMood.attack:
        for (final e in eyes) {
          c.drawCircle(e, 10, white);
          c.drawCircle(e, 10, s);
          c.drawCircle(e + const Offset(3.5, 0.5), 4.5, black);
          c.drawCircle(e + const Offset(5.5, -2), 1.5, white);
        }
        if (mood == SlipperMood.attack) {
          c.drawLine(const Offset(108, 38), const Offset(128, 46), s);
          c.drawLine(const Offset(140, 36), const Offset(160, 42), s);
        }
        _drawMouth(c, smile: mood == SlipperMood.idle);
    }
  }

  /// Рот на мыске; с прокачанным Ударом — зубастый.
  void _drawMouth(Canvas c, {required bool smile}) {
    final teeth = _tier(slipper.level(Stat.attack)) >= 2;
    final s = _stroke(3.5);
    if (teeth) {
      // Пасть вдоль края мыска.
      final mouth = Path()
        ..moveTo(170, 58)
        ..quadraticBezierTo(176, 76, 190, 80)
        ..quadraticBezierTo(178, 82, 166, 70)
        ..close();
      c.drawPath(mouth, Paint()..color = const Color(0xFF7A1F2E));
      final tooth = Paint()..color = Colors.white;
      for (final (o, d) in const [
        (Offset(172, 62), Offset(6, 6)),
        (Offset(177, 70), Offset(6, 5)),
        (Offset(184, 76), Offset(5, 4)),
      ]) {
        final t = Path()..moveTo(o.dx, o.dy)..lineTo(o.dx + d.dx, o.dy - 1)..lineTo(o.dx + d.dx * 0.4, o.dy + d.dy)..close();
        c.drawPath(t, tooth);
        c.drawPath(t, _stroke(2));
      }
      c.drawPath(mouth, s);
    } else if (smile) {
      c.drawArc(const Rect.fromLTWH(160, 52, 30, 24), 0.35, 1.5, false, s);
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
