import 'dart:math';

import 'package:flutter/material.dart';

import '../game/battle/battle_sim.dart';
import 'theme.dart';
import 'widgets/game_widgets.dart';

/// Эффект, висящий на бойце, — то, что показывается значком под шкалой ульты.
enum StatusKind {
  shield('Щит', 'Входящий урон снижен.', positive: true),
  barrier('Барьер', 'Поглощает урон, пока не иссякнет.', positive: true),
  haste('Ускорение', 'Ходит чаще обычного.', positive: true),
  evade('Уклонение', 'Следующая атака по нему пройдёт мимо.', positive: true),
  burn('Горение', 'Теряет здоровье в начале каждого своего хода.', positive: false),
  stun('Оглушение', 'Пропустит следующий ход.', positive: false),
  weaken('Ослабление', 'Наносит меньше урона.', positive: false),
  slow('Замедление', 'Ходит реже обычного.', positive: false);

  const StatusKind(this.label, this.description, {required this.positive});

  final String label;
  final String description;

  /// Полезный эффект — зелёная рамка, вредный — красная.
  final bool positive;
}

/// Какие эффекты висят на стороне прямо сейчас: сначала полезные, потом вредные.
List<StatusKind> statusesOf(SideSnapshot s) => [
      if (s.shielded) StatusKind.shield,
      if (s.barriered) StatusKind.barrier,
      if (s.hasted) StatusKind.haste,
      if (s.evading) StatusKind.evade,
      if (s.burning) StatusKind.burn,
      if (s.stunned) StatusKind.stun,
      if (s.weakened) StatusKind.weaken,
      if (s.slowed) StatusKind.slow,
    ];

/// Значок эффекта: схематичный рисунок в круглой рамке цвета «плюс/минус».
/// По тапу — название и что делает; бой на это время встаёт.
class StatusIcon extends StatelessWidget {
  const StatusIcon({
    super.key,
    required this.kind,
    required this.onDialog,
    required this.onDialogClosed,
    this.size = 22,
  });

  final StatusKind kind;
  final double size;
  final VoidCallback onDialog;
  final VoidCallback onDialogClosed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _show(context),
      child: CustomPaint(
        size: Size.square(size),
        painter: _StatusPainter(kind),
      ),
    );
  }

  void _show(BuildContext context) {
    final theme = Theme.of(context);
    final frame = kind.positive ? GameColors.green : GameColors.red;
    onDialog();
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            CustomPaint(size: const Size.square(34), painter: _StatusPainter(kind)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GameBadge(text: kind.positive ? 'Полезный' : 'Вредный', color: frame),
                  const SizedBox(height: 6),
                  StrokeText(kind.label, size: 20, color: frame, align: TextAlign.start),
                ],
              ),
            ),
          ],
        ),
        content: Text(kind.description, style: theme.textTheme.bodyMedium),
        actions: [
          GameButton(
            color: GameColors.panelLight,
            onPressed: () => Navigator.pop(context),
            child: const Text('Понятно', style: TextStyle(color: GameColors.text)),
          ),
        ],
      ),
    ).whenComplete(onDialogClosed);
  }
}

class _StatusPainter extends CustomPainter {
  _StatusPainter(this.kind);

  final StatusKind kind;

  @override
  void paint(Canvas c, Size size) {
    final s = size.width;
    final center = Offset(s / 2, s / 2);
    final frame = kind.positive ? GameColors.green : GameColors.red;

    // Подложка и рамка «плюс/минус».
    c.drawCircle(center, s / 2, Paint()..color = GameColors.outline);
    c.drawCircle(center, s / 2 - s * 0.06, Paint()..color = GameColors.panelDark);
    c.drawCircle(
      center,
      s / 2 - s * 0.1,
      Paint()
        ..color = frame
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.09,
    );

    switch (kind) {
      case StatusKind.shield:
        _shield(c, s);
      case StatusKind.barrier:
        _barrier(c, s);
      case StatusKind.haste:
        _haste(c, s);
      case StatusKind.evade:
        _evade(c, s);
      case StatusKind.burn:
        _burn(c, s);
      case StatusKind.stun:
        _stun(c, s);
      case StatusKind.weaken:
        _weaken(c, s);
      case StatusKind.slow:
        _slow(c, s);
    }
  }

  Paint _fill(Color color) => Paint()..color = color;

  Paint _line(Color color, double width) => Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  /// Щит — геральдический силуэт.
  void _shield(Canvas c, double s) {
    final p = Path()
      ..moveTo(s * 0.5, s * 0.24)
      ..lineTo(s * 0.72, s * 0.33)
      ..quadraticBezierTo(s * 0.72, s * 0.62, s * 0.5, s * 0.77)
      ..quadraticBezierTo(s * 0.28, s * 0.62, s * 0.28, s * 0.33)
      ..close();
    c.drawPath(p, _fill(GameColors.blue));
    c.drawLine(Offset(s * 0.5, s * 0.3), Offset(s * 0.5, s * 0.7),
        _line(GameColors.blueDark, s * 0.06));
  }

