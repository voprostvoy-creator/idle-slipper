import 'dart:math';

import 'package:flutter/material.dart';

import '../game/slipper.dart';
import '../game/slipper_kind.dart';

/// Состояние тапка в бою. Лица нет — настроение передаётся движением и цветом.
enum SlipperMood { idle, attack, hurt, happy, dead }

/// Спрайт тапка: PNG из каталога + аксессуары прокачки в якорях + эффекты.
/// Бокс 2:1 от [width]; картинка другой пропорции вписывается с полями.
class SlipperSprite extends StatefulWidget {
  const SlipperSprite({
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

  static const double aspect = 2;

  double get height => width / aspect;

  @override
  State<SlipperSprite> createState() => _SlipperSpriteState();
}

class _SlipperSpriteState extends State<SlipperSprite>
    with TickerProviderStateMixin {
  /// Дыхание в покое.
  late final AnimationController _breath = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat(reverse: true);

  /// Разовый эффект при смене настроения (тряска, подскок).
  late final AnimationController _fx = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
  );

  /// Реальный размер PNG — чтобы правильно положить якоря.
  Size? _imageSize;
  ImageStream? _stream;
  ImageStreamListener? _listener;

  @override
  void initState() {
    super.initState();
    _resolveImage();
  }

  @override
  void didUpdateWidget(SlipperSprite old) {
    super.didUpdateWidget(old);
    if (old.slipper.kindId != widget.slipper.kindId) _resolveImage();
    if (old.mood != widget.mood &&
        (widget.mood == SlipperMood.hurt || widget.mood == SlipperMood.happy)) {
      _fx.forward(from: 0);
    }
  }

  void _resolveImage() {
    _stream?.removeListener(_listener!);
    _listener = ImageStreamListener((info, _) {
      if (!mounted) return;
      setState(() {
        _imageSize = Size(info.image.width.toDouble(), info.image.height.toDouble());
      });
    });
    _stream = AssetImage(widget.slipper.kind.asset).resolve(ImageConfiguration.empty)
      ..addListener(_listener!);
  }

  @override
  void dispose() {
    _stream?.removeListener(_listener!);
    _breath.dispose();
    _fx.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final box = Size(widget.width, widget.height);
    final fitted = _fittedRect(box);

    Widget sprite = SizedBox.fromSize(
      size: box,
      child: Stack(
        // Аксессуары (шипы, пламя) могут выходить за края картинки.
        clipBehavior: Clip.none,
        children: [
          // Задний слой: пламя.
          Positioned.fill(
            child: CustomPaint(
              painter: _AccessoryPainter(slipper: widget.slipper, fitted: fitted, back: true),
            ),
          ),
          Positioned.fromRect(
            rect: fitted,
            child: Image.asset(widget.slipper.kind.asset, fit: BoxFit.fill),
          ),
          // Передний слой: шипы, пластины, бинты, подсветка.
          Positioned.fill(
            child: CustomPaint(
              painter: _AccessoryPainter(slipper: widget.slipper, fitted: fitted, back: false),
            ),
          ),
        ],
      ),
    );

    sprite = _applyMoodColor(sprite);
    if (widget.flip) sprite = Transform.flip(flipX: true, child: sprite);

    return AnimatedBuilder(
      animation: Listenable.merge([_breath, _fx]),
      builder: (_, child) => _applyMoodMotion(child!),
      child: sprite,
    );
  }

  /// Прямоугольник, в который вписана картинка внутри бокса.
  Rect _fittedRect(Size box) {
    final img = _imageSize ?? const Size(2, 1);
    final scale = min(box.width / img.width, box.height / img.height);
    final w = img.width * scale;
    final h = img.height * scale;
    return Rect.fromLTWH((box.width - w) / 2, (box.height - h) / 2, w, h);
  }

  Widget _applyMoodColor(Widget child) => switch (widget.mood) {
        SlipperMood.hurt => ColorFiltered(
            colorFilter: ColorFilter.mode(
              Colors.red.withValues(alpha: 0.45 * (1 - _fx.value)),
              BlendMode.srcATop,
            ),
            child: child,
          ),
        SlipperMood.dead => Opacity(
            opacity: 0.75,
            child: ColorFiltered(
              colorFilter: const ColorFilter.matrix(<double>[
                0.3, 0.59, 0.11, 0, 0,
                0.3, 0.59, 0.11, 0, 0,
                0.3, 0.59, 0.11, 0, 0,
                0, 0, 0, 1, 0,
              ]),
              child: child,
            ),
          ),
        _ => child,
      };

  Widget _applyMoodMotion(Widget child) {
    final dir = widget.flip ? -1.0 : 1.0;
    switch (widget.mood) {
      case SlipperMood.hurt:
        // Затухающая горизонтальная тряска.
        final t = _fx.value;
        final dx = sin(t * pi * 6) * 8 * (1 - t) * dir;
        return Transform.translate(offset: Offset(-dx, 0), child: child);
      case SlipperMood.happy:
        final t = Curves.easeOut.transform(_fx.value);
        final hop = sin(t * pi) * 22;
        return Transform.translate(
          offset: Offset(0, -hop),
          child: Transform.scale(
            scaleY: 1 + 0.08 * sin(t * pi),
            alignment: Alignment.bottomCenter,
            child: child,
          ),
        );
      case SlipperMood.attack:
        return Transform.rotate(angle: 0.12 * dir, alignment: Alignment.bottomCenter, child: child);
      case SlipperMood.dead:
        return Transform.rotate(angle: -0.4 * dir, alignment: Alignment.bottomCenter, child: child);
      case SlipperMood.idle:
        if (!widget.animate) return child;
        final t = Curves.easeInOut.transform(_breath.value);
        return Transform.translate(
          offset: Offset(0, -3 * t),
          child: Transform.scale(
            scaleY: 1 - 0.02 * t,
            alignment: Alignment.bottomCenter,
            child: child,
          ),
        );
    }
  }
}

/// Аксессуары прокачки поверх PNG. Рисуются в координатах вписанной картинки;
/// размеры заданы в «юнитах» — 1/200 её ширины, чтобы масштабироваться вместе с ней.
class _AccessoryPainter extends CustomPainter {
  _AccessoryPainter({required this.slipper, required this.fitted, required this.back});

