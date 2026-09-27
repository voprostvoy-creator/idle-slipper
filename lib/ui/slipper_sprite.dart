import 'dart:math';

import 'package:flutter/material.dart';

import '../game/battle/combatant.dart';

/// Состояние тапка в бою. Лица нет — настроение передаётся движением и цветом.
enum SlipperMood { idle, attack, hurt, happy, dead }

/// Спрайт тапка: PNG из каталога + аксессуары прокачки в якорях + эффекты.
/// Бокс 2:1 от [width]; картинка другой пропорции вписывается с полями.
class SlipperSprite extends StatefulWidget {
  const SlipperSprite({
    super.key,
    required this.fighter,
    this.mood = SlipperMood.idle,
    this.flip = false,
    this.animate = true,
    this.width = 200,
    this.showSize = true,
    this.impulse = 0,
    this.shake = true,
    this.negative = false,
  });

  final Combatant fighter;
  final SlipperMood mood;
  final bool flip;
  final bool animate;
  final double width;

  /// Учитывать ли размер от Здоровья. В витринах (коллекция) выключаем,
  /// чтобы тапки сравнивались в одном масштабе.
  final bool showSize;

  /// Счётчик внешних толчков: меняется — спрайт заново проигрывает реакцию.
  /// Нужен, когда удары идут подряд и поза не успевает смениться.
  final int impulse;

  /// Трясти ли при уроне. У ответного урона от шипов тряски нет —
  /// боец в этот момент не отшатывается, только вспыхивает красным.
  final bool shake;

  /// Рисовать негативом — тёмная форма преображения: белое становится
  /// чёрным, чёрная обводка — белой.
  final bool negative;

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

  /// Медленное вращение искр вокруг тапка.
  late final AnimationController _orbit = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 7),
  );

  /// Реальный размер PNG — чтобы правильно положить якоря.
  Size? _imageSize;
  ImageStream? _stream;
  ImageStreamListener? _listener;

  @override
  void initState() {
    super.initState();
    _resolveImage();
    if (widget.animate) _orbit.repeat();
  }

  @override
  void didUpdateWidget(SlipperSprite old) {
    super.didUpdateWidget(old);
    if (old.fighter.asset != widget.fighter.asset) _resolveImage();
    if (old.animate != widget.animate) {
      widget.animate ? _orbit.repeat() : _orbit.stop();
    }
    final reacts = widget.mood == SlipperMood.hurt || widget.mood == SlipperMood.happy;
    if (reacts && (old.mood != widget.mood || old.impulse != widget.impulse)) {
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
    _stream = AssetImage(widget.fighter.asset).resolve(ImageConfiguration.empty)
      ..addListener(_listener!);
  }

  @override
  void dispose() {
    _stream?.removeListener(_listener!);
    _breath.dispose();
    _fx.dispose();
    _orbit.dispose();
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
          // Аура прокачки — за тапком, арт не перекрывается.
          Positioned.fill(
            child: CustomPaint(
              painter: AuraPainter(
                aura: widget.fighter.aura,
                fitted: fitted,
                phase: widget.animate
                    ? _orbit
                    : const AlwaysStoppedAnimation<double>(0),
              ),
            ),
          ),
          Positioned.fromRect(
            rect: fitted,
            child: Image.asset(widget.fighter.asset, fit: BoxFit.fill),
          ),
        ],
      ),
    );

    sprite = _applyMoodColor(sprite);
    if (widget.negative) {
      sprite = ColorFiltered(
        colorFilter: const ColorFilter.matrix([
          -1, 0, 0, 0, 255,
          0, -1, 0, 0, 255,
          0, 0, -1, 0, 255,
          0, 0, 0, 1, 0,
        ]),
        child: sprite,
      );
    }
    if (widget.showSize) {
      sprite = Transform.scale(
        scale: widget.fighter.sizeFactor,
        alignment: Alignment.bottomCenter,
        child: sprite,
      );
    }
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
        if (!widget.shake) return child;
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
        // Наклон и рывок задаёт AttackAnimation — здесь спрайт нейтрален.
        return child;
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

