import 'dart:math';

import 'slipper_kind.dart';
import 'stars.dart';
import 'story/enemies.dart';

/// «Оборона кухни» — tower defense: насекомые ползут по тропе к сахарнице,
/// тапки из коллекции стоят по бокам и бьют их. Чистая логика без Flutter:
/// экран вызывает [DefenseGame.step] каждый кадр и рисует состояние.

/// Клетка поля.
typedef Cell = ({int col, int row});

class DefenseMap {
  DefenseMap._();

  static const cols = 7;
  static const rows = 11;

  /// Изгибы тропы в клетках: от входа слева сверху змейкой к сахарнице.
  static const waypoints = <(double, double)>[
    (-1, 1),
    (5, 1),
    (5, 4),
    (1, 4),
    (1, 7),
    (5, 7),
    (5, 10),
  ];

  /// Клетки, по которым идёт тропа, — на них тапки не ставятся.
  static final Set<Cell> path = () {
    final cells = <Cell>{};
    for (var i = 0; i < waypoints.length - 1; i++) {
      final (x0, y0) = waypoints[i];
      final (x1, y1) = waypoints[i + 1];
      final steps = max((x1 - x0).abs(), (y1 - y0).abs()).round();
      for (var s = 0; s <= steps; s++) {
        final x = (x0 + (x1 - x0) * s / steps).round();
        final y = (y0 + (y1 - y0) * s / steps).round();
        if (x >= 0 && x < cols && y >= 0 && y < rows) cells.add((col: x, row: y));
      }
    }
    return cells;
  }();

  /// Сахарница — конец тропы.
  static const Cell sugar = (col: 5, row: 10);

  static final double length = () {
    var l = 0.0;
    for (var i = 0; i < waypoints.length - 1; i++) {
      final (x0, y0) = waypoints[i];
      final (x1, y1) = waypoints[i + 1];
      l += (x1 - x0).abs() + (y1 - y0).abs();
    }
    return l;
  }();

  /// Точка на тропе через [d] клеток пути от входа (центр клетки — x+0.5).
  static (double, double) pointAt(double d) {
    var left = d;
    for (var i = 0; i < waypoints.length - 1; i++) {
      final (x0, y0) = waypoints[i];
      final (x1, y1) = waypoints[i + 1];
      final seg = (x1 - x0).abs() + (y1 - y0).abs();
      if (left <= seg) {
        final t = seg == 0 ? 0 : left / seg;
        return (x0 + (x1 - x0) * t + 0.5, y0 + (y1 - y0) * t + 0.5);
      }
      left -= seg;
    }
    final (x, y) = waypoints.last;
    return (x + 0.5, y + 0.5);
  }

  /// Направление по горизонтали на этом участке: −1 влево, 1 вправо, 0 вниз.
  static int dirAt(double d) {
    var left = d;
    for (var i = 0; i < waypoints.length - 1; i++) {
      final (x0, y0) = waypoints[i];
      final (x1, y1) = waypoints[i + 1];
      final seg = (x1 - x0).abs() + (y1 - y0).abs();
      if (left <= seg) return (x1 - x0).sign.toInt();
      left -= seg;
    }
    return 0;
  }
}

/// Чем тапок бьёт в обороне.
enum TowerRole { strike, slow, splash, chain, poison, beam, stunner }

/// Характеристики тапка-защитника по виду.
class TowerSpec {
  const TowerSpec({
    required this.role,
    required this.damage,
    required this.range,
    required this.cooldown,
    required this.label,
  });

  final TowerRole role;

  /// Урон за удар до множителя редкости, звёзд и уровня.
  final double damage;

  /// Дальность в клетках.
  final double range;

  /// Секунд между ударами.
  final double cooldown;

  /// Что делает — для подсказки.
  final String label;