  final Slipper slipper;
  final Rect fitted;

  /// true — слой за картинкой, false — перед ней.
  final bool back;

  static const _outline = Color(0xFF17111D);
  static const _metal = Color(0xFFD7DCE3);
  static const _metalDark = Color(0xFF8C95A3);
  static const _socket = Color(0xFF4A3F55);
  static const _leather = Color(0xFF8A5A33);
  static const _leatherDark = Color(0xFF5E3A1F);

  late final double _u = fitted.width / 200;

  Offset _at(Offset norm) => Offset(
        fitted.left + norm.dx * fitted.width,
        fitted.top + norm.dy * fitted.height,
      );

  Paint _stroke(double w) => Paint()
    ..color = _outline
    ..style = PaintingStyle.stroke
    ..strokeWidth = w * _u
    ..strokeJoin = StrokeJoin.round
    ..strokeCap = StrokeCap.round;

  static int _tier(int level, {int per = 5, int maxTier = 6}) =>
      min(maxTier, level ~/ per);

  @override
  void paint(Canvas c, Size size) {
    final a = slipper.kind.anchors;
    if (back) {
      _drawFlames(c, a);
      return;
    }
    _drawSoleArmor(c, a);
    _drawStraps(c, a);
    _drawSpikes(c, a);
  }

  /// Удар: стальные шипы по верхнему контуру, наружу по нормали.
  void _drawSpikes(Canvas c, SlipperAnchors a) {
    final n = min(_tier(slipper.level(Stat.attack)), a.ridge.length);
    if (n == 0 || a.ridge.length < 2) return;
    // Порядок: сначала середина, потом края — чтобы 1 шип стоял по центру.
    final order = _centerOut(a.ridge.length);
    final len = (14 + min(3, n) * 2) * _u;
    for (var i = 0; i < n; i++) {
      final idx = order[i];
      final p = _at(a.ridge[idx]);
      final prev = _at(a.ridge[max(0, idx - 1)]);
      final next = _at(a.ridge[min(a.ridge.length - 1, idx + 1)]);
      var tangent = next - prev;
      if (tangent.distance == 0) tangent = const Offset(1, 0);
      tangent = tangent / tangent.distance;
      // Нормаль «вверх» от контура (тапок смотрит вправо, верх — отрицательный Y).
      var normal = Offset(tangent.dy, -tangent.dx);
      if (normal.dy > 0) normal = -normal;
      final tip = p + normal * len;
      final side = tangent * 6 * _u;
      final spike = Path()
        ..moveTo(p.dx - side.dx, p.dy - side.dy)
        ..lineTo(tip.dx, tip.dy)
        ..lineTo(p.dx + side.dx, p.dy + side.dy)
        ..close();
      final half = Path()
        ..moveTo(p.dx, p.dy)
        ..lineTo(tip.dx, tip.dy)
        ..lineTo(p.dx + side.dx, p.dy + side.dy)
        ..close();
      c.drawCircle(p, 7 * _u, Paint()..color = _socket);
      c.drawCircle(p, 7 * _u, _stroke(2.5));
      c.drawPath(spike, Paint()..color = _metal);
      c.drawPath(half, Paint()..color = _metalDark);
      c.drawPath(spike, _stroke(2.5));
    }
  }

