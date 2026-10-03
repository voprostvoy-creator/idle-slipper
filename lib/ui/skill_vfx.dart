import 'dart:math';

import 'package:flutter/material.dart';

import '../game/battle/skills.dart';

/// Короткие вспышки поверх бойца: блики удара и эффекты скиллов.
/// Всё, что связано с ударом, появляется в момент касания; то, что скилл
/// делает с самим бойцом, — в момент применения.
enum VfxKind {
  /// Блик обычного попадания.
  hit(Duration(milliseconds: 280)),

  /// Золотая звезда крита.
  crit(Duration(milliseconds: 420)),

  /// Кольцо удара скиллом.
  skillRing(Duration(milliseconds: 420)),

  /// Мощная вспышка ульты.
  ultBurst(Duration(milliseconds: 560)),

  // --- Эффекты скилла на цели (в момент удара) ---
  poison(Duration(milliseconds: 620)),
  fire(Duration(milliseconds: 560)),
  frost(Duration(milliseconds: 560)),
  weaken(Duration(milliseconds: 600)),
  vulnerable(Duration(milliseconds: 520)),
  silence(Duration(milliseconds: 600)),
  pierce(Duration(milliseconds: 360)),
  dispel(Duration(milliseconds: 560)),
  stunPop(Duration(milliseconds: 480)),
  lifesteal(Duration(milliseconds: 620)),
  ultSteal(Duration(milliseconds: 560)),

  // --- Эффекты скилла на себе (в момент применения) ---
  barrierCast(Duration(milliseconds: 560)),
  hasteCast(Duration(milliseconds: 520)),
  cleanseCast(Duration(milliseconds: 600)),
  reflectCast(Duration(milliseconds: 560)),
  formCast(Duration(milliseconds: 700));

  const VfxKind(this.duration);
  final Duration duration;
}

/// Какие эффекты вспыхивают на цели в момент удара этим скиллом.
List<VfxKind> hitVfxOf(ActiveSkill s) => [
  if (s.poisonStacks > 0) VfxKind.poison,
  if (s.burnTurns > 0) VfxKind.fire,
  if (s.slowTurns > 0) VfxKind.frost,
  if (s.weakenTurns > 0) VfxKind.weaken,
  if (s.vulnerableTurns > 0) VfxKind.vulnerable,
  if (s.silenceTurns > 0) VfxKind.silence,
  if (s.pierce > 0) VfxKind.pierce,
  if (s.dispel) VfxKind.dispel,
  if (s.stun) VfxKind.stunPop,
  if (s.lifesteal > 0) VfxKind.lifesteal,
  if (s.ultSteal > 0) VfxKind.ultSteal,
];

/// Какие эффекты вспыхивают на самом бойце, когда он применяет скилл.
List<VfxKind> castVfxOf(ActiveSkill s) => [
  if (s.barrierPercent > 0 || s.shield > 0) VfxKind.barrierCast,
  if (s.hasteTurns > 0) VfxKind.hasteCast,
  if (s.cleanse) VfxKind.cleanseCast,
  if (s.reflect) VfxKind.reflectCast,
  if (s.formTurns > 0) VfxKind.formCast,
];

/// Рисует одну вспышку: [t] — ход 0..1, [body] — где стоит боец,
/// [dir] — куда смотрит удар (1 — вправо, -1 — влево).
class VfxPainter extends CustomPainter {
  VfxPainter({
    required this.kind,
    required this.t,
    required this.body,
    this.dir = 1,
  });

  final VfxKind kind;
  final double t;
  final Rect body;
  final double dir;

  double get _fade => t < 0.7 ? 1 : 1 - (t - 0.7) / 0.3;

  Paint _p(Color c, [double alpha = 1]) =>
      Paint()..color = c.withValues(alpha: (alpha * _fade).clamp(0.0, 1.0));

  Paint _stroke(Color c, double w, [double alpha = 1]) => _p(c, alpha)
    ..style = PaintingStyle.stroke
    ..strokeWidth = w
    ..strokeCap = StrokeCap.round;

