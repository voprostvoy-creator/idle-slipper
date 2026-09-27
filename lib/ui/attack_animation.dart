import 'dart:math';

import 'package:flutter/material.dart';

import '../game/battle/combatant.dart';

/// Анимации атаки: каждому виду тапка — своя манера удара.
///
/// [progress] идёт 0 → 1 → 0 за один удар: на пике тапок дотягивается до
/// противника, затем возвращается на место. [reach] — расстояние в пикселях,
/// на которое он подаётся вперёд; [flip] зеркалит движение для правого бойца.
class AttackAnimation {
  AttackAnimation._();

  /// Сколько длится замах и возврат для каждого стиля.
  static Duration duration(AttackStyle style) => switch (style) {
    AttackStyle.lunge => const Duration(milliseconds: 260),
    AttackStyle.dash => const Duration(milliseconds: 210),
    AttackStyle.slam => const Duration(milliseconds: 320),
    AttackStyle.blink => const Duration(milliseconds: 240),
    AttackStyle.spin => const Duration(milliseconds: 340),
    AttackStyle.meteor => const Duration(milliseconds: 420),
    AttackStyle.stomp => const Duration(milliseconds: 360),
    AttackStyle.laser => const Duration(milliseconds: 320),
    AttackStyle.uppercut => const Duration(milliseconds: 300),
    // Таран возвращается сам, поэтому это длина всего цикла.
    AttackStyle.charge => const Duration(milliseconds: 600),
    AttackStyle.taichi => const Duration(milliseconds: 620),
  };

  /// Стили, которые сами возвращают бойца на место за один проход 0 → 1.
  /// Для них экран не проигрывает анимацию в обратную сторону: у тарана
  /// обратный ход прошёл бы через замах, то есть откатил бы назад дальше
  /// исходной точки.
  static bool returnsOnItsOwn(AttackStyle style) =>
      style == AttackStyle.charge || style == AttackStyle.taichi;

  static Widget apply({
    required AttackStyle style,
    required double progress,
    required bool flip,
    required double reach,
    required Widget child,
  }) {
    if (progress <= 0.001) return child;
    // Движение всегда «к противнику»: для правого бойца — в другую сторону.
    final dir = flip ? -1.0 : 1.0;
    return switch (style) {
      AttackStyle.lunge => _lunge(progress, dir, reach, child),
      AttackStyle.dash => _dash(progress, dir, reach, child),
      AttackStyle.slam => _slam(progress, dir, reach, child),
      AttackStyle.blink => _blink(progress, dir, reach, child),
      AttackStyle.spin => _spin(progress, dir, reach, child),
      AttackStyle.meteor => _meteor(progress, dir, reach, child),
      AttackStyle.stomp => _stomp(progress, dir, reach, child),
      AttackStyle.laser => _laser(progress, dir, reach, child),
      AttackStyle.uppercut => _uppercut(progress, dir, reach, child),
      AttackStyle.charge => _charge(progress, dir, reach, child),
      AttackStyle.taichi => _taichi(progress, dir, reach, child),
    };
  }