  /// Прочность: кожаные ремни с пряжками поперёк ремешка.
  void _drawStraps(Canvas c, SlipperAnchors a) {
    final n = min(_tier(slipper.level(Stat.health), maxTier: 3), a.side.length);
    if (n == 0) return;
    final order = _centerOut(a.side.length);
    final leather = Paint()..color = _leather;
    final buckle = Paint()..color = _metal;
    for (var i = 0; i < n; i++) {
      final o = _at(a.side[order[i]]);
      c.save();
      c.translate(o.dx, o.dy);
      // Лёгкий наклон, чтобы ремни не выглядели штампованными.
      c.rotate(-0.28 + i * 0.16);
      final belt = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: 13 * _u, height: 42 * _u),
        Radius.circular(3 * _u),
      );
      c.drawRRect(belt, leather);
      // Тёмная кромка вдоль ремня — объём.
      c.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(4 * _u, 0), width: 5 * _u, height: 42 * _u),
          Radius.circular(2 * _u),
        ),
        Paint()..color = _leatherDark,
      );
      c.drawRRect(belt, _stroke(2));
      // Пряжка.
      final plate = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: 17 * _u, height: 13 * _u),
        Radius.circular(2.5 * _u),
      );
      c.drawRRect(plate.shift(Offset(0, 1.5 * _u)), Paint()..color = _metalDark);
      c.drawRRect(plate, buckle);
      c.drawRRect(plate, _stroke(2));
      c.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: 6 * _u, height: 4.5 * _u),
          Radius.circular(1 * _u),
        ),
        Paint()..color = _outline,
      );
      c.restore();
    }
  }

  /// Скорость: пламя из пятки.
  void _drawFlames(Canvas c, SlipperAnchors a) {
    final n = _tier(slipper.level(Stat.speed), maxTier: 3);
    if (n == 0) return;
    final o = _at(a.heel);
    final len = (30 + n * 12) * _u;
    Path flame(double s, double dy) {
      final d = dy * _u;
      return Path()
        ..moveTo(o.dx, o.dy - 14 * _u + d)
        ..cubicTo(o.dx - 24 * s * _u, o.dy - 20 * _u + d, o.dx - len * 0.5 * s, o.dy - 28 * _u + d,
            o.dx - len * s, o.dy - 34 * _u + d)
        ..cubicTo(o.dx - len * 0.55 * s, o.dy - 20 * _u + d, o.dx - len * 0.7 * s, o.dy - 12 * _u + d,
            o.dx - len * 0.9 * s, o.dy - 6 * _u + d)
        ..cubicTo(o.dx - len * 0.5 * s, o.dy - 8 * _u + d, o.dx - len * 0.4 * s, o.dy + 2 * _u + d,
            o.dx - len * 0.55 * s, o.dy + 14 * _u + d)
        ..cubicTo(o.dx - len * 0.25 * s, o.dy + 6 * _u + d, o.dx - 20 * s * _u, o.dy + 10 * _u + d,
            o.dx, o.dy + 12 * _u + d)
        ..close();
    }
    final outer = flame(1, 0);
    c.drawPath(outer, Paint()..color = const Color(0xFFFF6A1F));
    c.drawPath(flame(0.62, 4), Paint()..color = const Color(0xFFFFC533));
    c.drawPath(flame(0.3, 7), Paint()..color = const Color(0xFFFFF3B0));
    c.drawPath(outer, _stroke(3));
  }

  /// Подошва: стальная шина по низу — растёт в длину и толщину с уровнем.
  void _drawSoleArmor(Canvas c, SlipperAnchors a) {
    final tier = _tier(slipper.level(Stat.defense));
    if (tier == 0) return;
    final band = Rect.fromPoints(_at(a.sole.topLeft), _at(a.sole.bottomRight));
    // Длина: от половины подошвы на 1 тире до полной на 6-м.
    final frac = 0.5 + 0.5 * (tier - 1) / 5;
    final h = band.height * (0.45 + 0.07 * min(3, tier));
    final r = Rect.fromCenter(
      center: Offset(band.center.dx, band.bottom - h * 0.75),
      width: band.width * frac,
      height: h,
    );
    final rr = RRect.fromRectAndRadius(r, Radius.circular(h * 0.35));
    c.drawRRect(rr, Paint()..color = _metalDark);
    c.save();
    c.clipRRect(rr);
    // Верхняя половина светлее — блик на металле.
    c.drawRect(
      Rect.fromLTRB(r.left, r.top, r.right, r.center.dy),
      Paint()..color = _metal,
    );
    // Насечки протектора.
    final notch = Paint()
      ..color = _outline.withValues(alpha: 0.55)
      ..strokeWidth = 2 * _u;
    final steps = (r.width / (10 * _u)).floor().clamp(2, 24);
    for (var i = 1; i < steps; i++) {
      final x = r.left + r.width * i / steps;
      c.drawLine(Offset(x, r.top), Offset(x, r.bottom), notch);
    }
    c.restore();
    c.drawRRect(rr, _stroke(2.5));
    // Заклёпки по краям шины.
    final rivet = Paint()..color = _outline;
    for (final x in [r.left + 5 * _u, r.right - 5 * _u]) {
      c.drawCircle(Offset(x, r.center.dy), 2 * _u, rivet);
    }
  }

  /// Индексы от центра к краям: [2,1,3,0,4] для длины 5.
  static List<int> _centerOut(int n) {
    final mid = n ~/ 2;
    final out = <int>[mid];
    for (var d = 1; out.length < n; d++) {
      if (mid - d >= 0) out.add(mid - d);
      if (mid + d < n) out.add(mid + d);
    }
    return out;
  }

  @override
  bool shouldRepaint(_AccessoryPainter old) =>
      old.slipper != slipper || old.fitted != fitted || old.back != back;
}