  @override
  void paint(Canvas c, Size size) {
    final center = body.center;
    final r = body.shortestSide * 0.5;
    final e = Curves.easeOutCubic.transform(t);
    switch (kind) {
      case VfxKind.hit:
        _burst(c, center, r * (0.3 + 0.5 * e), Colors.white, rays: 6);
      case VfxKind.crit:
        _star(c, center, r * (0.4 + 0.7 * e), const Color(0xFFFFD84A));
        _burst(c, center, r * (0.5 + 0.8 * e), Colors.white, rays: 10);
      case VfxKind.skillRing:
        c.drawCircle(
          center,
          r * (0.3 + 1.0 * e),
          _stroke(const Color(0xFFBFE9FF), r * 0.14 * (1 - e) + 1),
        );
        _burst(c, center, r * (0.4 + 0.6 * e), Colors.white, rays: 8);
      case VfxKind.ultBurst:
        c.drawCircle(
          center,
          r * (0.5 + 1.6 * e),
          Paint()
            ..shader =
                RadialGradient(
                  colors: [
                    const Color(0xFFFFF3B0).withValues(alpha: 0.8 * _fade),
                    const Color(0xFFFFB03A).withValues(alpha: 0.4 * _fade),
                    Colors.transparent,
                  ],
                ).createShader(
                  Rect.fromCircle(center: center, radius: r * (0.5 + 1.6 * e)),
                ),
        );
        c.drawCircle(
          center,
          r * (0.4 + 1.4 * e),
          _stroke(Colors.white, r * 0.12 * (1 - e) + 1),
        );
        _burst(
          c,
          center,
          r * (0.6 + 1.1 * e),
          const Color(0xFFFFE28A),
          rays: 12,
        );
      case VfxKind.poison:
        _particles(
          c,
          center,
          r,
          const Color(0xFF7CE35A),
          up: false,
          count: 10,
          round: true,
        );
      case VfxKind.fire:
        _flare(c, center, r * (0.5 + 0.9 * e));
      case VfxKind.frost:
        _shards(c, center, r * (0.4 + 0.8 * e), const Color(0xFFBFE9FF));
      case VfxKind.weaken:
        _arrows(c, center, r, const Color(0xFFC77DFF), down: true);
      case VfxKind.vulnerable:
        _cracks(c, center, r * (0.5 + 0.5 * e), const Color(0xFFFF9F43));
      case VfxKind.silence:
        c.drawCircle(
          center,
          r * (0.5 + 0.4 * e),
          _stroke(const Color(0xFFCDBBE0), r * 0.08),
        );
        c.drawLine(
          center + Offset(-r * 0.5, -r * 0.5),
          center + Offset(r * 0.5, r * 0.5),
          _stroke(const Color(0xFFFF6161), r * 0.1),
        );
      case VfxKind.pierce:
        final len = body.width * (0.6 + 0.8 * e);
        c.drawLine(
          center - Offset(len * 0.5 * dir, 0),
          center + Offset(len * 0.5 * dir, 0),
          _stroke(Colors.white, r * 0.12 * (1 - e) + 1.5),
        );
      case VfxKind.dispel:
        _shards(c, center, r * (0.5 + 1.0 * e), const Color(0xFF7FF5FF));
      case VfxKind.stunPop:
        for (var i = 0; i < 5; i++) {
          final a = i / 5 * 2 * pi + t * 2;
          _star(
            c,
            center + Offset(cos(a), sin(a) * 0.5) * r * (0.3 + 0.7 * e),
            r * 0.18,
            const Color(0xFFFFD84A),
          );
        }
      case VfxKind.lifesteal:
        _particles(
          c,
          center,
          r,
          const Color(0xFFFF4D6D),
          up: true,
          count: 9,
          round: true,
        );
      case VfxKind.ultSteal:
        for (var i = 0; i < 3; i++) {
          c.drawArc(
            Rect.fromCircle(
              center: center,
              radius: r * (0.3 + 0.25 * i) * (1 - 0.4 * e),
            ),
            t * 6 + i,
            pi * 1.2,
            false,
            _stroke(const Color(0xFF5BC8FF), r * 0.07),
          );
        }
      case VfxKind.barrierCast:
        _hexagon(c, center, r * (0.8 + 0.4 * e), const Color(0xFF7FDBFF));
      case VfxKind.hasteCast:
        for (var i = 0; i < 5; i++) {
          final y = body.top + body.height * (0.2 + i * 0.15);
          final x0 = center.dx - dir * body.width * (0.2 + 0.5 * e);
          c.drawLine(
            Offset(x0, y),
            Offset(x0 - dir * body.width * 0.3, y),
            _stroke(const Color(0xFF6BE07A), r * 0.06),
          );
        }
      case VfxKind.cleanseCast:
        _particles(
          c,
          center,
          r,
          Colors.white,
          up: true,
          count: 12,
          round: false,
        );
      case VfxKind.reflectCast:
        final rect = Rect.fromCenter(
          center: center,
          width: body.width * 0.9,
          height: body.height * 1.1,
        );
        c.drawRRect(
          RRect.fromRectAndRadius(rect, Radius.circular(r * 0.3)),
          _stroke(const Color(0xFFBFE9FF), r * 0.08, 0.9),
        );
        c.drawLine(
          Offset(rect.left + rect.width * (e - 0.2), rect.top),
          Offset(rect.left + rect.width * (e + 0.1), rect.bottom),
          _stroke(Colors.white, r * 0.12, 0.8),
        );
      case VfxKind.formCast:
        for (var i = 0; i < 3; i++) {
          c.drawArc(
            Rect.fromCircle(
              center: center,
              radius: r * (0.6 + 0.3 * i) * (1.2 - 0.4 * e),
            ),
            -t * 5 + i * 2,
            pi * 1.3,
            false,
            _stroke(i.isEven ? Colors.white : const Color(0xFF14091F), r * 0.1),
          );
        }
    }
  }

