import 'dart:math';

import 'package:flutter/material.dart';

import 'theme.dart';

/// Что сейчас происходит с бойцом — рисуется поверх его спрайта.
enum BattleEffect {
  /// Пропускает ход: звёзды кружат над бойцом.
  stun,

  /// Горит: пламя охватывает силуэт.
  burn,

  /// Под щитом: купол вокруг бойца.
  shield,

  /// Только что подлечился: зелёные искры вверх.
  heal,
}

/// Сколько эффект держится на экране после своего события.
const effectDurations = {
  BattleEffect.stun: Duration(milliseconds: 1100),
  BattleEffect.burn: Duration(milliseconds: 1000),
  BattleEffect.shield: Duration(milliseconds: 1600),
  BattleEffect.heal: Duration(milliseconds: 800),
};

/// Слой эффектов поверх бойца. Анимация идёт по собственному тикеру,
/// поэтому не зависит от того, как часто перестраивается дерево.
class BattleEffectsLayer extends StatefulWidget {
  const BattleEffectsLayer({
    super.key,
    required this.effects,
    required this.size,
    required this.body,
  });

  final Set<BattleEffect> effects;

  /// Размер бокса бойца.
  final Size size;

  /// Где внутри бокса реально находится спрайт: эффекты держатся за него,
  /// иначе у мелкого тапка пламя горело бы в стороне.
  final Rect body;

  @override
  State<BattleEffectsLayer> createState() => _BattleEffectsLayerState();
}

class _BattleEffectsLayerState extends State<BattleEffectsLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.effects.isEmpty) return const SizedBox.shrink();
    return IgnorePointer(
      child: CustomPaint(
        size: widget.size,
        painter: _EffectsPainter(
          effects: widget.effects,
          phase: _c,
          body: widget.body,
        ),
      ),
    );
  }
}

class _EffectsPainter extends CustomPainter {
  _EffectsPainter({
    required this.effects,
    required this.phase,
    required this.body,
  }) : super(repaint: phase);

  final Set<BattleEffect> effects;
  final Animation<double> phase;

  /// Прямоугольник самого бойца внутри бокса.
  final Rect body;

  @override
  void paint(Canvas c, Size size) {
    final t = phase.value;
    // Щит рисуется под остальным, звёзды — поверх всего.
    if (effects.contains(BattleEffect.shield)) _shield(c, t);
    if (effects.contains(BattleEffect.burn)) _burn(c, t);
    if (effects.contains(BattleEffect.heal)) _heal(c, t);
    if (effects.contains(BattleEffect.stun)) _stun(c, t);
  }

  /// Звёзды по кругу над бойцом — классический знак оглушения.
  void _stun(Canvas c, double t) {
    final center = Offset(body.center.dx, body.top - body.height * 0.3);
    final rx = body.width * 0.24;
    final ry = body.height * 0.22;
    const count = 3;
    for (var i = 0; i < count; i++) {
      final a = (t + i / count) * 2 * pi;
      final p = Offset(center.dx + cos(a) * rx, center.dy + sin(a) * ry);
      // Дальние звёзды мельче — получается объём.
      final depth = (sin(a) + 1) / 2;
      final r = body.width * (0.035 + 0.022 * depth);
      _star(c, p, r, GameColors.gold, spin: a);
    }
  }

  void _star(Canvas c, Offset o, double r, Color color, {double spin = 0}) {
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final a = -pi / 2 + spin + i * pi / 5;
      final rad = i.isEven ? r : r * 0.44;
      final p = o + Offset(cos(a), sin(a)) * rad;
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    path.close();
    c.drawPath(path, Paint()..color = color);
    c.drawPath(
      path,
      Paint()
        ..color = GameColors.outline
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.28
        ..strokeJoin = StrokeJoin.round,
    );
  }

