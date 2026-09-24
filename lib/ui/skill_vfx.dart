import 'dart:math';

import 'package:flutter/material.dart';

import '../game/battle/skills.dart';

/// Разовый росчерк скилла поверх сцены боя: волна, росчерки, взрыв и прочее.
/// Живёт одну короткую анимацию и исчезает.
class SkillVfxLayer extends StatefulWidget {
  const SkillVfxLayer({
    super.key,
    required this.vfx,
    required this.color,
    required this.body,
    required this.flip,
    required this.token,
  });

  final SkillVfx vfx;
  final Color color;

  /// Прямоугольник бойца, у которого играем эффект.
  final Rect body;

  /// Куда смотрит боец — росчерки идут «по ходу» удара.
  final bool flip;

  /// Меняется при каждом новом срабатывании: по нему анимация перезапускается.
  final int token;

  static const duration = Duration(milliseconds: 620);

  @override
  State<SkillVfxLayer> createState() => _SkillVfxLayerState();
}

class _SkillVfxLayerState extends State<SkillVfxLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: SkillVfxLayer.duration,
  );

  @override
  void initState() {
    super.initState();
    if (widget.vfx != SkillVfx.none) _c.forward(from: 0);
  }

  @override
  void didUpdateWidget(SkillVfxLayer old) {
    super.didUpdateWidget(old);
    // Новое срабатывание — играем заново, даже если эффект тот же.
    if (old.token != widget.token && widget.vfx != SkillVfx.none) {
      _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.vfx == SkillVfx.none) return const SizedBox.shrink();
    return IgnorePointer(
      child: CustomPaint(
        painter: _VfxPainter(
          vfx: widget.vfx,
          color: widget.color,
          body: widget.body,
          flip: widget.flip,
          progress: _c,
        ),
      ),
    );
  }
}

class _VfxPainter extends CustomPainter {
  _VfxPainter({
    required this.vfx,
    required this.color,
    required this.body,
    required this.flip,
    required this.progress,
  }) : super(repaint: progress);

  final SkillVfx vfx;
  final Color color;
  final Rect body;
  final bool flip;
  final Animation<double> progress;

  @override
  void paint(Canvas c, Size size) {
    final t = progress.value;
    if (t <= 0 || t >= 1) return;
    switch (vfx) {
      case SkillVfx.none:
        return;
      case SkillVfx.shockwave:
        _shockwave(c, t);
      case SkillVfx.slash:
        _slash(c, t);
      case SkillVfx.burst:
        _burst(c, t);
      case SkillVfx.frost:
        _frost(c, t);
      case SkillVfx.drain:
        _drain(c, t);
      case SkillVfx.blades:
        _blades(c, t);
      case SkillVfx.gloom:
        _gloom(c, t);
    }
  }

  /// Волна от подошвы: пара колец расходится по полу и гаснет.
  void _shockwave(Canvas c, double t) {
    final ground = Offset(body.center.dx, body.bottom);
    for (var i = 0; i < 2; i++) {
      // Второе кольцо идёт с задержкой — волна читается как раскат.
      final local = (t - i * 0.18).clamp(0.0, 1.0);
      if (local <= 0) continue;
      final e = Curves.easeOutQuad.transform(local);
      final alpha = (1 - local).clamp(0.0, 1.0);
      final rx = body.width * (0.3 + 1.5 * e);
      final ry = body.height * (0.12 + 0.5 * e);
      c.drawOval(
        Rect.fromCenter(center: ground, width: rx * 2, height: ry * 2),
        Paint()
          ..color = color.withValues(alpha: 0.75 * alpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = body.height * 0.14 * alpha,
      );
    }
    // Пыль, разлетающаяся вдоль пола.
    final dust = Paint()..color = color.withValues(alpha: (1 - t) * 0.8);
    for (var i = 0; i < 8; i++) {
      final dir = i.isEven ? 1 : -1;
      final k = (i ~/ 2 + 1) / 4;
      final x = ground.dx + dir * body.width * 1.3 * t * k;
      final y = ground.dy - body.height * 0.5 * sin(t * pi) * k;
      c.drawCircle(Offset(x, y), body.width * 0.03 * (1 - t), dust);
    }
  }

  /// Пара косых росчерков по цели.
  void _slash(Canvas c, double t) {
    final dir = flip ? -1.0 : 1.0;
    for (var i = 0; i < 2; i++) {
      final local = (t - i * 0.15) / 0.7;
      if (local <= 0 || local >= 1) continue;
      final e = Curves.easeOutQuart.transform(local);
      final alpha = (1 - local).clamp(0.0, 1.0);
      final y = body.center.dy + (i == 0 ? -body.height * 0.25 : body.height * 0.2);
      final from = Offset(body.center.dx - dir * body.width * 0.55, y - body.height * 0.4);
      final to = Offset(body.center.dx + dir * body.width * 0.55, y + body.height * 0.4);
      final head = Offset.lerp(from, to, e)!;
      c.drawLine(
        from,
        head,
        Paint()
          ..color = color.withValues(alpha: 0.9 * alpha)
          ..strokeCap = StrokeCap.round
          ..strokeWidth = body.height * 0.1 * alpha,
      );
      c.drawLine(
        from,
        head,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.8 * alpha)
          ..strokeCap = StrokeCap.round
          ..strokeWidth = body.height * 0.035 * alpha,
      );
    }
  }