  static TowerSpec of(String kindId) => switch (kindId) {
        'blue_slide' => const TowerSpec(
            role: TowerRole.slow, damage: 10, range: 1.8, cooldown: 0.9,
            label: 'Замедляет жуков на 40%'),
        'carbon_sport' => const TowerSpec(
            role: TowerRole.splash, damage: 14, range: 1.6, cooldown: 1.4,
            label: 'Бьёт по площади'),
        'purple_neon' => const TowerSpec(
            role: TowerRole.chain, damage: 10, range: 2.0, cooldown: 1.1,
            label: 'Молния по трём целям'),
        'red_spike' => const TowerSpec(
            role: TowerRole.poison, damage: 9, range: 1.8, cooldown: 1.0,
            label: 'Отравляет: урон 3 секунды'),
        'rainbow' => const TowerSpec(
            role: TowerRole.beam, damage: 26, range: 3.2, cooldown: 1.3,
            label: 'Луч дальнего боя'),
        'yin_yang' => const TowerSpec(
            role: TowerRole.stunner, damage: 22, range: 2.0, cooldown: 1.0,
            label: 'Мощный удар, каждый третий оглушает'),
        _ => const TowerSpec(
            role: TowerRole.strike, damage: 11, range: 1.7, cooldown: 0.8,
            label: 'Обычный удар'),
      };
}

class Tower {
  Tower({required this.kindId, required this.cell, required this.stars});

  final String kindId;
  final Cell cell;
  final int stars;
  int level = 1;
  double _cooldown = 0;
  int _shots = 0;

  static const maxLevel = 3;

  TowerSpec get spec => TowerSpec.of(kindId);
  Rarity get rarity => SlipperCatalog.byId(kindId).rarity;

  double get damage =>
      spec.damage * rarity.statMul * Stars.multiplier(stars) * const [1.0, 1.7, 2.6][level - 1];

  double get range => spec.range + (level - 1) * 0.25;

  (double, double) get center => (cell.col + 0.5, cell.row + 0.5);

  /// Цена постановки одна для всех: редкий тапок сильнее сам по себе.
  static int priceOf(String kindId) => 50;

  int get upgradePrice => (priceOf(kindId) * (level == 1 ? 1.0 : 1.6)).round();

  /// Сколько вернёт продажа: половину вложенного.
  int get sellPrice {
    var spent = priceOf(kindId).toDouble();
    if (level >= 2) spent += priceOf(kindId);
    if (level >= 3) spent += priceOf(kindId) * 1.6;
    return (spent / 2).round();
  }
}

class Bug {
  Bug({required this.kind, required this.maxHp, required this.speed, required this.reward, this.boss = false})
      : hp = maxHp;

  final EnemyKind kind;
  final double maxHp;
  double hp;

  /// Клеток в секунду.
  final double speed;
  final int reward;
  final bool boss;

  /// Пройдено клеток тропы; отрицательное — ещё не вышел.
  double dist = 0;
  double slowLeft = 0;
  double stunLeft = 0;
  double poisonLeft = 0;
  double poisonDps = 0;

  bool get alive => hp > 0;
  (double, double) get pos => DefenseMap.pointAt(max(0, dist));
}

/// Вспышка выстрела для экрана: от тапка к цели.
class Shot {
  Shot({required this.from, required this.to, required this.role});
  final (double, double) from;
  final (double, double) to;
  final TowerRole role;
  double age = 0;
  static const life = 0.18;
}

/// Описание волны: кто и сколько.
class WaveSpec {
  const WaveSpec(this.groups);
  final List<(EnemyKind, int, bool)> groups;
}

class DefenseGame {
  DefenseGame({Random? random}) : _rng = random ?? Random();

  static const waves = 10;
  static const startLives = 10;
  static const startCrumbs = 120;

  final Random _rng;
  final towers = <Tower>[];
  final bugs = <Bug>[];
  final shots = <Shot>[];
  int lives = startLives;
  int crumbs = startCrumbs;

  /// Сколько волн уже отбито полностью.
  int cleared = 0;

  /// Идёт волна (а не пауза на стройку).
  bool waveActive = false;
  final _queue = <Bug>[];
  double _spawnTimer = 0;

  bool get over => lives <= 0 || cleared >= waves;
  bool get won => cleared >= waves && lives > 0;
  int get nextWave => cleared + 1;

