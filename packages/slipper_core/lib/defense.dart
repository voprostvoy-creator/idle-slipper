import 'dart:math';

import 'slipper_kind.dart';
import 'stars.dart';
import 'story/enemies.dart';

/// «Оборона сада» — tower defense: насекомые ползут по тропе к сахарнице,
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

  /// Расстояние от точки до оси тропы, в клетках.
  static double distToPath(double x, double y) {
    var best = double.infinity;
    for (var i = 0; i < waypoints.length - 1; i++) {
      final ax = waypoints[i].$1 + 0.5;
      final ay = waypoints[i].$2 + 0.5;
      final bx = waypoints[i + 1].$1 + 0.5;
      final by = waypoints[i + 1].$2 + 0.5;
      final vx = bx - ax;
      final vy = by - ay;
      final l2 = vx * vx + vy * vy;
      final t = l2 == 0 ? 0.0 : (((x - ax) * vx + (y - ay) * vy) / l2).clamp(0.0, 1.0);
      final dx = x - (ax + vx * t);
      final dy = y - (ay + vy * t);
      best = min(best, sqrt(dx * dx + dy * dy));
    }
    return best;
  }

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
enum TowerRole {
  /// Пинок носком по одной цели.
  strike,

  /// Холодное дыхание: урон и замедление.
  frost,

  /// Огненный шар: летит к цели и взрывается.
  fireball,

  /// Молния, скачущая по жукам.
  lightning,

  /// Резанье: каждый удар по той же цели сильнее.
  slash,

  /// Лазерный луч.
  laser,

  /// Воздушная волна, проходящая насквозь.
  wave,
}

