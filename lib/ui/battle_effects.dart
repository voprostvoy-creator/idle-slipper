import 'dart:math';

import 'package:flutter/material.dart';

import 'theme.dart';

/// Что сейчас происходит с бойцом — рисуется поверх его спрайта.
enum BattleEffect {
  /// Пропускает ход: звёзды кружат над бойцом.
  stun,

  /// Горит: языки пламени лижут снизу.
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
  const BattleEffectsLayer({super.key, required this.effects, required this.size});

  final Set<BattleEffect> effects;
  final Size size;

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
        painter: _EffectsPainter(effects: widget.effects, phase: _c),
      ),
    );
  }
}

class _EffectsPainter extends CustomPainter {
  _EffectsPainter({required this.effects, required this.phase})
      : super(repaint: phase);

  final Set<BattleEffect> effects;
  final Animation<double> phase;

  @override
  void paint(Canvas c, Size size) {
    final t = phase.value;
    // Щит рисуется под остальным, звёзды — поверх всего.
    if (effects.contains(BattleEffect.shield)) _shield(c, size, t);
    if (effects.contains(BattleEffect.burn)) _burn(c, size, t);
    if (effects.contains(BattleEffect.heal)) _heal(c, size, t);
    if (effects.contains(BattleEffect.stun)) _stun(c, size, t);
  }

  /// Звёзды по кругу над бойцом — классический знак оглушения.
  void _stun(Canvas c, Size size, double t) {
    final center = Offset(size.width / 2, size.height * 0.16);
    final rx = size.width * 0.2;
    final ry = size.height * 0.09;
    const count = 3;
    for (var i = 0; i < count; i++) {
      final a = (t + i / count) * 2 * pi;
      final p = Offset(center.dx + cos(a) * rx, center.dy + sin(a) * ry);
      // Дальние звёзды мельче — получается объём.
      final depth = (sin(a) + 1) / 2;
      final r = size.width * (0.028 + 0.018 * depth);
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

  /// Пламя у подошвы: несколько язычков, колышутся вразнобой.
  void _burn(Canvas c, Size size, double t) {
    final baseY = size.height * 0.92;
    const tongues = 5;
    for (var i = 0; i < tongues; i++) {
      // Каждый язык живёт со своей фазой, поэтому пламя не пульсирует разом.
      final localPhase = (t * 2 + i / tongues) % 1;
      final x = size.width * (0.28 + 0.44 * i / (tongues - 1));
      final h = size.height * (0.16 + 0.12 * sin(localPhase * pi));
      final w = size.width * (0.05 + 0.02 * cos(localPhase * 2 * pi));
      final sway = sin((t * 2 + i) * 2 * pi) * size.width * 0.012;

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

      c.drawPath(tongue(1), Paint()..color = const Color(0xCCFF6A1F));
      c.drawPath(tongue(0.62), Paint()..color = const Color(0xE6FFC533));
      c.drawPath(tongue(0.3), Paint()..color = const Color(0xF2FFF3B0));
    }
    // Тлеющие угольки, поднимающиеся вверх.
    for (var i = 0; i < 4; i++) {
      final localPhase = (t * 1.5 + i / 4) % 1;
      final x = size.width * (0.32 + 0.36 * ((i * 7) % 5) / 4);
      final y = baseY - size.height * 0.3 * localPhase;
      c.drawCircle(
        Offset(x, y),
        size.width * 0.012 * (1 - localPhase),
        Paint()..color = const Color(0xFFFFB03A).withValues(alpha: 1 - localPhase),
      );
    }
  }

  /// Купол щита вокруг бойца.
  void _shield(Canvas c, Size size, double t) {
    final rect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height * 0.6),
      width: size.width * 0.88,
      height: size.height * 0.95,
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
      size.width * 0.02,
      Paint()..color = Colors.white.withValues(alpha: 0.8 * pulse),
    );
  }

  /// Зелёные искры вверх — лечение.
  void _heal(Canvas c, Size size, double t) {
    const count = 6;
    for (var i = 0; i < count; i++) {
      final localPhase = (t * 2 + i / count) % 1;
      final x = size.width * (0.3 + 0.4 * ((i * 3) % 5) / 4);
      final y = size.height * (0.9 - 0.55 * localPhase);
      final alpha = (1 - localPhase).clamp(0.0, 1.0);
      final r = size.width * 0.018 * (1 - localPhase * 0.4);
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
      old.phase != phase;
}