  /// Барьер — кристалл-шестигранник с бликом.
  void _barrier(Canvas c, double s) {
    Path hex(double r) {
      final p = Path();
      for (var i = 0; i < 6; i++) {
        final a = -pi / 2 + i * pi / 3;
        final pt = Offset(s / 2 + cos(a) * r, s / 2 + sin(a) * r);
        i == 0 ? p.moveTo(pt.dx, pt.dy) : p.lineTo(pt.dx, pt.dy);
      }
      return p..close();
    }

    c.drawPath(hex(s * 0.25), _fill(const Color(0xFF4FE3D0)));
    c.drawPath(hex(s * 0.13), _fill(Colors.white.withValues(alpha: 0.7)));
  }

  /// Ускорение — двойной шеврон вперёд.
  void _haste(Canvas c, double s) {
    final paint = _line(GameColors.gold, s * 0.1);
    for (final dx in [0.0, s * 0.18]) {
      c.drawPath(
        Path()
          ..moveTo(s * 0.3 + dx, s * 0.32)
          ..lineTo(s * 0.44 + dx, s * 0.5)
          ..lineTo(s * 0.3 + dx, s * 0.68),
        paint,
      );
    }
  }

  /// Уклонение — два завитка ветра.
  void _evade(Canvas c, double s) {
    final paint = _line(const Color(0xFFB8F5D8), s * 0.08);
    c.drawPath(
      Path()
        ..moveTo(s * 0.26, s * 0.4)
        ..lineTo(s * 0.58, s * 0.4)
        ..arcToPoint(Offset(s * 0.58, s * 0.26), radius: Radius.circular(s * 0.07)),
      paint,
    );
    c.drawPath(
      Path()
        ..moveTo(s * 0.26, s * 0.58)
        ..lineTo(s * 0.66, s * 0.58)
        ..arcToPoint(Offset(s * 0.66, s * 0.74),
            radius: Radius.circular(s * 0.08), clockwise: true),
      paint,
    );
  }

  /// Горение — язык пламени с жёлтой сердцевиной.
  void _burn(Canvas c, double s) {
    Path flame(double k) => Path()
      ..moveTo(s * 0.5, s * (0.5 - 0.3 * k))
      ..quadraticBezierTo(s * (0.5 + 0.26 * k), s * 0.5, s * (0.5 + 0.18 * k), s * 0.66)
      ..quadraticBezierTo(s * 0.5, s * (0.66 + 0.12 * k), s * (0.5 - 0.18 * k), s * 0.66)
      ..quadraticBezierTo(s * (0.5 - 0.26 * k), s * 0.5, s * 0.5, s * (0.5 - 0.3 * k))
      ..close();
    c.drawPath(flame(1), _fill(const Color(0xFFFF6A1F)));
    c.drawPath(flame(0.55), _fill(const Color(0xFFFFD34D)));
  }

  /// Оглушение — две звезды.
  void _stun(Canvas c, double s) {
    _star(c, Offset(s * 0.44, s * 0.45), s * 0.19);
    _star(c, Offset(s * 0.66, s * 0.66), s * 0.11);
  }

  void _star(Canvas c, Offset o, double r) {
    final p = Path();
    for (var i = 0; i < 10; i++) {
      final a = -pi / 2 + i * pi / 5;
      final rad = i.isEven ? r : r * 0.45;
      final pt = o + Offset(cos(a), sin(a)) * rad;
      i == 0 ? p.moveTo(pt.dx, pt.dy) : p.lineTo(pt.dx, pt.dy);
    }
    c.drawPath(p..close(), _fill(GameColors.gold));
  }

  /// Ослабление — стрелка вниз.
  void _weaken(Canvas c, double s) {
    const color = Color(0xFFC77DFF);
    c.drawLine(Offset(s * 0.5, s * 0.26), Offset(s * 0.5, s * 0.6), _line(color, s * 0.11));
    c.drawPath(
      Path()
        ..moveTo(s * 0.32, s * 0.52)
        ..lineTo(s * 0.68, s * 0.52)
        ..lineTo(s * 0.5, s * 0.76)
        ..close(),
      _fill(color),
    );
  }

  /// Замедление — песочные часы.
  void _slow(Canvas c, double s) {
    final frame = _line(GameColors.blue, s * 0.07);
    c.drawLine(Offset(s * 0.32, s * 0.27), Offset(s * 0.68, s * 0.27), frame);
    c.drawLine(Offset(s * 0.32, s * 0.73), Offset(s * 0.68, s * 0.73), frame);
    // Колба.
    c.drawPath(
      Path()
        ..moveTo(s * 0.36, s * 0.3)
        ..lineTo(s * 0.64, s * 0.3)
        ..lineTo(s * 0.52, s * 0.5)
        ..lineTo(s * 0.64, s * 0.7)
        ..lineTo(s * 0.36, s * 0.7)
        ..lineTo(s * 0.48, s * 0.5)
        ..close(),
      _line(GameColors.blue, s * 0.05),
    );
    // Песок внизу.
    c.drawPath(
      Path()
        ..moveTo(s * 0.4, s * 0.68)
        ..lineTo(s * 0.6, s * 0.68)
        ..lineTo(s * 0.5, s * 0.56)
        ..close(),
      _fill(const Color(0xFFF2DEB4)),
    );
  }

  @override
  bool shouldRepaint(_StatusPainter old) => old.kind != kind;
}