/// Характеристики тапка-защитника по виду.
class TowerSpec {
  const TowerSpec({
    required this.role,
    required this.damage,
    required this.range,
    required this.cooldown,
    required this.label,
    required this.ability,
    required this.abilityText,
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

  /// Способность, которая открывается на 3-м уровне тапка в обороне.
  final String ability;
  final String abilityText;

  static TowerSpec of(String kindId) => switch (kindId) {
        'blue_slide' => const TowerSpec(
            role: TowerRole.frost, damage: 10, range: 1.8, cooldown: 0.9,
            label: 'Обдаёт холодом: замедляет на 40%',
            ability: 'Скользкий пол',
            abilityText: 'Замедление 60% вместо 40% и держится вдвое дольше.'),
        'carbon_sport' => const TowerSpec(
            role: TowerRole.fireball, damage: 14, range: 1.8, cooldown: 1.4,
            label: 'Огненный шар бьёт по площади',
            ability: 'Ударная волна',
            abilityText: 'Каждый третий удар бьёт по площади вокруг себя и оглушает всех на 0.5 с.'),
        'purple_neon' => const TowerSpec(
            role: TowerRole.lightning, damage: 10, range: 2.0, cooldown: 1.1,
            label: 'Молния по трём целям',
            ability: 'Перегрузка',
            abilityText: 'Каждая третья молния скачет по всем жукам на карте с полным уроном.'),
        'red_spike' => const TowerSpec(
            role: TowerRole.slash, damage: 9, range: 1.7, cooldown: 0.9,
            label: 'Режет: каждый удар по той же цели +20% урона (до +100%)',
            ability: 'Ярость',
            abilityText: 'Каждый третий удар ускоряется — три быстрых взмаха подряд.'),
        'rainbow' => const TowerSpec(
            role: TowerRole.laser, damage: 26, range: 3.2, cooldown: 1.3,
            label: 'Лазерный луч дальнего боя',
            ability: 'Призма',
            abilityText: 'Каждый третий луч пробивает всю карту насквозь с двойным уроном.'),
        'yin_yang' => const TowerSpec(
            role: TowerRole.wave, damage: 18, range: 2.2, cooldown: 1.1,
            label: 'Воздушная волна в 1.5 клетки — бьёт всех на пути',
            ability: 'Равновесие',
            abilityText: 'Каждый удар отбрасывает жуков на полклетки назад (жука — не чаще раза в 2 с).'),
        _ => const TowerSpec(
            role: TowerRole.strike, damage: 11, range: 1.7, cooldown: 0.8,
            label: 'Пинок по жуку',
            ability: 'Бабушкина подмога',
            abilityText: 'После каждой отбитой волны сахарнице +1 жизнь.'),
      };
}

class Tower {
  Tower({required this.kindId, required this.x, required this.y, required this.stars});

  final String kindId;

  /// Где стоит — в клетках, центр тапка; ставится в любое место поля.
  final double x;
  final double y;
  final int stars;
  int level = 1;
  double _cooldown = 0;
  int _shots = 0;

  /// Сколько быстрых взмахов Адского ещё осталось в серии.
  int _burstLeft = 0;

  /// Адский: по кому бил в прошлый раз и сколько раз подряд.
  Bug? _lastTarget;
  int _streak = 0;

  /// Куда смотрит тапок: угол на последнюю цель (0 — вправо).
  double aim = 0;

  /// Сколько секунд назад был удар — для анимации; большое — давно.
  double sinceShot = 99;

  /// Удар усиленный: способность сработала — экран может подсветить.
  bool special = false;

  static const maxLevel = 3;

  /// На каком уровне в обороне открывается способность.
  static const abilityLevel = 3;

  /// Открыта способность — тапок улучшен до 3-го уровня.
  bool get hasAbility => level >= abilityLevel;

  TowerSpec get spec => TowerSpec.of(kindId);
  Rarity get rarity => SlipperCatalog.byId(kindId).rarity;

  double get damage => damageAt(level);
  double get range => rangeAt(level);

  /// Урон и дальность на уровне [lv] — чтобы показать, что даст улучшение.
  double damageAt(int lv) =>
      spec.damage * rarity.statMul * Stars.multiplier(stars) * const [1.0, 1.7, 2.6][lv - 1];

  double rangeAt(int lv) => spec.range + (lv - 1) * 0.25;

  (double, double) get center => (x, y);

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
  double slowPower = 0.4;
  double stunLeft = 0;

  /// Отбрасывание Инь-Яна снова сработает через столько секунд — так
  /// несколько Инь-Янов не откидывают жука дважды.
  double knockCd = 0;
  static const knockCooldown = 2.0;

  bool get alive => hp > 0;
  (double, double) get pos => DefenseMap.pointAt(max(0, dist));
}

/// Что нарисовать на месте удара.
enum ShotFx {
  /// Вспышка пинка у цели.
  kick,

  /// Холодное облако от тапка к цели.
  frost,

  /// Ломаная молния.
  lightning,

  /// Взрыв огненного шара.
  explosion,

  /// Ударная волна вокруг тапка.
  nova,

  /// Росчерк когтя на цели.
  slash,

  /// Лазер до цели.
  laser,

  /// Лазер насквозь через всю карту.
  laserLong,
}

/// Вспышка удара для экрана.
class Shot {
  Shot({required this.from, required this.to, required this.fx, this.radius = 0, this.seed = 0});
  final (double, double) from;
  final (double, double) to;
  final ShotFx fx;

  /// Радиус взрыва или волны в клетках.
  final double radius;

  /// Для молнии — чтобы излом не дрожал каждый кадр.
  final int seed;
  double age = 0;

  double get life => switch (fx) {
        ShotFx.kick => 0.22,
        ShotFx.frost => 0.4,
        ShotFx.lightning => 0.25,
        ShotFx.explosion => 0.35,
        ShotFx.nova => 0.45,
        ShotFx.slash => 0.22,
        ShotFx.laser => 0.3,
        ShotFx.laserLong => 0.4,
      };
}

enum MissileKind { fireball, wave }

/// Летящий снаряд: огненный шар Карбона или воздушная волна Инь-Яна.
class Missile {
  Missile({
    required this.kind,
    required this.tower,
    required this.pos,
    required this.dir,
    required this.damage,
    this.target,
    this.travel = 0,
  })  : start = pos,
        aimPoint = target?.pos ?? pos;

  final MissileKind kind;
  final Tower tower;
  final (double, double) start;
  (double, double) pos;

  /// Единичное направление полёта.
  (double, double) dir;
  final double damage;

  /// Огненный шар летит за целью; если она умерла — в последнюю точку.
  Bug? target;
  (double, double) aimPoint;

  /// Сколько клеток ещё пролетит волна.
  double travel;
  final hit = <Bug>{};
  bool done = false;

  static const fireballSpeed = 6.0;
  static const waveSpeed = 5.0;

  /// Полуширина волны: вся волна — 1.5 клетки.
  static const waveHalfWidth = 0.75;
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
  final missiles = <Missile>[];
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

  /// Верх и низ поля в клетках: экран бывает выше карты — сверху и снизу
  /// тоже можно ставить тапки.
  double minY = 0;
  double maxY = DefenseMap.rows.toDouble();

  /// Ближе к оси тропы ставить нельзя.
  static const pathClearance = 0.72;

  /// Ближе к другому тапку ставить нельзя.
  static const towerGap = 0.75;

  bool canPlace(double x, double y) =>
      x >= 0.3 &&
      x <= DefenseMap.cols - 0.3 &&
      y >= minY + 0.3 &&
      y <= maxY - 0.3 &&
      DefenseMap.distToPath(x, y) >= pathClearance &&
      towers.every((t) => _distTo(t.center, (x, y)) >= towerGap);

  /// Тапок под пальцем: ближайший в радиусе полклетки.
  Tower? towerNear(double x, double y) {
    Tower? best;
    var bestD = 0.55;
    for (final t in towers) {
      final d = _distTo(t.center, (x, y));
      if (d < bestD) {
        best = t;
        bestD = d;
      }
    }
    return best;
  }

  bool place(String kindId, double x, double y, {int stars = 0}) {
    final price = Tower.priceOf(kindId);
    if (!canPlace(x, y) || crumbs < price) return false;
    crumbs -= price;
    towers.add(Tower(kindId: kindId, x: x, y: y, stars: stars));
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
    missiles.removeWhere((m) => m.tower == t);
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
    shots.removeWhere((s) => s.age > s.life);
    if (!waveActive) {
      missiles.clear();
      return;
    }

    // Выпуск жуков по очереди.
    _spawnTimer -= dt;
    if (_queue.isNotEmpty && _spawnTimer <= 0) {
      bugs.add(_queue.removeAt(0));
      _spawnTimer = 1.1;
    }

    // Движение и оглушение.
    for (final b in bugs) {
      if (b.knockCd > 0) b.knockCd -= dt;
      if (b.stunLeft > 0) {
        b.stunLeft -= dt;
        continue;
      }
      final slow = b.slowLeft > 0 ? 1 - b.slowPower : 1.0;
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
      t.sinceShot += dt;
      if (t._cooldown > 0) continue;
      final target = _target(t);
      if (target == null) continue;
      if (t._burstLeft > 0) {
        // Серия быстрых взмахов Адского.
        t._burstLeft--;
        t._cooldown = 0.13;
        t.special = true;
      } else {
        t._shots++;
        t._cooldown = t.spec.cooldown;
        t.special = t.hasAbility && t._shots % 3 == 0 && t.spec.role != TowerRole.strike &&
            t.spec.role != TowerRole.frost && t.spec.role != TowerRole.wave;
        if (t.special && t.spec.role == TowerRole.slash) {
          t._burstLeft = 2;
          t._cooldown = 0.13;
        }
      }
      t.sinceShot = 0;
      final (tx, ty) = target.pos;
      t.aim = atan2(ty - t.center.$2, tx - t.center.$1);
      _hit(t, target);
    }

    _moveMissiles(dt);

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
      missiles.clear();
      cleared++;
      // Премия за отбитую волну.
      crumbs += 20 + cleared * 5;
      // Бабушкина подмога: клетчатый 3-го уровня подлечивает сахарницу.
      if (towers.any((t) => t.kindId == 'basic' && t.hasAbility)) {
        lives = min(startLives, lives + 1);
      }
    }
  }

  double _distTo((double, double) a, (double, double) b) {
    final dx = a.$1 - b.$1;
    final dy = a.$2 - b.$2;
    return sqrt(dx * dx + dy * dy);
  }

  (double, double) _unit((double, double) from, (double, double) to) {
    final dx = to.$1 - from.$1;
    final dy = to.$2 - from.$2;
    final l = sqrt(dx * dx + dy * dy);
    return l == 0 ? (1, 0) : (dx / l, dy / l);
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

  /// Точка, где луч из [from] по [dir] выходит за край поля.
  (double, double) _edge((double, double) from, (double, double) dir) {
    var k = double.infinity;
    final (x, y) = from;
    final (dx, dy) = dir;
    if (dx > 0) k = min(k, (DefenseMap.cols - x) / dx);
    if (dx < 0) k = min(k, -x / dx);
    if (dy > 0) k = min(k, (maxY - y) / dy);
    if (dy < 0) k = min(k, (minY - y) / dy);
    return (x + dx * k, y + dy * k);
  }

  void _hit(Tower t, Bug target) {
    final dmg = t.damage;
    final ab = t.special;
    switch (t.spec.role) {
      case TowerRole.strike:
        target.hp -= dmg;
        shots.add(Shot(from: t.center, to: target.pos, fx: ShotFx.kick));
      case TowerRole.frost:
        target.hp -= dmg;
        final strong = t.hasAbility;
        target.slowLeft = strong ? 3 : 1.5;
        target.slowPower = strong ? 0.6 : 0.4;
        shots.add(Shot(from: t.center, to: target.pos, fx: ShotFx.frost));
      case TowerRole.fireball:
        if (ab) {
          // Ударная волна: всех вокруг себя бьёт и оглушает.
          for (final b in bugs) {
            if (b.dist >= 0 && _distTo(b.pos, t.center) <= t.range) {
              b.hp -= dmg;
              b.stunLeft = max(b.stunLeft, 0.5);
            }
          }
          shots.add(Shot(from: t.center, to: t.center, fx: ShotFx.nova, radius: t.range));
        } else {
          missiles.add(Missile(
            kind: MissileKind.fireball,
            tower: t,
            pos: t.center,
            dir: _unit(t.center, target.pos),
            damage: dmg,
            target: target,
          ));
        }
      case TowerRole.lightning:
        target.hp -= dmg;
        shots.add(Shot(from: t.center, to: target.pos, fx: ShotFx.lightning, seed: _rng.nextInt(1 << 20)));
        var from = target;
        final hit = {target};
        // Обычно — ещё две цели рядом; с перегрузкой — все жуки на карте.
        final jumps = ab ? bugs.length : 2;
        for (var i = 0; i < jumps; i++) {
          Bug? next;
          for (final b in bugs) {
            if (hit.contains(b) || !b.alive || b.dist < 0) continue;
            final d = _distTo(b.pos, from.pos);
            if (!ab && d > 1.4) continue;
            if (next == null || d < _distTo(next.pos, from.pos)) next = b;
          }
          if (next == null) break;
          next.hp -= ab ? dmg : dmg * 0.7;
          shots.add(Shot(from: from.pos, to: next.pos, fx: ShotFx.lightning, seed: _rng.nextInt(1 << 20)));
          hit.add(next);
          from = next;
        }
      case TowerRole.slash:
        // Каждый следующий удар по той же цели +20%.
        if (t._lastTarget == target) {
          t._streak = min(t._streak + 1, 5);
        } else {
          t._lastTarget = target;
          t._streak = 0;
        }
        target.hp -= dmg * (1 + 0.2 * t._streak);
        shots.add(Shot(from: t.center, to: target.pos, fx: ShotFx.slash, seed: t._streak));
      case TowerRole.laser:
        if (ab) {
          // Призма: луч насквозь до края карты, двойной урон всем на линии.
          final dir = _unit(t.center, target.pos);
          for (final b in bugs) {
            if (b.dist < 0) continue;
            final rx = b.pos.$1 - t.center.$1;
            final ry = b.pos.$2 - t.center.$2;
            final along = rx * dir.$1 + ry * dir.$2;
            final perp = (rx * dir.$2 - ry * dir.$1).abs();
            if (along > 0 && perp <= 0.45) b.hp -= dmg * 2;
          }
          shots.add(Shot(from: t.center, to: _edge(t.center, dir), fx: ShotFx.laserLong));
        } else {
          target.hp -= dmg;
          shots.add(Shot(from: t.center, to: target.pos, fx: ShotFx.laser));
        }
      case TowerRole.wave:
        missiles.add(Missile(
          kind: MissileKind.wave,
          tower: t,
          pos: t.center,
          dir: _unit(t.center, target.pos),
          damage: dmg,
          travel: t.range + 0.4,
        ));
    }
  }

  void _moveMissiles(double dt) {
    for (final m in missiles) {
      switch (m.kind) {
        case MissileKind.fireball:
          // Летит за целью; умерла — долетает до точки, где она была.
          if (m.target != null && m.target!.alive) m.aimPoint = m.target!.pos;
          final goal = m.aimPoint;
          m.dir = _unit(m.pos, goal);
          final stepLen = Missile.fireballSpeed * dt;
          if (_distTo(m.pos, goal) <= stepLen) {
            m.pos = goal;
            _explode(m);
          } else {
            m.pos = (m.pos.$1 + m.dir.$1 * stepLen, m.pos.$2 + m.dir.$2 * stepLen);
          }
        case MissileKind.wave:
          final stepLen = Missile.waveSpeed * dt;
          m.pos = (m.pos.$1 + m.dir.$1 * stepLen, m.pos.$2 + m.dir.$2 * stepLen);
          m.travel -= stepLen;
          for (final b in bugs) {
            if (!b.alive || b.dist < 0 || m.hit.contains(b)) continue;
            final rx = b.pos.$1 - m.pos.$1;
            final ry = b.pos.$2 - m.pos.$2;
            final along = rx * m.dir.$1 + ry * m.dir.$2;
            final perp = (rx * m.dir.$2 - ry * m.dir.$1).abs();
            if (along.abs() <= 0.35 && perp <= Missile.waveHalfWidth) {
              m.hit.add(b);
              b.hp -= m.damage;
              // Равновесие: отбрасывает на полклетки назад, не чаще раза в 2 с.
              if (m.tower.hasAbility && b.knockCd <= 0) {
                b.dist = max(0, b.dist - 0.5);
                b.knockCd = Bug.knockCooldown;
              }
            }
          }
          if (m.travel <= 0) m.done = true;
      }
    }
    missiles.removeWhere((m) => m.done);
  }

  void _explode(Missile m) {
    m.done = true;
    for (final b in bugs) {
      if (b.dist >= 0 && _distTo(b.pos, m.pos) <= 0.9) {
        b.hp -= m.damage * (b == m.target ? 1 : 0.6);
      }
    }
    shots.add(Shot(from: m.pos, to: m.pos, fx: ShotFx.explosion, radius: 0.9));
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