  static WaveSpec specOf(int wave) => switch (wave) {
        1 => const WaveSpec([(EnemyCatalog.cockroach, 8, false)]),
        2 => const WaveSpec([(EnemyCatalog.fly, 10, false)]),
        3 => const WaveSpec([(EnemyCatalog.cockroach, 6, false), (EnemyCatalog.mosquito, 6, false)]),
        4 => const WaveSpec([(EnemyCatalog.rhinoBeetle, 5, false), (EnemyCatalog.fly, 8, false)]),
        5 => const WaveSpec([(EnemyCatalog.cockroach, 8, false), (EnemyCatalog.roachKing, 1, true)]),
        6 => const WaveSpec([(EnemyCatalog.silverfish, 14, false)]),
        7 => const WaveSpec([(EnemyCatalog.woodlouse, 7, false), (EnemyCatalog.mosquito, 8, false)]),
        8 => const WaveSpec([(EnemyCatalog.spider, 10, false), (EnemyCatalog.slug, 4, false)]),
        9 => const WaveSpec([(EnemyCatalog.woodlouse, 8, false), (EnemyCatalog.silverfish, 12, false)]),
        _ => const WaveSpec([(EnemyCatalog.spider, 10, false), (EnemyCatalog.spiderQueen, 1, true)]),
      };

  /// Здоровье жука: от его вида, номера волны; боссы — в разы толще.
  static double hpOf(EnemyKind k, int wave, bool boss) =>
      48 * k.hp * pow(1.34, wave - 1) * (boss ? 12 : 1);

  bool canPlace(Cell c) =>
      c.col >= 0 &&
      c.col < DefenseMap.cols &&
      c.row >= 0 &&
      c.row < DefenseMap.rows &&
      !DefenseMap.path.contains(c) &&
      towers.every((t) => t.cell != c);

  Tower? towerAt(Cell c) => towers.where((t) => t.cell == c).firstOrNull;

  bool place(String kindId, Cell c, {int stars = 0}) {
    final price = Tower.priceOf(kindId);
    if (!canPlace(c) || crumbs < price) return false;
    crumbs -= price;
    towers.add(Tower(kindId: kindId, cell: c, stars: stars));
    return true;
  }

  bool upgrade(Tower t) {
    if (t.level >= Tower.maxLevel || crumbs < t.upgradePrice) return false;
    crumbs -= t.upgradePrice;
    t.level++;
    return true;
  }

  void sell(Tower t) {
    crumbs += t.sellPrice;
    towers.remove(t);
  }

  /// Запустить следующую волну.
  void startWave() {
    if (waveActive || over) return;
    final w = nextWave;
    _queue.clear();
    for (final (kind, count, boss) in specOf(w).groups) {
      for (var i = 0; i < count; i++) {
        _queue.add(Bug(
          kind: kind,
          maxHp: hpOf(kind, w, boss),
          speed: (boss ? 0.55 : 0.85) * kind.speed,
          reward: boss ? 60 : (4 + w),
          boss: boss,
        ));
      }
    }
    // Боссы выходят последними, остальные — вперемешку.
    final regular = _queue.where((b) => !b.boss).toList()..shuffle(_rng);
    final bosses = _queue.where((b) => b.boss).toList();
    _queue
      ..clear()
      ..addAll(regular)
      ..addAll(bosses);
    _spawnTimer = 0;
    waveActive = true;
  }