  /// Пламя охватывает бойца: тёплый ореол по силуэту и языки, поднимающиеся
  /// от подошвы вверх по нему.
  void _burn(Canvas c, double t) {
    // Ореол под языками — горит весь тапок, а не только пол под ним.
    final glow = Rect.fromCenter(
      center: Offset(body.center.dx, body.center.dy - body.height * 0.1),
      width: body.width * 1.2,
      height: body.height * 1.9,
    );
    final flicker = 0.8 + 0.2 * sin(t * 6 * pi);
    c.drawOval(
      glow,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFFF6A1F).withValues(alpha: 0.34 * flicker),
            const Color(0xFFFF6A1F).withValues(alpha: 0.13 * flicker),
            const Color(0x00FF6A1F),
          ],
          stops: const [0, 0.5, 1],
        ).createShader(glow),
    );

    // Языки начинаются у подошвы и достают до верха тапка.
    const tongues = 7;
    final baseY = body.bottom;
    for (var i = 0; i < tongues; i++) {
      // Каждый язык живёт со своей фазой, поэтому пламя не пульсирует разом.
      final localPhase = (t * 2 + i / tongues) % 1;
      final x = body.left + body.width * (0.08 + 0.84 * i / (tongues - 1));
      // Ближе к центру языки выше — пламя облизывает силуэт.
      final bias = 1 - (x - body.center.dx).abs() / (body.width / 2);
      final h =
          body.height *
          (0.5 + 0.6 * bias) *
          (0.82 + 0.28 * sin(localPhase * pi));
      final w = body.width * (0.07 + 0.02 * cos(localPhase * 2 * pi));
      final sway = sin((t * 2 + i) * 2 * pi) * body.width * 0.02;

      Path tongue(double scale) => Path()
        ..moveTo(x - w * scale, baseY)
        ..quadraticBezierTo(
          x - w * scale + sway,
          baseY - h * scale * 0.55,
          x + sway * 1.6,
          baseY - h * scale,
        )
        ..quadraticBezierTo(
          x + w * scale + sway,
          baseY - h * scale * 0.55,
          x + w * scale,
          baseY,
        )
        ..close();

      c.drawPath(tongue(1), Paint()..color = const Color(0x99FF6A1F));
      c.drawPath(tongue(0.62), Paint()..color = const Color(0xCCFFC533));
      c.drawPath(tongue(0.3), Paint()..color = const Color(0xE6FFF3B0));
    }

    // Тлеющие угольки, поднимающиеся над бойцом.
    for (var i = 0; i < 5; i++) {
      final localPhase = (t * 1.5 + i / 5) % 1;
      final x = body.left + body.width * (0.15 + 0.7 * ((i * 7) % 5) / 4);
      final y = baseY - body.height * (0.9 + 1.3 * localPhase);
      c.drawCircle(
        Offset(x, y),
        body.width * 0.016 * (1 - localPhase),
        Paint()
          ..color = const Color(0xFFFFB03A).withValues(alpha: 1 - localPhase),
      );
    }
  }

  /// Купол щита вокруг бойца.
  void _shield(Canvas c, double t) {
    final rect = Rect.fromCenter(
      center: Offset(body.center.dx, body.center.dy - body.height * 0.1),
      width: body.width * 1.18,
      height: body.height * 2.6,
    );
    final pulse = 0.75 + 0.25 * sin(t * 2 * pi);
    c.drawOval(
      rect,
      Paint()
        ..shader = RadialGradient(
          colors: [
            GameColors.blue.withValues(alpha: 0.04 * pulse),
            GameColors.blue.withValues(alpha: 0.3 * pulse),
          ],
          stops: const [0.6, 1],
        ).createShader(rect),
    );
    c.drawOval(
      rect,
      Paint()
        ..color = GameColors.blue.withValues(alpha: 0.75 * pulse)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
    // Блик, бегущий по куполу.
    final a = t * 2 * pi;
    c.drawCircle(
      Offset(
        rect.center.dx + cos(a) * rect.width / 2,
        rect.center.dy + sin(a) * rect.height / 2,
      ),
      body.width * 0.03,
      Paint()..color = Colors.white.withValues(alpha: 0.8 * pulse),
    );
  }

  /// Зелёные искры вверх — лечение.
  void _heal(Canvas c, double t) {
    const count = 6;
    for (var i = 0; i < count; i++) {
      final localPhase = (t * 2 + i / count) % 1;
      final x = body.left + body.width * (0.12 + 0.76 * ((i * 3) % 5) / 4);
      final y = body.bottom - body.height * (0.1 + 2.4 * localPhase);
      final alpha = (1 - localPhase).clamp(0.0, 1.0);
      final r = body.width * 0.026 * (1 - localPhase * 0.4);
      // Маленькие кресты — читаются как лечение лучше точек.
      final paint = Paint()
        ..color = GameColors.green.withValues(alpha: alpha)
        ..strokeWidth = r * 0.8
        ..strokeCap = StrokeCap.round;
      c.drawLine(Offset(x - r, y), Offset(x + r, y), paint);
      c.drawLine(Offset(x, y - r), Offset(x, y + r), paint);
    }
  }

  @override
  bool shouldRepaint(_EffectsPainter old) =>
      old.effects.length != effects.length ||
      !old.effects.containsAll(effects) ||
      old.body != body ||
      old.phase != phase;
}
