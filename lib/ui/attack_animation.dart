import 'dart:math';

import 'package:flutter/material.dart';

import '../game/slipper_kind.dart';

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
      };

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
    };
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

  /// Прыжок с ударом сверху: взлетает по дуге и обрушивается носком вниз.
  static Widget _slam(double t, double dir, double reach, Widget child) {
    // Первая половина — подъём, вторая — падение на цель.
    final up = sin(t * pi);
    final e = Curves.easeInCubic.transform(t);
    return Transform.translate(
      offset: Offset(reach * 0.95 * e * dir, -reach * 0.85 * up),
      child: Transform.rotate(
        angle: 0.7 * e * dir,
        alignment: Alignment.center,
        child: child,
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
        child: Transform.scale(
          scale: 1 - 0.25 * height,
          child: child,
        ),
      ),
    );
  }
}
