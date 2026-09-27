import 'dart:math';

import 'slipper.dart';

/// Участник рейтинга арены — снимок чужого тапка и его очки.
class LeaderboardEntry {
  const LeaderboardEntry({required this.slipper, required this.rating});

  final Slipper slipper;
  final int rating;

  String get name => slipper.name;
}

/// Рейтинг арены. Пока без сервера: 20 заготовленных тапков разной силы,
/// их очки не меняются. Игрок встаёт между ними по своим очкам.
class Leaderboard {
  Leaderboard._();

  /// (имя, вид, средний уровень статов, звёзды, очки) — сверху самые сильные.
  static const _bots = [
    ('Тапочный Император', 'rainbow', 40, 5, 2600),
    ('Шлёпа Легенда', 'red_spike', 34, 4, 2450),
    ('Банный Ураган', 'purple_neon', 29, 4, 2300),
    ('Меховой Молот', 'carbon_sport', 25, 3, 2180),
    ('Гроза Кухни', 'red_spike', 22, 3, 2060),
    ('Резиновый Мститель', 'blue_slide', 19, 3, 1950),
    ('Левый Шершень', 'purple_neon', 17, 2, 1850),
    ('Пляжный Кара', 'carbon_sport', 15, 2, 1760),
    ('Бабушкин Разрушитель', 'basic', 13, 2, 1670),
    ('Гостевой Пыльник', 'blue_slide', 12, 2, 1590),
    ('Правый Тихоня', 'carbon_sport', 10, 1, 1510),
    ('Домашний Уют', 'basic', 9, 1, 1430),
    ('Тапыч Комнатный', 'blue_slide', 8, 1, 1360),
    ('Неоновый Шлёпатель', 'purple_neon', 7, 1, 1290),
    ('Банный Тихоня', 'basic', 6, 0, 1220),
    ('Мокрый Шлёпа', 'blue_slide', 5, 0, 1150),
    ('Пыльный Тапок', 'basic', 4, 0, 1090),
    ('Левый Резиновый', 'basic', 3, 0, 1040),
    ('Сонный Тапок', 'basic', 2, 0, 960),
    ('Новичок Шлёпа', 'basic', 1, 0, 880),
  ];

  /// Боты по убыванию очков. У каждого свой «билд» — уровни раскиданы
  /// по статам неравномерно, но всегда одинаково.
  static final List<LeaderboardEntry> bots = [
    for (final (i, (name, kind, avg, stars, rating)) in _bots.indexed)
      LeaderboardEntry(
        slipper: Slipper(
          name: name,
          kindId: kind,
          levels: _build(avg, Random(i * 31 + 7)),
          stars: stars,
        ),
        rating: rating,
      ),
  ];

  static Map<Stat, int> _build(int avg, Random rng) {
    final total = avg * Stat.values.length;
    final weights = [for (final _ in Stat.values) 0.6 + rng.nextDouble() * 0.8];
    final sum = weights.reduce((a, b) => a + b);
    final levels = {
      for (final (k, s) in Stat.values.indexed)
        s: max(1, (total * weights[k] / sum).round()),
    };
    return levels;
  }

  /// Место игрока: сколько ботов выше него, плюс один.
  /// При равных очках игрок стоит выше.
  static int placeOf(int rating) => bots.where((b) => b.rating > rating).length + 1;

  static int get size => bots.length + 1;

  /// Соперник — тот, кто стоит в рейтинге сразу над игроком.
  /// Лидеру достаётся второй номер.
  static LeaderboardEntry nextOpponent(int rating) {
    final above = bots.where((b) => b.rating > rating);
    return above.isEmpty ? bots.first : above.last;
  }
}
