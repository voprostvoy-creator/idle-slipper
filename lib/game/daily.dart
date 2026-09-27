import 'dart:math';

/// Всё, что обновляется со временем: ежедневный кейс и задания. Чистая логика — текущее время передаётся снаружи, чтобы её
/// можно было проверять тестами.

/// Ключ календарного дня по местному времени: новый день — с полуночи.
String dayKey(DateTime now) =>
    '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

/// Сколько осталось до полуночи — до обновления кейса и заданий.
Duration untilMidnight(DateTime now) =>
    DateTime(now.year, now.month, now.day + 1).difference(now);

/// Что считают задания.
enum QuestKind { arenaWins, arenaFights, storyWins, openCases, upgrades, chest }

class QuestSpec {
  const QuestSpec({
    required this.kind,
    required this.title,
    required this.target,
    required this.coins,
  });

  final QuestKind kind;
  final String title;
  final int target;
  final int coins;
}

class DailyQuests {
  DailyQuests._();

  /// Сколько заданий в день.
  static const perDay = 3;

  /// Награда, когда получены все задания дня.
  static const bonusCoins = 50;

  static const pool = [
    QuestSpec(kind: QuestKind.arenaWins, title: 'Победи на арене 3 раза', target: 3, coins: 40),
    QuestSpec(kind: QuestKind.arenaFights, title: 'Проведи 5 боёв на арене', target: 5, coins: 30),
    QuestSpec(kind: QuestKind.storyWins, title: 'Выиграй 2 боя в сюжете', target: 2, coins: 30),
    QuestSpec(kind: QuestKind.openCases, title: 'Открой кейс', target: 1, coins: 25),
    QuestSpec(kind: QuestKind.upgrades, title: 'Прокачай тапок 10 раз', target: 10, coins: 30),
    QuestSpec(kind: QuestKind.chest, title: 'Забери сундук дежурства', target: 1, coins: 20),
  ];

  /// Задания дня. Набор зависит только от даты — одинаков весь день
  /// и не меняется от перезапуска.
  static List<QuestSpec> forDay(DateTime now) {
    final day = DateTime.utc(now.year, now.month, now.day).millisecondsSinceEpoch ~/
        Duration.millisecondsPerDay;
    final picks = [...pool]..shuffle(Random(day));
    return picks.take(perDay).toList();
  }
}
