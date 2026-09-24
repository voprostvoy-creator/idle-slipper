import 'dart:ui';

import 'skills.dart';

/// Как боец бьёт в бою. У каждого вида своя манера.
enum AttackStyle {
  /// Выпад вперёд с наклоном — базовый удар.
  lunge,

  /// Скольжение: резкий рывок с откидыванием назад.
  dash,

  /// Прыжок и удар сверху вниз.
  slam,

  /// Мигающий рывок: гаснет на месте, появляется у цели.
  blink,

  /// Разворот вокруг оси на ходу.
  spin,

  /// Уход вверх и падение на противника.
  meteor,

  /// Тяжёлые шаги к противнику с топотом.
  stomp,

  /// Выстрел лучом с отдачей.
  laser,

  /// Двойка: два быстрых выпада подряд.
  combo,

  /// Таран: замах назад и стремительный рывок вперёд.
  charge,
}

/// Свечение вокруг бойца: цвет и насыщенность 0..1.
class AuraSpec {
  const AuraSpec({required this.color, required this.strength});
  final Color color;
  final double strength;
}

/// Всё, что движку боя и экрану нужно знать об участнике боя.
///
/// Тапок игрока и противник-насекомое из сюжета реализуют один интерфейс,
/// поэтому `BattleSim` не знает, кто именно дерётся.
abstract class Combatant {
  String get name;

  /// PNG бойца: прозрачный фон, смотрит вправо.
  String get asset;

  AttackStyle get attackStyle;

  double get maxHp;
  double get attack;
  double get defense;
  double get speed;
  double get dodgeChance;
  double get critChance;

  /// Во сколько раз спрайт рисуется меньше своего бокса.
  double get sizeFactor => 1;

  /// Аура прокачки; у противников без прокачки её нет.
  AuraSpec? get aura => null;

  SkillSet get skills;
}
