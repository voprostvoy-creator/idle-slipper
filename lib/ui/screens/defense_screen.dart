import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../game/defense.dart';
import '../../game/game_state.dart';
import '../../game/gems.dart';
import '../../game/slipper.dart';
import '../../game/slipper_kind.dart';
import '../format.dart';
import '../gem_icon.dart';
import '../slipper_sprite.dart';
import '../theme.dart';
import '../widgets/game_widgets.dart';
import 'battle_hub_screen.dart';

/// Страница режима «Оборона кухни»: попытки, рекорд, награды, кнопка игры.
class DefenseScreen extends StatelessWidget {
  const DefenseScreen({super.key, required this.game, required this.onBack});

  final GameState game;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListenableBuilder(
      listenable: game,
      builder: (context, _) {
        final attempts = game.defenseAttempts;
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          children: [
            BackToModes(title: 'Оборона кухни', onBack: onBack),
            const SizedBox(height: 10),
            GamePanel(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  Text(
                    'Жуки ползут к сахарнице! Ставь тапки из коллекции вдоль тропы — '
                    'они бьют всех, кто рядом. Чем больше волн отобьёшь, тем богаче награда.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _Stat(
                        label: 'Попыток',
                        value: '$attempts',
                        color: GameColors.green,
                      ),
                      _Stat(
                        label: 'Рекорд',
                        value: '${game.defenseBest}/${DefenseGame.waves}',
                        color: GameColors.gold,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: GameButton(
                      color: attempts > 0
                          ? GameColors.red
                          : GameColors.panelDark,
                      height: 56,
                      onPressed: attempts > 0 ? () => _play(context) : null,
                      child: const Text(
                        'Защищать кухню',
                        style: TextStyle(fontSize: 20),
                      ),
                    ),
                  ),
                  if (game.defenseAdAvailable) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: GameButton(
                        color: GameColors.green,
                        height: 46,
                        onPressed: game.takeDefenseAdAttempt,
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.play_circle_fill_rounded, size: 20),
                            SizedBox(width: 6),
                            Text('+1 попытка за рекламу'),
                          ],
                        ),
                      ),
                    ),
                  ],
                  if (attempts == 0 && !game.defenseAdAvailable) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Новые попытки завтра',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),
            const StrokeText('Награды', size: 22),
            const SizedBox(height: 8),
            for (final w in const [3, 5, 8, 10]) ...[
              _RewardRow(waves: w),
              const SizedBox(height: 8),
            ],
          ],
        );
      },
    );
  }

  void _play(BuildContext context) {
    if (!game.startDefense()) return;
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => DefenseGameScreen(game: game)));
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      StrokeText(value, size: 28, color: color),
      Text(label, style: Theme.of(context).textTheme.bodySmall),
    ],
  );
}

class _RewardRow extends StatelessWidget {
  const _RewardRow({required this.waves});
  final int waves;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = DefenseReward.forWaves(waves);
    return GamePanel(
      color: GameColors.panelDark,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 74,
            child: Text('$waves волн', style: theme.textTheme.titleSmall),
          ),
          const ThreadIcon(size: 16),
          const SizedBox(width: 3),
          Text(fmtNum(r.threads), style: theme.textTheme.bodyMedium),
          const SizedBox(width: 12),
          const CoinIcon(size: 16),
          const SizedBox(width: 3),
          Text('${r.coins}', style: theme.textTheme.bodyMedium),
          const Spacer(),
          if (r.gem != null)
            GemIcon(
              gem: Gem(id: 0, type: GemType.attack, rarity: r.gem!),
              size: 24,
              showLevel: false,
            ),
        ],
      ),
    );
  }
}

/// Само поле обороны.
class DefenseGameScreen extends StatefulWidget {
  const DefenseGameScreen({super.key, required this.game});
  final GameState game;

  @override
  State<DefenseGameScreen> createState() => _DefenseGameScreenState();
}