  /// Шаг симуляции на [dt] секунд.
  void step(double dt) {
    for (final s in shots) {
      s.age += dt;
    }
    shots.removeWhere((s) => s.age > Shot.life);
    if (!waveActive) return;

    // Выпуск жуков по очереди.
    _spawnTimer -= dt;
    if (_queue.isNotEmpty && _spawnTimer <= 0) {
      bugs.add(_queue.removeAt(0));
      _spawnTimer = 1.1;
    }

    // Движение, яд, оглушение.
    for (final b in bugs) {
      if (b.poisonLeft > 0) {
        b.hp -= b.poisonDps * dt;
        b.poisonLeft -= dt;
      }
      if (b.stunLeft > 0) {
        b.stunLeft -= dt;
        continue;
      }
      final slow = b.slowLeft > 0 ? 0.6 : 1.0;
      if (b.slowLeft > 0) b.slowLeft -= dt;
      b.dist += b.speed * slow * dt;
    }

    // Дошли до сахарницы.
    for (final b in [...bugs]) {
      if (b.dist >= DefenseMap.length) {
        bugs.remove(b);
        lives = max(0, lives - (b.boss ? 5 : 1));
      }
    }

    // Тапки бьют.
    for (final t in towers) {
      t._cooldown -= dt;
      if (t._cooldown > 0) continue;
      final target = _target(t);
      if (target == null) continue;
      t._cooldown = t.spec.cooldown;
      t._shots++;
      _hit(t, target);
    }

    // Убитые дают крошки.
    for (final b in [...bugs]) {
      if (!b.alive) {
        bugs.remove(b);
        crumbs += b.reward;
      }
    }

    if (lives <= 0) {
      waveActive = false;
      return;
    }
    if (_queue.isEmpty && bugs.isEmpty) {
      waveActive = false;
      cleared++;
      // Премия за отбитую волну.
      crumbs += 20 + cleared * 5;
    }
  }

  double _distTo((double, double) a, (double, double) b) {
    final dx = a.$1 - b.$1;
    final dy = a.$2 - b.$2;
    return sqrt(dx * dx + dy * dy);
  }

  /// Цель — тот, кто дальше всех прошёл по тропе в радиусе.
  Bug? _target(Tower t) {
    Bug? best;
    for (final b in bugs) {
      if (b.dist < 0 || !b.alive) continue;
      if (_distTo(t.center, b.pos) > t.range) continue;
      if (best == null || b.dist > best.dist) best = b;
    }
    return best;
  }

  void _hit(Tower t, Bug target) {
    final dmg = t.damage;
    shots.add(Shot(from: t.center, to: target.pos, role: t.spec.role));
    switch (t.spec.role) {
      case TowerRole.strike:
      case TowerRole.beam:
        target.hp -= dmg;
      case TowerRole.slow:
        target.hp -= dmg;
        target.slowLeft = 1.5;
      case TowerRole.splash:
        for (final b in bugs) {
          if (_distTo(b.pos, target.pos) <= 0.9) b.hp -= dmg * (b == target ? 1 : 0.6);
        }
      case TowerRole.chain:
        target.hp -= dmg;
        var from = target;
        final hit = {target};
        for (var i = 0; i < 2; i++) {
          Bug? next;
          for (final b in bugs) {
            if (hit.contains(b) || !b.alive) continue;
            if (_distTo(b.pos, from.pos) <= 1.4 && (next == null || b.dist > next.dist)) next = b;
          }
          if (next == null) break;
          next.hp -= dmg * 0.7;
          shots.add(Shot(from: from.pos, to: next.pos, role: TowerRole.chain));
          hit.add(next);
          from = next;
        }
      case TowerRole.poison:
        target.hp -= dmg * 0.5;
        target.poisonLeft = 3;
        target.poisonDps = max(target.poisonDps, dmg * 0.5);
      case TowerRole.stunner:
        target.hp -= dmg;
        if (t._shots % 3 == 0 && !target.boss) target.stunLeft = 0.6;
    }
  }
}

/// Награда за [waves] отбитых волн.
class DefenseReward {
  const DefenseReward({required this.threads, required this.coins, this.gem});

  final int threads;
  final int coins;

  /// Редкость гема в награду; null — без гема.
  final Rarity? gem;

  static DefenseReward forWaves(int waves) => DefenseReward(
        threads: 40 * waves * (waves + 1) ~/ 2,
        coins: 12 * waves + (waves >= 10 ? 100 : 0),
        gem: waves >= 10
            ? Rarity.epic
            : waves >= 8
                ? Rarity.rare
                : waves >= 5
                    ? Rarity.common
                    : null,
      );
}