  /// Призыв инь-ян: тапок сам почти не двигается — приподнимается,
  /// поднимает носок и коротким кивком «бросает» знак. У цели вспыхивает
  /// вращающийся знак инь-ян — он и наносит удар.
  static Widget _taichi(double t, double dir, double reach, Widget child) {
    double x;
    double y;
    double tilt;
    if (t < 0.3) {
      final e = Curves.easeOutCubic.transform(t / 0.3);
      x = 0.05 * e;
      y = -0.2 * e;
      tilt = -0.14 * e;
    } else if (t < 0.4) {
      final e = Curves.easeOutQuart.transform((t - 0.3) / 0.1);
      x = 0.05 + 0.17 * e;
      y = -0.2 + 0.12 * e;
      tilt = -0.14 + 0.26 * e;
    } else {
      final e = Curves.easeInOutCubic.transform((t - 0.4) / 0.6);
      x = 0.22 * (1 - e);
      y = -0.08 * (1 - e);
      tilt = 0.12 * (1 - e);
    }
    final body = Transform.translate(
      offset: Offset(reach * x * dir, reach * y),
      child: Transform.rotate(
        angle: tilt * dir,
        alignment: Alignment.bottomCenter,
        child: child,
      ),
    );
    final mark = t < 0.36 ? 0.0 : ((t - 0.36) / 0.5).clamp(0.0, 1.0);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        body,
        if (mark > 0 && mark < 1)
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _YinYangMarkPainter(progress: mark, dir: dir, reach: reach),
              ),
            ),
          ),
      ],
    );
  }

  /// Базовый выпад: подаётся вперёд и клюёт носком.
  static Widget _lunge(double t, double dir, double reach, Widget child) {
    final e = Curves.easeOutBack.transform(t);
    return Transform.translate(
      offset: Offset(reach * e * dir, 0),
      child: Transform.rotate(
        angle: 0.12 * e * dir,
        alignment: Alignment.bottomCenter,
        child: child,
      ),
    );
  }

  /// Скольжение: уезжает вперёд, откинувшись назад, как в подкате.
  static Widget _dash(double t, double dir, double reach, Widget child) {
    final e = Curves.easeOutCubic.transform(t);
    return Transform.translate(
      offset: Offset(reach * 1.35 * e * dir, 0),
      child: Transform.rotate(
        // Наклон назад против хода — читается как торможение юзом.
        angle: -0.22 * e * dir,
        alignment: Alignment.bottomCenter,
        child: Transform.scale(
          scaleX: 1 + 0.12 * e,
          scaleY: 1 - 0.06 * e,
          alignment: Alignment.bottomCenter,
          child: child,
        ),
      ),
    );
  }

  /// Прыжок с ударом сверху: подскок с замахом, затем обрушивается вниз.
  static Widget _slam(double t, double dir, double reach, Widget child) {
    // Взлёт занимает чуть меньше половины, падение — быстрее и резче.
    const peak = 0.42;
    final rise = t < peak ? Curves.easeOutQuad.transform(t / peak) : 1.0;
    final fall = t < peak
        ? 0.0
        : Curves.easeInQuart.transform((t - peak) / (1 - peak));
    final height = rise - fall;
    // Вперёд смещается в основном на падении — приземляется на противника.
    final advance = rise * 0.3 + fall * 0.7;
    // На взлёте чуть откидывается назад, на падении бьёт носком вниз.
    final angle = -0.2 * rise * (1 - fall) + 0.45 * fall;
    // В самом конце — короткое приседание от удара о пол.
    final land = fall > 0.85 ? (fall - 0.85) / 0.15 : 0.0;
    return Transform.translate(
      offset: Offset(reach * 0.95 * advance * dir, -reach * 1.15 * height),
      child: Transform.rotate(
        angle: angle * dir,
        alignment: Alignment.bottomCenter,
        child: Transform.scale(
          scaleY: 1 - 0.14 * land,
          scaleX: 1 + 0.1 * land,
          alignment: Alignment.bottomCenter,
          child: child,
        ),
      ),
    );
  }

  /// Мигающий рывок: почти исчезает на месте и возникает вплотную к цели.
  static Widget _blink(double t, double dir, double reach, Widget child) {
    // Гаснет к середине рывка и вспыхивает обратно у противника.
    final fade = 1 - sin(t * pi) * 0.92;
    final e = Curves.easeOutQuint.transform(t);
    return Opacity(
      opacity: fade,
      child: Transform.translate(
        offset: Offset(reach * 1.25 * e * dir, 0),
        child: Transform.scale(
          scaleX: 1 - 0.2 * sin(t * pi),
          alignment: Alignment.center,
          child: child,
        ),
      ),
    );
  }

  /// Разворот вокруг оси: летит на противника, вращаясь как пила.
  static Widget _spin(double t, double dir, double reach, Widget child) {
    final e = Curves.easeOutCubic.transform(t);
    return Transform.translate(
      offset: Offset(reach * e * dir, -reach * 0.25 * sin(t * pi)),
      child: Transform.rotate(
        angle: 2 * pi * e * dir,
        alignment: Alignment.center,
        child: child,
      ),
    );
  }

  /// Топот: два тяжёлых шага к противнику и удар всем весом.
  static Widget _stomp(double t, double dir, double reach, Widget child) {
    // Два шага вместо трёх, и всё считается от гладких кривых — раньше
    // движение ломалось на стыках и выглядело дёрганым.
    const steps = 2;
    final phase = t * steps;
    final step = phase.floor().clamp(0, steps - 1);
    final local = (phase - step).clamp(0.0, 1.0);

    // Продвижение равномерное по всей длине, без рывков на стыках шагов.
    final advance = Curves.easeInOutCubic.transform(t);
    // Мягкий подскок внутри каждого шага; второй — заметно тяжелее.
    final hop = sin(local * pi) * (step == 0 ? 0.75 : 1.0);
    // Наклон плавно нарастает к финальному удару, без скачков.
    final press = Curves.easeInCubic.transform(t);

    return Transform.translate(
      offset: Offset(reach * advance * dir, -reach * 0.34 * hop),
      child: Transform.rotate(
        // В подскоке носок вверх, к приземлению — вниз.
        angle: (-0.14 * hop + 0.3 * press) * dir,
        alignment: Alignment.bottomCenter,
        child: Transform.scale(
          // Проседает, когда вес идёт вниз, а не на каждом шаге.
          scaleY: 1 - 0.12 * press * (1 - hop),
          alignment: Alignment.bottomCenter,
          child: child,
        ),
      ),
    );
  }

  /// Лазер: тапок задирает носок, копит заряд и бьёт лучом с отдачей.
  static Widget _laser(double t, double dir, double reach, Widget child) {
    // До 40% — накопление, дальше — выстрел.
    const chargeEnd = 0.4;
    final charge = (t / chargeEnd).clamp(0.0, 1.0);
    final fire = t <= chargeEnd ? 0.0 : (t - chargeEnd) / (1 - chargeEnd);
    // Отдача: на выстреле откидывает назад.
    final recoil = -reach * 0.35 * sin(fire * pi);
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        Positioned.fill(
          child: CustomPaint(
            painter: _LaserPainter(
              charge: charge,
              fire: fire,
              dir: dir,
              reach: reach,
            ),
          ),
        ),
        Transform.translate(
          offset: Offset(recoil * dir, 0),
          child: Transform.rotate(
            // Носок поднимается к моменту выстрела.
            angle: -0.16 * charge * dir,
            alignment: Alignment.bottomCenter,
            child: child,
          ),
        ),
      ],
    );
  }

  /// Апперкот: одно слитное движение — носок поддевает противника снизу вверх.
  static Widget _uppercut(double t, double dir, double reach, Widget child) {
    // Короткий подсед в начале, затем взмах носком по дуге вверх.
    final swing = Curves.easeOutBack.transform(t);
    final crouch = t < 0.25 ? t / 0.25 : 0.0;
    return Transform.translate(
      // Вперёд и вверх по дуге — удар идёт снизу.
      offset: Offset(reach * 0.85 * swing * dir, -reach * 0.5 * swing),
      child: Transform.rotate(
        // Носок задирается: это и есть подбив.
        angle: -0.42 * swing * dir,
        alignment: Alignment.bottomCenter,
        child: Transform.scale(
          scaleY: 1 - 0.1 * crouch,
          alignment: Alignment.bottomCenter,
          child: child,
        ),
      ),
    );
  }

  /// Таран: отходит назад, сжимается и бросается шипами вперёд, затем
  /// плавно возвращается на место — всё за один проход, без обратного хода.
  static Widget _charge(double t, double dir, double reach, Widget child) {
    const windupEnd = 0.3;
    const hitAt = 0.58;
    // Замах: отход назад и сжатие как у пружины.
    final windup = t < windupEnd
        ? Curves.easeOutCubic.transform(t / windupEnd)
        : t < hitAt
        ? 1 -
              Curves.easeInCubic.transform(
                (t - windupEnd) / (hitAt - windupEnd),
              )
        : 0.0;
    // Бросок: резкий разгон до удара, потом плавный отход прямо на место.
    final dash = t < windupEnd
        ? 0.0
        : t < hitAt
        ? Curves.easeInQuart.transform((t - windupEnd) / (hitAt - windupEnd))
        : 1 - Curves.easeInOutCubic.transform((t - hitAt) / (1 - hitAt));
    // Дистанция на 10% короче прежней: бросок 0.88, замах 0.27.
    final x = -reach * 0.27 * windup + reach * 0.88 * dash;
    return Transform.translate(
      offset: Offset(x * dir, -reach * 0.1 * windup),
      child: Transform.rotate(
        // Откидывается назад на замахе и клюёт носком в броске.
        angle: (-0.22 * windup + 0.3 * dash) * dir,
        alignment: Alignment.bottomCenter,
        child: Transform.scale(
          scaleX: 1 - 0.1 * windup + 0.14 * dash,
          scaleY: 1 - 0.08 * windup,
          alignment: Alignment.bottomCenter,
          child: child,
        ),
      ),
    );
  }

  /// Метеор: уходит вверх за кадр и падает на противника.
  static Widget _meteor(double t, double dir, double reach, Widget child) {
    // До середины — взлёт и уменьшение, после — падение с переворотом.
    final rise = t < 0.5 ? Curves.easeOutCubic.transform(t * 2) : 1.0;
    final fall = t < 0.5 ? 0.0 : Curves.easeInCubic.transform((t - 0.5) * 2);
    final height = rise - fall;
    return Transform.translate(
      offset: Offset(reach * 1.15 * fall * dir, -reach * 1.25 * height),
      child: Transform.rotate(
        angle: (0.9 * rise + 1.6 * fall) * dir,
        alignment: Alignment.center,
        child: Transform.scale(scale: 1 - 0.25 * height, child: child),
      ),
    );
  }
}