class _DefenseGameScreenState extends State<DefenseGameScreen>
    with SingleTickerProviderStateMixin {
  final _d = DefenseGame();
  late final Ticker _ticker;
  Duration _last = Duration.zero;
  int _speed = 1;
  Tower? _selected;
  bool _finished = false;

  GameState get game => widget.game;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _onTick(Duration now) {
    var dt = (now - _last).inMicroseconds / 1e6;
    _last = now;
    if (dt > 0.1) dt = 0.1;
    if (_finished) return;
    var left = dt * _speed;
    while (left > 0) {
      final step = min(left, 1 / 30);
      _d.step(step);
      left -= step;
    }
    setState(() {});
    if (_d.over) _finish();
  }

  void _finish() {
    if (_finished) return;
    _finished = true;
    final waves = _d.won ? DefenseGame.waves : _d.cleared;
    final res = game.finishDefense(waves);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: StrokeText(
          _d.won ? 'Кухня спасена!' : 'Жуки прорвались',
          size: 24,
          color: _d.won ? GameColors.gold : GameColors.red,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Отбито волн: $waves из ${DefenseGame.waves}'),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const ThreadIcon(size: 20),
                const SizedBox(width: 4),
                Text('+${fmtNum(res.reward.threads)}'),
                const SizedBox(width: 16),
                const CoinIcon(size: 20),
                const SizedBox(width: 4),
                Text('+${res.reward.coins}'),
              ],
            ),
            if (res.gem != null) ...[
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GemIcon(gem: res.gem!, size: 36),
                  const SizedBox(width: 8),
                  Flexible(child: Text(gemTitle(res.gem!))),
                ],
              ),
            ],
          ],
        ),
        actions: [
          GameButton(
            color: GameColors.gold,
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(this.context);
            },
            child: const Text('Готово'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmExit() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const StrokeText('Сдаться?', size: 22),
        content: Text('Награду получишь за уже отбитые волны: ${_d.cleared}.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Играть дальше'),
          ),
          GameButton(
            color: GameColors.red,
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Сдаться'),
          ),
        ],
      ),
    );
    if (ok == true) _finish();
  }

  void _tapCell(Cell c) {
    final t = _d.towerAt(c);
    if (t != null) {
      setState(() => _selected = t);
      _towerSheet(t);
      return;
    }
    setState(() => _selected = null);
    if (DefenseMap.path.contains(c)) return;
    _buildSheet(c);
  }

  void _buildSheet(Cell c) {
    final owned = [
      for (final k in SlipperCatalog.all)
        if (game.count(k.id) > 0) k,
    ];
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: GameColors.panel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        side: BorderSide(color: GameColors.outline, width: 3),
      ),
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Center(child: StrokeText('Поставить тапок', size: 22)),
              const SizedBox(height: 8),
              for (final k in owned)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: GamePanel(
                    padding: const EdgeInsets.all(8),
                    onTap: _d.crumbs >= Tower.priceOf(k.id)
                        ? () {
                            setState(
                              () =>
                                  _d.place(k.id, c, stars: game.starsOf(k.id)),
                            );
                            Navigator.pop(context);
                          }
                        : null,
                    child: Row(
                      children: [
                        SlipperSprite(
                          fighter: Slipper(name: k.name, kindId: k.id),
                          width: 64,
                          animate: false,
                          showSize: false,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                k.name,
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                              Text(
                                TowerSpec.of(k.id).label,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        _Crumbs(
                          Tower.priceOf(k.id),
                          enough: _d.crumbs >= Tower.priceOf(k.id),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _towerSheet(Tower t) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: GameColors.panel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        side: BorderSide(color: GameColors.outline, width: 3),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              StrokeText(
                '${SlipperCatalog.byId(t.kindId).name} · ур. ${t.level}',
                size: 20,
              ),
              const SizedBox(height: 4),
              Text(
                '${t.spec.label}. Урон ${t.damage.round()}, дальность ${t.range.toStringAsFixed(1)}',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: GameButton(
                      color: GameColors.panelLight,
                      height: 46,
                      onPressed: () {
                        setState(() {
                          _d.sell(t);
                          _selected = null;
                        });
                        Navigator.pop(context);
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Продать ',
                            style: TextStyle(color: GameColors.text),
                          ),
                          _Crumbs(t.sellPrice, enough: true, plus: true),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: t.level >= Tower.maxLevel
                        ? const Center(child: Text('Максимум'))
                        : GameButton(
                            color: _d.crumbs >= t.upgradePrice
                                ? GameColors.gold
                                : GameColors.panelDark,
                            height: 46,
                            onPressed: _d.crumbs >= t.upgradePrice
                                ? () {
                                    setState(() => _d.upgrade(t));
                                    Navigator.pop(context);
                                  }
                                : null,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text('Улучшить '),
                                _Crumbs(
                                  t.upgradePrice,
                                  enough: _d.crumbs >= t.upgradePrice,
                                ),
                              ],
                            ),
                          ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ).whenComplete(() {
      if (mounted) setState(() => _selected = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopScope(
      canPop: _finished,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmExit();
      },
      child: Scaffold(
        body: GameBackground(
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
                  child: Row(
                    children: [
                      GameButton(
                        onPressed: _confirmExit,
                        color: GameColors.panelLight,
                        height: 36,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: const Icon(
                          Icons.flag_rounded,
                          color: GameColors.text,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Icon(
                        Icons.favorite,
                        color: GameColors.red,
                        size: 22,
                      ),
                      const SizedBox(width: 3),
                      StrokeText('${_d.lives}', size: 20),
                      const SizedBox(width: 12),
                      _Crumbs(_d.crumbs, enough: true, big: true),
                      const Spacer(),
                      StrokeText(
                        'Волна ${min(_d.nextWave, DefenseGame.waves)}/${DefenseGame.waves}',
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      GameButton(
                        onPressed: () =>
                            setState(() => _speed = _speed == 1 ? 2 : 1),
                        color: _speed == 2
                            ? GameColors.gold
                            : GameColors.panelLight,
                        height: 36,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          '×$_speed',
                          style: TextStyle(
                            color: _speed == 2
                                ? GameColors.outline
                                : GameColors.text,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: DefenseMap.cols / DefenseMap.rows,
                      child: LayoutBuilder(
                        builder: (context, box) =>
                            _field(box.maxWidth / DefenseMap.cols),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
                  child: SizedBox(
                    width: double.infinity,
                    child: _d.waveActive
                        ? GamePanel(
                            color: GameColors.panelDark,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Text(
                              'Жуки идут! Осталось: ${_d.bugs.length}',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.titleSmall,
                            ),
                          )
                        : GameButton(
                            color: GameColors.red,
                            height: 52,
                            onPressed: _d.over
                                ? null
                                : () => setState(_d.startWave),
                            child: Text(
                              _d.towers.isEmpty
                                  ? 'Поставь тапок и начни волну ${_d.nextWave}'
                                  : 'Начать волну ${_d.nextWave}',
                              style: const TextStyle(fontSize: 17),
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(double cell) {
    return GestureDetector(
      onTapUp: (d) => _tapCell((
        col: (d.localPosition.dx / cell).floor(),
        row: (d.localPosition.dy / cell).floor(),
      )),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _BoardPainter(cell: cell, selected: _selected),
            ),
          ),
          for (final t in _d.towers)
            Positioned(
              left: t.cell.col * cell - cell * 0.1,
              top: t.cell.row * cell + cell * 0.2,
              width: cell * 1.2,
              child: Column(
                children: [
                  SlipperSprite(
                    fighter: Slipper(name: t.kindId, kindId: t.kindId),
                    width: cell * 1.2,
                    animate: false,
                    showSize: false,
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < t.level; i++)
                        Icon(
                          Icons.star_rounded,
                          size: cell * 0.22,
                          color: GameColors.gold,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          for (final b in _d.bugs)
            if (b.dist >= 0) _bug(b, cell),
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _ShotsPainter(cell: cell, shots: _d.shots),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bug(Bug b, double cell) {
    final (x, y) = b.pos;
    final w = cell * (b.boss ? 1.6 : 0.95);
    final h = w / 2;
    final dir = DefenseMap.dirAt(b.dist);
    Widget img = Image.asset(
      b.kind.asset,
      width: w,
      height: h,
      gaplessPlayback: true,
    );
    if (dir < 0) img = Transform.flip(flipX: true, child: img);
    if (b.poisonLeft > 0) {
      img = ColorFiltered(
        colorFilter: const ColorFilter.mode(
          Color(0x6650FF60),
          BlendMode.srcATop,
        ),
        child: img,
      );
    }
    return Positioned(
      left: x * cell - w / 2,
      top: y * cell - h * 0.75,
      width: w,
      child: Column(
        children: [
          // Полоска здоровья.
          Container(
            width: w * 0.6,
            height: 4,
            decoration: BoxDecoration(
              color: GameColors.outline,
              borderRadius: BorderRadius.circular(2),
            ),
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: (b.hp / b.maxHp).clamp(0.0, 1.0),
              child: Container(
                color: b.boss ? GameColors.gold : GameColors.red,
              ),
            ),
          ),
          img,
          if (b.stunLeft > 0)
            const Icon(Icons.star, size: 10, color: GameColors.gold),
        ],
      ),
    );
  }
}

class _Crumbs extends StatelessWidget {
  const _Crumbs(
    this.amount, {
    required this.enough,
    this.big = false,
    this.plus = false,
  });
  final int amount;
  final bool enough;
  final bool big;
  final bool plus;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(
        Icons.bakery_dining_rounded,
        size: big ? 22 : 16,
        color: const Color(0xFFE8B66A),
      ),
      const SizedBox(width: 3),
      Text(
        '${plus ? '+' : ''}$amount',
        style: TextStyle(
          fontSize: big ? 18 : 14,
          fontWeight: FontWeight.w900,
          color: enough ? GameColors.text : GameColors.red,
        ),
      ),
    ],
  );
}

/// Пол кухни, тропа и сахарница; у выбранного тапка — круг дальности.
class _BoardPainter extends CustomPainter {
  _BoardPainter({required this.cell, required this.selected});
  final double cell;
  final Tower? selected;

  @override
  void paint(Canvas c, Size size) {
    // Плитка пола в шахматку.
    for (var r = 0; r < DefenseMap.rows; r++) {
      for (var col = 0; col < DefenseMap.cols; col++) {
        final rect = Rect.fromLTWH(col * cell, r * cell, cell, cell);
        final isPath = DefenseMap.path.contains((col: col, row: r));
        final light = (r + col).isEven;
        c.drawRect(
          rect,
          Paint()
            ..color = isPath
                ? (light ? const Color(0xFF8C6A4A) : const Color(0xFF7C5C3E))
                : (light ? const Color(0xFF4E3A6E) : const Color(0xFF45325F)),
        );
      }
    }
    // Края тропы.
    final edge = Paint()
      ..color = const Color(0x55000000)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (final p in DefenseMap.path) {
      c.drawRect(Rect.fromLTWH(p.col * cell, p.row * cell, cell, cell), edge);
    }
    // Сахарница.
    final s = DefenseMap.sugar;
    final center = Offset((s.col + 0.5) * cell, (s.row + 0.5) * cell);
    c.drawOval(
      Rect.fromCenter(
        center: center + Offset(0, cell * 0.12),
        width: cell * 0.9,
        height: cell * 0.55,
      ),
      Paint()..color = Colors.white,
    );
    c.drawOval(
      Rect.fromCenter(
        center: center + Offset(0, cell * 0.12),
        width: cell * 0.9,
        height: cell * 0.55,
      ),
      Paint()
        ..color = GameColors.outline
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
    for (final o in [
      const Offset(-0.18, -0.05),
      const Offset(0.12, -0.08),
      const Offset(-0.02, -0.2),
    ]) {
      final r = Rect.fromCenter(
        center: center + o * cell,
        width: cell * 0.2,
        height: cell * 0.2,
      );
      c.drawRect(r, Paint()..color = const Color(0xFFFFF6E8));
      c.drawRect(
        r,
        Paint()
          ..color = GameColors.outline
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }
    // Дальность выбранного тапка.
    final t = selected;
    if (t != null) {
      final (x, y) = t.center;
      c.drawCircle(
        Offset(x * cell, y * cell),
        t.range * cell,
        Paint()..color = const Color(0x2266D9FF),
      );
      c.drawCircle(
        Offset(x * cell, y * cell),
        t.range * cell,
        Paint()
          ..color = const Color(0x9966D9FF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }

  @override
  bool shouldRepaint(_BoardPainter old) =>
      old.selected != selected || old.cell != cell;
}

/// Выстрелы тапков: вспышки-линии цвета роли.
class _ShotsPainter extends CustomPainter {
  _ShotsPainter({required this.cell, required this.shots});
  final double cell;
  final List<Shot> shots;

  static Color _color(TowerRole r) => switch (r) {
    TowerRole.strike => Colors.white,
    TowerRole.slow => const Color(0xFF7FDBFF),
    TowerRole.splash => const Color(0xFFFF9F43),
    TowerRole.chain => const Color(0xFFC77DFF),
    TowerRole.poison => const Color(0xFF7CE35A),
    TowerRole.beam => const Color(0xFFFFE28A),
    TowerRole.stunner => Colors.white,
  };

  @override
  void paint(Canvas c, Size size) {
    for (final s in shots) {
      final k = 1 - s.age / Shot.life;
      final from = Offset(s.from.$1 * cell, s.from.$2 * cell);
      final to = Offset(s.to.$1 * cell, s.to.$2 * cell);
      final color = _color(s.role).withValues(alpha: k.clamp(0.0, 1.0));
      c.drawLine(
        from,
        to,
        Paint()
          ..color = color
          ..strokeWidth = s.role == TowerRole.beam ? 5 : 3
          ..strokeCap = StrokeCap.round,
      );
      c.drawCircle(
        to,
        cell * (s.role == TowerRole.splash ? 0.5 : 0.18) * (1.2 - k),
        Paint()..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(_ShotsPainter old) => true;
}