  /// Взрыв: вспышка и разлетающиеся искры.
  void _burst(Canvas c, double t) {
    final o = body.center;
    final e = Curves.easeOutCubic.transform(t);
    final alpha = (1 - t).clamp(0.0, 1.0);
    // Вспышка в центре.
    c.drawCircle(
      o,
      body.width * 0.45 * (0.4 + e),
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.white.withValues(alpha: 0.9 * alpha),
            color.withValues(alpha: 0.6 * alpha),
            color.withValues(alpha: 0),
          ],
          stops: const [0, 0.45, 1],
        ).createShader(Rect.fromCircle(center: o, radius: body.width * 0.45 * (0.4 + e))),
    );
    // Лучи-искры во все стороны.
    const rays = 10;
    for (var i = 0; i < rays; i++) {
      final a = i * 2 * pi / rays + t;
      final len = body.width * (0.35 + 0.65 * e);
      final from = o + Offset(cos(a), sin(a)) * len * 0.45;
      final to = o + Offset(cos(a), sin(a)) * len;
      c.drawLine(
        from,
        to,
        Paint()
          ..color = color.withValues(alpha: 0.9 * alpha)
          ..strokeCap = StrokeCap.round
          ..strokeWidth = body.width * 0.022 * alpha,
      );
    }
  }

  /// Иней: осколки оседают на цели.
  void _frost(Canvas c, double t) {
    final o = body.center;
    final alpha = (1 - t).clamp(0.0, 1.0);
    const shards = 7;
    for (var i = 0; i < shards; i++) {
      final a = i * 2 * pi / shards;
      final d = body.width * 0.5 * (1 - Curves.easeOutCubic.transform(t));
      final p = o + Offset(cos(a), sin(a)) * (body.width * 0.28 + d);
      final r = body.width * 0.05 * alpha;
      final path = Path()
        ..moveTo(p.dx, p.dy - r)
        ..lineTo(p.dx + r * 0.7, p.dy)
        ..lineTo(p.dx, p.dy + r)
        ..lineTo(p.dx - r * 0.7, p.dy)
        ..close();
      c.drawPath(path, Paint()..color = color.withValues(alpha: 0.85 * alpha));
    }
  }

  /// Вытягивание: искры тянутся от цели к бойцу.
  void _drain(Canvas c, double t) {
    final dir = flip ? 1.0 : -1.0;
    final from = body.center;
    final to = Offset(body.center.dx + dir * body.width * 1.6, body.center.dy);
    const count = 7;
    for (var i = 0; i < count; i++) {
      final local = (t * 1.4 - i / count).clamp(0.0, 1.0);
      if (local <= 0) continue;
      final e = Curves.easeInCubic.transform(local);
      final p = Offset.lerp(from, to, e)!;
      // Небольшая волна по вертикали, чтобы поток не был линейкой.
      final wave = sin((i + t * 4) * 1.6) * body.height * 0.25 * (1 - e);
      final alpha = (1 - local).clamp(0.0, 1.0);
      c.drawCircle(
        Offset(p.dx, p.dy + wave),
        body.width * 0.035 * (1 - e * 0.5),
        Paint()..color = color.withValues(alpha: 0.9 * alpha),
      );
    }
  }

  /// Серия лезвий: быстрые параллельные росчерки.
  void _blades(Canvas c, double t) {
    final dir = flip ? -1.0 : 1.0;
    const count = 4;
    for (var i = 0; i < count; i++) {
      final local = (t - i * 0.12) / 0.55;
      if (local <= 0 || local >= 1) continue;
      final e = Curves.easeOutQuart.transform(local);
      final alpha = (1 - local).clamp(0.0, 1.0);
      final y = body.top + body.height * (0.15 + 0.7 * i / (count - 1));
      final from = Offset(body.center.dx - dir * body.width * 0.6, y);
      final to = Offset(body.center.dx + dir * body.width * 0.6, y - body.height * 0.18);
      c.drawLine(
        from,
        Offset.lerp(from, to, e)!,
        Paint()
          ..color = color.withValues(alpha: 0.9 * alpha)
          ..strokeCap = StrokeCap.round
          ..strokeWidth = body.height * 0.07 * alpha,
      );
    }
  }

  /// Клубы над целью — ослабление. Тёмное ядро со светлой каймой,
  /// иначе на тёмном фоне комнаты эффект пропадает.
  void _gloom(Canvas c, double t) {
    final alpha = sin(t * pi).clamp(0.0, 1.0);
    const puffs = 6;
    for (var i = 0; i < puffs; i++) {
      final localPhase = (t + i / puffs) % 1;
      final x = body.left + body.width * (0.12 + 0.76 * i / (puffs - 1));
      final y = body.center.dy - body.height * (0.1 + 1.1 * localPhase);
      final r = body.width * (0.1 + 0.09 * localPhase);
      final fade = alpha * (1 - localPhase);
      // Тёмная сердцевина.
      c.drawCircle(
        Offset(x, y),
        r,
        Paint()
          ..color = const Color(0xFF1A0F26).withValues(alpha: 0.8 * fade)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.45),
      );
      // Светящаяся кайма цветом скилла.
      c.drawCircle(
        Offset(x, y),
        r * 0.85,
        Paint()
          ..color = color.withValues(alpha: 0.85 * fade)
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.3,
      );
    }
  }

  @override
  bool shouldRepaint(_VfxPainter old) =>
      old.vfx != vfx ||
      old.color != color ||
      old.body != body ||
      old.progress != progress;
}