/// Аура бойца: свечение, кольца на «земле» и искры по орбите.
/// Что рисовать, решает сам боец через [AuraSpec] — движок и статы тут ни при чём.
class AuraPainter extends CustomPainter {
  AuraPainter({
    required this.aura,
    required this.fitted,
    required this.phase,
  }) : super(repaint: phase);

  final AuraSpec? aura;
  final Rect fitted;

  /// 0..1 — фаза вращения искр. Перерисовка идёт по её тикеру, поэтому
  /// аура не зависит от того, как часто перестраивается дерево виджетов.
  final Animation<double> phase;

  @override
  void paint(Canvas c, Size size) {
    final spec = aura;
    if (spec == null || spec.strength <= 0.001) return;
    final t = spec.strength;
    final col = spec.color;

    final center = Offset(fitted.center.dx, fitted.center.dy + fitted.height * 0.12);
    final rx = fitted.width * (0.55 + 0.14 * t);
    final ry = fitted.height * (0.46 + 0.16 * t);
    // Лёгкая пульсация, чтобы аура жила.
    final pulse = 0.88 + 0.12 * sin(phase.value * 2 * pi);

    // Мягкое свечение вокруг бойца.
    c.drawOval(
      Rect.fromCenter(center: center, width: rx * 2, height: ry * 2),
      Paint()
        ..shader = RadialGradient(
          colors: [
            col.withValues(alpha: 0.62 * t * pulse),
            col.withValues(alpha: 0.26 * t * pulse),
            col.withValues(alpha: 0),
          ],
          stops: const [0, 0.5, 1],
        ).createShader(Rect.fromCenter(center: center, width: rx * 2, height: ry * 2)),
    );

    // Плотное ядро у самого бойца.
    c.drawOval(
      Rect.fromCenter(center: center, width: rx * 1.1, height: ry * 1.0),
      Paint()
        ..shader = RadialGradient(
          colors: [
            col.withValues(alpha: 0.34 * t * pulse),
            col.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCenter(center: center, width: rx * 1.1, height: ry * 1.0)),
    );

    // Кольца на «земле» — чем сильнее аура, тем их больше.
    final ground = Offset(fitted.center.dx, fitted.bottom - fitted.height * 0.08);
    final rings = 1 + (t * 2).floor();
    for (var i = 0; i < rings; i++) {
      final k = 1 - i * 0.22;
      c.drawOval(
        Rect.fromCenter(
          center: ground,
          width: fitted.width * 0.78 * k,
          height: fitted.height * 0.2 * k,
        ),
        Paint()
          ..color = col.withValues(alpha: (0.72 - i * 0.16) * t)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.5 - i * 0.7,
      );
    }

    // Искры по орбите: половина за бойцом, половина перед — создаёт объём.
    final sparks = 3 + (t * 7).round();
    for (var i = 0; i < sparks; i++) {
      final a = (phase.value + i / sparks) * 2 * pi;
      final p = Offset(
        center.dx + cos(a) * rx * 0.86,
        center.dy + sin(a) * ry * 0.78,
      );
      // Ближние искры крупнее и ярче.
      final depth = (sin(a) + 1) / 2;
      final r = fitted.width * (0.011 + 0.017 * depth) * (0.6 + 0.4 * t);
      c.drawCircle(p, r * 2.6, Paint()..color = col.withValues(alpha: 0.26 * t * depth));
      c.drawCircle(p, r, Paint()..color = col.withValues(alpha: (0.55 + 0.45 * depth) * t));
      // Белое ядро у ближних искр — так они читаются как свет.
      if (depth > 0.65) {
        c.drawCircle(p, r * 0.45, Paint()..color = Colors.white.withValues(alpha: 0.7 * t));
      }
    }
  }

  @override
  bool shouldRepaint(AuraPainter old) =>
      old.aura != aura || old.fitted != fitted || old.phase != phase;
}
