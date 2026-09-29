import '../slipper.dart';
import 'enemies.dart';

/// Один бой главы.
class Stage {
  const Stage({
    required this.kind,
    required this.levels,
    required this.threads,
    required this.coins,
    this.name,
    this.elite = false,
    this.boss = false,
    this.rewardKindId,
  });

  final EnemyKind kind;

  /// Уровни статов противника: удар, прочность, здоровье, скорость.
  final (int, int, int, int) levels;

  /// Нитки за первую победу. Повтор даёт треть.
  final int threads;

  /// Монеты — только за первую победу.
  final int coins;

  /// Своё имя у элитных версий; иначе — имя вида.
  final String? name;
  final bool elite;
  final bool boss;

  /// Тапок, который гарантированно выпадает за первую победу.
  final String? rewardKindId;

  /// Повторная победа: треть ниток, без монет.
  int get replayThreads => (threads / 3).round();

  Enemy get enemy {
    final (a, d, h, s) = levels;
    return Enemy(
      kind: kind,
      levels: {Stat.attack: a, Stat.defense: d, Stat.health: h, Stat.speed: s},
      name: name,
      elite: elite,
      boss: boss,
    );
  }
}

class Chapter {
  const Chapter({
    required this.id,
    required this.number,
    required this.title,
    required this.intro,
    required this.stages,
  });

  final String id;
  final int number;
  final String title;
  final String intro;
  final List<Stage> stages;
}

class StoryCatalog {
  StoryCatalog._();

  static const chapter1 = Chapter(
    id: 'kitchen',
    number: 1,
    title: 'Ночная кухня',
    intro: 'Ночью на кухне завелись насекомые. Тапок выходит на дежурство.',
    stages: [
      Stage(kind: EnemyCatalog.fly, levels: (1, 1, 1, 1), threads: 30, coins: 10),
      Stage(kind: EnemyCatalog.cockroach, levels: (1, 1, 2, 1), threads: 35, coins: 12),
      Stage(kind: EnemyCatalog.mosquito, levels: (2, 1, 2, 2), threads: 40, coins: 15),
      Stage(kind: EnemyCatalog.cockroach, levels: (3, 2, 3, 2), threads: 45, coins: 18),
      Stage(kind: EnemyCatalog.rhinoBeetle, levels: (4, 5, 4, 1), threads: 60, coins: 30),
      Stage(
        kind: EnemyCatalog.fly,
        levels: (4, 3, 4, 5),
        threads: 60, coins: 25,
        name: 'Жирная муха',
        elite: true,
      ),
      Stage(
        kind: EnemyCatalog.mosquito,
        levels: (5, 3, 5, 6),
        threads: 70, coins: 30,
        name: 'Кровосос',
        elite: true,
      ),
      Stage(
        kind: EnemyCatalog.rhinoBeetle,
        levels: (7, 8, 7, 2),
        threads: 80, coins: 35,
        name: 'Бронированный жук',
        elite: true,
      ),
      Stage(
        kind: EnemyCatalog.cockroach,
        levels: (7, 5, 7, 5),
        threads: 100, coins: 40,
        name: 'Таракан-ветеран',
        elite: true,
      ),
      Stage(
        kind: EnemyCatalog.roachKing,
        levels: (8, 7, 8, 5),
        threads: 250, coins: 100,
        boss: true,
        rewardKindId: 'blue_slide',
      ),
    ],
  );

  static const chapter2 = Chapter(
    id: 'bathroom',
    number: 2,
    title: 'Ванная',
    intro: 'Уцелевшие жуки сбежали в сырую ванную. Здесь водятся твари похитрее: '
        'яд, паутина и слизь.',
    stages: [
      Stage(kind: EnemyCatalog.silverfish, levels: (8, 6, 8, 9), threads: 60, coins: 20),
      Stage(kind: EnemyCatalog.woodlouse, levels: (9, 8, 9, 7), threads: 70, coins: 24),
      Stage(kind: EnemyCatalog.spider, levels: (10, 8, 10, 9), threads: 80, coins: 28),
      Stage(kind: EnemyCatalog.silverfish, levels: (10, 8, 10, 10), threads: 90, coins: 32),
      Stage(kind: EnemyCatalog.slug, levels: (11, 10, 12, 8), threads: 120, coins: 50),
      Stage(
        kind: EnemyCatalog.silverfish,
        levels: (12, 10, 12, 13),
        threads: 120, coins: 45,
        name: 'Серебряная чешуйница',
        elite: true,
      ),
      Stage(
        kind: EnemyCatalog.woodlouse,
        levels: (12, 13, 13, 9),
        threads: 140, coins: 50,
        name: 'Панцирная мокрица',
        elite: true,
      ),
      Stage(
        kind: EnemyCatalog.spider,
        levels: (13, 11, 13, 12),
        threads: 160, coins: 60,
        name: 'Ядовитый паук',
        elite: true,
      ),
      Stage(
        kind: EnemyCatalog.slug,
        levels: (14, 12, 15, 10),
        threads: 200, coins: 70,
        name: 'Королевский слизень',
        elite: true,
      ),
      Stage(
        kind: EnemyCatalog.spiderQueen,
        levels: (15, 13, 16, 12),
        threads: 500, coins: 200,
        boss: true,
        rewardKindId: 'purple_neon',
      ),
    ],
  );

  static const chapters = [chapter1, chapter2];
}
