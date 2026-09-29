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
    QuestSpec(kind: QuestKind.arenaFights, title: 'Проведи 3 боя на арене', target: 3, coins: 30),
    QuestSpec(kind: QuestKind.storyWins, title: 'Выиграй 2 боя в сюжете', target: 2, coins: 30),
    QuestSpec(kind: QuestKind.openCases, title: 'Открой кейс', target: 1, coins: 25),
    QuestSpec(kind: QuestKind.upgrades, title: 'Прокачай тапок 10 раз', target: 10, coins: 30),
    QuestSpec(kind: QuestKind.chest, title: 'Забери сундук дежурства', target: 1, coins: 20),
  ];

  /// Задания дня: первое всегда «Проведи 3 боя на арене», остальные —
  /// случайные по дате: весь день одни и те же, от перезапуска не меняются.
  static List<QuestSpec> forDay(DateTime now) {
    final first = pool.firstWhere((q) => q.kind == QuestKind.arenaFights);
    final rest = [for (final q in pool) if (q != first) q]..shuffle(Random(dayNumber(now)));
    return [first, ...rest.take(perDay - 1)];
  }
}

/// Номер дня по календарю — сид для всего, что обновляется ежедневно.
int dayNumber(DateTime now) =>
    DateTime.utc(now.year, now.month, now.day).millisecondsSinceEpoch ~/ Duration.millisecondsPerDay;

/// Задание мини-игры «Под диваном»: награда — взмахи тапком.
class DigTask {
  const DigTask({required this.kind, required this.title, required this.target, required this.swings});

  final QuestKind kind;
  final String title;
  final int target;
  final int swings;
}

class DigTasks {
  DigTasks._();

  /// Каждый день одни и те же: вместе дают ещё 10 взмахов.
  static const all = [
    DigTask(kind: QuestKind.arenaFights, title: 'Проведи 3 боя на арене', target: 3, swings: 4),
    DigTask(kind: QuestKind.storyWins, title: 'Выиграй бой в сюжете', target: 1, swings: 3),
    DigTask(kind: QuestKind.chest, title: 'Забери сундук дежурства', target: 1, swings: 3),
  ];
}