/// Радужный луч от носка тапка в сторону противника.
class _LaserPainter extends CustomPainter {
  _LaserPainter({
    required this.charge,
    required this.fire,
    required this.dir,
    required this.reach,
  });

  /// 0..1 — накопление заряда перед выстрелом.
  final double charge;

  /// 0..1 — сам выстрел.
  final double fire;

  /// 1 — луч идёт вправо, -1 — влево.
  final double dir;

  final double reach;

  static const _rainbow = [
    Color(0xFFFF4D6D),
    Color(0xFFFFB03A),
    Color(0xFFFFF35C),
    Color(0xFF5CFF8F),
    Color(0xFF4FD8FF),
    Color(0xFFB06BFF),
  ];

  @override
  void paint(Canvas c, Size size) {
    // Носок тапка: правый край спрайта, с поправкой на зеркалирование.
    final muzzle = Offset(
      size.width * (dir > 0 ? 0.82 : 0.18),
      size.height * 0.42,
    );

    if (fire <= 0) {
      if (charge <= 0) return;
      // Копим заряд — светящийся шар у носка.
      final r = reach * 0.1 * charge;
      c.drawCircle(muzzle, r * 2.4, Paint()..color = const Color(0x554FD8FF));
      c.drawCircle(
        muzzle,
        r,
        Paint()..color = Colors.white.withValues(alpha: 0.9),
      );
      return;
    }

    // Луч вспыхивает и гаснет; длины хватает до противника.
    final alpha = sin(fire * pi).clamp(0.0, 1.0);
    final len = reach * 5.5 * Curves.easeOutQuart.transform(fire);
    final end = muzzle + Offset(dir * len, 0);
    final rect = Rect.fromPoints(
      Offset(muzzle.dx, muzzle.dy - reach * 0.4),
      Offset(end.dx, end.dy + reach * 0.4),
    );
    final gradient = LinearGradient(
      begin: dir > 0 ? Alignment.centerLeft : Alignment.centerRight,
      end: dir > 0 ? Alignment.centerRight : Alignment.centerLeft,
      colors: _rainbow,
    ).createShader(rect);

    // Широкое свечение под лучом.
    c.drawLine(
      muzzle,
      end,
      Paint()
        ..shader = gradient
        ..strokeCap = StrokeCap.round
        ..strokeWidth = reach * 0.42 * alpha
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, reach * 0.12),
    );
    // Тело луча.
    c.drawLine(
      muzzle,
      end,
      Paint()
        ..shader = gradient
        ..strokeCap = StrokeCap.round
        ..strokeWidth = reach * 0.2 * alpha,
    );
    // Белое ядро.
    c.drawLine(
      muzzle,
      end,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.85 * alpha)
        ..strokeCap = StrokeCap.round
        ..strokeWidth = reach * 0.07 * alpha,
    );
    // Вспышка у носка и точка попадания.
    c.drawCircle(
      muzzle,
      reach * 0.22 * alpha,
      Paint()..color = Colors.white.withValues(alpha: 0.8 * alpha),
    );
    c.drawCircle(
      end,
      reach * 0.3 * alpha,
      Paint()..color = const Color(0xFFB06BFF).withValues(alpha: 0.7 * alpha),
    );
    c.drawCircle(
      end,
      reach * 0.14 * alpha,
      Paint()..color = Colors.white.withValues(alpha: 0.9 * alpha),
    );
  }

  @override
  bool shouldRepaint(_LaserPainter old) =>
      old.charge != charge || old.fire != fire || old.dir != dir;
}