  void _burst(
    Canvas c,
    Offset o,
    double len,
    Color color, {
    required int rays,
  }) {
    for (var i = 0; i < rays; i++) {
      final a = i / rays * 2 * pi + 0.3;
      final d = Offset(cos(a), sin(a));
      c.drawLine(
        o + d * len * 0.35,
        o + d * len,
        _stroke(color, max(1.5, len * 0.08)),
      );
    }
  }

  void _star(Canvas c, Offset o, double r, Color color) {
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final a = -pi / 2 + i * pi / 5;
      final rr = i.isEven ? r : r * 0.45;
      final p = o + Offset(cos(a), sin(a)) * rr;
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    path.close();
    c.drawPath(path, _p(color));
    c.drawPath(path, _stroke(const Color(0xFF14091F), max(1, r * 0.1)));
  }

  /// Капли или искры, разлетающиеся вверх или вниз.
  void _particles(
    Canvas c,
    Offset o,
    double r,
    Color color, {
    required bool up,
    required int count,
    required bool round,
  }) {
    for (var i = 0; i < count; i++) {
      final a = (i / count) * 2 * pi + i * 0.7;
      final spread = Offset(cos(a) * r * 0.9, sin(a) * r * 0.4);
      final lift =
          (up ? -1 : 1) * r * 1.2 * t * (0.6 + 0.4 * ((i * 37) % 10) / 10);
      final p = o + spread * Curves.easeOut.transform(t) + Offset(0, lift);
      final size = r * (0.1 + 0.05 * (i % 3));
      if (round) {
        c.drawCircle(p, size, _p(color));
      } else {
        _star(c, p, size * 1.2, color);
      }
    }
  }

  /// Огненная вспышка: языки пламени во все стороны.
  void _flare(Canvas c, Offset o, double r) {
    c.drawCircle(
      o,
      r,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFFFF3B0).withValues(alpha: 0.9 * _fade),
            const Color(0xFFFF7A2E).withValues(alpha: 0.7 * _fade),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(center: o, radius: r)),
    );
    for (var i = 0; i < 7; i++) {
      final a = -pi / 2 + (i - 3) * 0.4;
      final tip = o + Offset(cos(a), sin(a)) * r * 1.2;
      c.drawPath(
        Path()
          ..moveTo(o.dx - r * 0.12, o.dy)
          ..quadraticBezierTo(o.dx, o.dy - r * 0.3, tip.dx, tip.dy)
          ..quadraticBezierTo(o.dx, o.dy - r * 0.2, o.dx + r * 0.12, o.dy)
          ..close(),
        _p(const Color(0xFFFF9F43), 0.85),
      );
    }
  }

  /// Осколки: льдинки или кристаллы, разлетающиеся от центра.
  void _shards(Canvas c, Offset o, double r, Color color) {
    for (var i = 0; i < 8; i++) {
      final a = i / 8 * 2 * pi + 0.2;
      final d = Offset(cos(a), sin(a));
      final p = o + d * r;
      final n = Offset(-d.dy, d.dx);
      c.drawPath(
        Path()
          ..moveTo((p + d * r * 0.25).dx, (p + d * r * 0.25).dy)
          ..lineTo((p + n * r * 0.08).dx, (p + n * r * 0.08).dy)
          ..lineTo((p - d * r * 0.15).dx, (p - d * r * 0.15).dy)
          ..lineTo((p - n * r * 0.08).dx, (p - n * r * 0.08).dy)
          ..close(),
        _p(color, 0.9),
      );
    }
  }

  void _arrows(
    Canvas c,
    Offset o,
    double r,
    Color color, {
    required bool down,
  }) {
    for (var i = -1; i <= 1; i++) {
      final x = o.dx + i * r * 0.6;
      final y = o.dy - r * 0.6 + r * 1.2 * t + (i.abs() * r * 0.2);
      final s = r * 0.25;
      c.drawPath(
        Path()
          ..moveTo(x - s, y - s * 0.4)
          ..lineTo(x + s, y - s * 0.4)
          ..lineTo(x, y + s)
          ..close(),
        _p(color),
      );
    }
  }

  void _cracks(Canvas c, Offset o, double r, Color color) {
    for (var i = 0; i < 5; i++) {
      final a = i / 5 * 2 * pi + 0.5;
      final d = Offset(cos(a), sin(a));
      final n = Offset(-d.dy, d.dx);
      c.drawPath(
        Path()
          ..moveTo(o.dx, o.dy)
          ..lineTo(
            (o + d * r * 0.5 + n * r * 0.12).dx,
            (o + d * r * 0.5 + n * r * 0.12).dy,
          )
          ..lineTo((o + d * r).dx, (o + d * r).dy),
        _stroke(color, max(1.5, r * 0.08)),
      );
    }
  }

  void _hexagon(Canvas c, Offset o, double r, Color color) {
    final path = Path();
    for (var i = 0; i < 6; i++) {
      final a = pi / 6 + i * pi / 3;
      final p = o + Offset(cos(a), sin(a)) * r;
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    path.close();
    c.drawPath(path, _p(color, 0.25));
    c.drawPath(path, _stroke(color, max(2, r * 0.06), 0.9));
  }

  @override
  bool shouldRepaint(VfxPainter old) => old.t != t || old.kind != kind;
}
