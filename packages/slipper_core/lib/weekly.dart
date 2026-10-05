/// Еженедельные призы арены: итоги подводятся в понедельник в 00:00
/// по Москве, места 1–50 получают нитки и монеты, топ-20 — ещё и карту
/// выбора тапка.
library;

/// Карта выбора тапка: в инвентаре, по нажатию — любой тапок на выбор.
enum PickCard {
  /// Любой тапок, включая мифические.
  superCard('Супер карта выбора', 'Любой тапок на выбор, даже мифический'),

  /// Любой тапок, кроме мифических.
  normal('Карта выбора', 'Любой тапок на выбор, кроме мифических');

  const PickCard(this.title, this.description);
  final String title;
  final String description;

  static PickCard? byName(String? name) {
    for (final c in values) {
      if (c.name == name) return c;
    }
    return null;
  }
}

class WeeklyPrize {
  const WeeklyPrize({required this.threads, required this.coins, this.card});

  final int threads;
  final int coins;
  final PickCard? card;

  /// Сколько мест награждается.
  static const places = 50;

  /// Приз за место [place] (1 — первое); null — без приза.
  static WeeklyPrize? forPlace(int place) {
    if (place < 1 || place > places) return null;
    return switch (place) {
      1 => const WeeklyPrize(threads: 15000, coins: 1500, card: PickCard.superCard),
      2 => const WeeklyPrize(threads: 12000, coins: 1200, card: PickCard.superCard),
      3 => const WeeklyPrize(threads: 10000, coins: 1000, card: PickCard.superCard),
      <= 10 => const WeeklyPrize(threads: 7000, coins: 700, card: PickCard.superCard),
      <= 20 => const WeeklyPrize(threads: 4000, coins: 400, card: PickCard.normal),
      <= 30 => const WeeklyPrize(threads: 2500, coins: 250),
      _ => const WeeklyPrize(threads: 1500, coins: 150),
    };
  }

  /// Группы мест для таблицы призов: (с, по, приз).
  static final List<(int, int, WeeklyPrize)> table = [
    (1, 1, forPlace(1)!),
    (2, 2, forPlace(2)!),
    (3, 3, forPlace(3)!),
    (4, 10, forPlace(4)!),
    (11, 20, forPlace(11)!),
    (21, 30, forPlace(21)!),
    (31, 50, forPlace(31)!),
  ];

  Map<String, dynamic> toJson() => {
        'threads': threads,
        'coins': coins,
        'card': ?card?.name,
      };

  factory WeeklyPrize.fromJson(Map<String, dynamic> j) => WeeklyPrize(
        threads: (j['threads'] as num?)?.toInt() ?? 0,
        coins: (j['coins'] as num?)?.toInt() ?? 0,
        card: PickCard.byName(j['card'] as String?),
      );
}

/// Неделя арены: с понедельника 00:00 по Москве (UTC+3, без перевода часов).
class ArenaWeek {
  ArenaWeek._();

  static const _msk = Duration(hours: 3);

  /// Начало недели, в которую попадает [now], — в UTC.
  static DateTime startOf(DateTime now) {
    final m = now.toUtc().add(_msk);
    final day = DateTime.utc(m.year, m.month, m.day);
    return day.subtract(Duration(days: day.weekday - 1)).subtract(_msk);
  }

  /// Конец недели (начало следующей) — в UTC.
  static DateTime endOf(DateTime now) => startOf(now).add(const Duration(days: 7));

  /// Ключ недели: дата понедельника по Москве, `2026-10-05`.
  static String keyOf(DateTime now) {
    final m = startOf(now).add(_msk);
    String two(int v) => v.toString().padLeft(2, '0');
    return '${m.year}-${two(m.month)}-${two(m.day)}';
  }

  /// Ключ прошлой недели.
  static String previousKey(DateTime now) =>
      keyOf(startOf(now).subtract(const Duration(days: 1)));
}