/// Знак инь-ян у цели в момент удара: выскакивает, делает оборот и тает.
/// Размером с тапок, чтобы не перекрывать экран.
class _YinYangMarkPainter extends CustomPainter {
  _YinYangMarkPainter({
    required this.progress,
    required this.dir,
    required this.reach,
  });

  final double progress;
  final double dir;
  final double reach;

  @override
  void paint(Canvas c, Size size) {
    // У противника: там, куда дотягиваются удары других тапков.
    final center = Offset(
      size.width / 2 + dir * (reach + size.width * 0.42),
      size.height * 0.45,
    );
    final pop = Curves.easeOutBack.transform((progress / 0.3).clamp(0.0, 1.0));
    final fade = progress < 0.6 ? 1.0 : 1 - (progress - 0.6) / 0.4;
    final radius = size.height * 0.32 * pop;
    if (radius <= 0.5) return;

    c.save();
    c.translate(center.dx, center.dy);
    c.rotate(dir * 2 * pi * Curves.easeOutCubic.transform(progress));
    final light = Paint()..color = Colors.white.withValues(alpha: fade);
    final dark = Paint()
      ..color = const Color(0xFF14091F).withValues(alpha: fade);
    final whole = Rect.fromCircle(center: Offset.zero, radius: radius);

    // Светлый круг, тёмная половина с «каплей»: полукруг + малые круги.
    c.drawCircle(Offset.zero, radius, light);
    final yin = Path()
      ..addArc(whole, -pi / 2, pi)
      ..addArc(
        Rect.fromCircle(center: Offset(0, radius / 2), radius: radius / 2),
        pi / 2,
        pi,
      )
      ..close();
    c.drawPath(yin, dark);
    c.drawCircle(Offset(0, -radius / 2), radius / 2, light);
    c.drawCircle(Offset(0, radius / 2), radius / 2, dark);
    // Глазки: тёмный в светлой части, светлый в тёмной.
    c.drawCircle(Offset(0, -radius / 2), radius * 0.14, dark);
    c.drawCircle(Offset(0, radius / 2), radius * 0.14, light);
    c.drawCircle(
      Offset.zero,
      radius,
      Paint()
        ..color = const Color(0xFF14091F).withValues(alpha: fade)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    c.restore();
  }

  @override
  bool shouldRepaint(_YinYangMarkPainter old) => old.progress != progress;
}
