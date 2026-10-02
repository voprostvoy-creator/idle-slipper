import 'dart:math';
import 'dart:ui' as ui;

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
import '../toast.dart';
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
                    child: attempts == 0 && game.defenseAdAvailable
                        // Первая попытка потрачена — вместо неё реклама,
                        // после просмотра игра запускается сразу.
                        ? GameButton(
                            color: GameColors.green,
                            height: 56,
                            onPressed: () {
                              game.takeDefenseAdAttempt();
                              _play(context);
                            },
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.play_circle_fill_rounded, size: 24),
                                SizedBox(width: 8),
                                Text(
                                  'Ещё попытка за рекламу',
                                  style: TextStyle(fontSize: 18),
                                ),
                              ],
                            ),
                          )
                        : GameButton(
                            color: attempts > 0
                                ? GameColors.red
                                : GameColors.panelDark,
                            height: 56,
                            onPressed: attempts > 0
                                ? () => _play(context)
                                : null,
                            child: const Text(
                              'Защищать кухню',
                              style: TextStyle(fontSize: 20),
                            ),
                          ),
                  ),
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

  /// Размер клетки и сдвиг карты на экране (в клетках) — с последней раскладки.
  double _cell = 40;
  double _ox = 0;
  double _oy = 0;
  final _fieldKey = GlobalKey();

  /// Тапок, который сейчас тащат из панели, и куда он встанет.
  ({String kind, double x, double y})? _drag;

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

  /// Перевод точки на экране поля в клетки карты.
  (double, double) _toMap(Offset local) =>
      (local.dx / _cell - _ox, local.dy / _cell - _oy);

  void _tapField(Offset local) {
    final (x, y) = _toMap(local);
    final t = _d.towerNear(x, y);
    if (t == null) {
      setState(() => _selected = null);
      return;
    }
    setState(() => _selected = t);
    _towerSheet(t);
  }

  /// Куда встанет тапок, который тащат: палец + подъём, чтобы его было видно.
  void _dragTo(String kindId, Offset global) {
    final box = _fieldKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final local = box.globalToLocal(global) + Offset(0, -_lift * _cell);
    final (x, y) = _toMap(local);
    setState(() => _drag = (kind: kindId, x: x, y: y));
  }

  void _drop() {
    final d = _drag;
    if (d == null) return;
    setState(() {
      _d.place(d.kind, d.x, d.y, stars: game.starsOf(d.kind));
      _drag = null;
    });
  }

  /// Насколько выше пальца ставится тапок, в клетках.
  static const _lift = 0.9;

  void _towerSheet(Tower t) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: GameColors.panel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        side: BorderSide(color: GameColors.outline, width: 3),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheet) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                StrokeText(
                  '${SlipperCatalog.byId(t.kindId).name} · ур. ${t.level}',
                  size: 20,
                ),
                const SizedBox(height: 2),
                Text(
                  t.spec.label,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 10),
                _StatLine(
                  label: 'Урон',
                  now: t.damage.round().toString(),
                  next: t.level < Tower.maxLevel
                      ? t.damageAt(t.level + 1).round().toString()
                      : null,
                ),
                const SizedBox(height: 6),
                _StatLine(
                  label: 'Дальность',
                  now: t.range.toStringAsFixed(1),
                  next: t.level < Tower.maxLevel
                      ? t.rangeAt(t.level + 1).toStringAsFixed(1)
                      : null,
                ),
                const SizedBox(height: 10),
                _AbilityBox(tower: t),
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
                                      setSheet(() {});
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
      ),
    ).whenComplete(() {
      if (mounted) setState(() => _selected = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _finished,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmExit();
      },
      child: Scaffold(
        body: GameBackground(
          child: Column(
            children: [
              SafeArea(bottom: false, child: _hud()),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, box) =>
                      _field(box.maxWidth, box.maxHeight),
                ),
              ),
              _panel(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _hud() => Padding(
    padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
    child: Row(
      children: [
        GameButton(
          onPressed: _confirmExit,
          color: GameColors.panelLight,
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: const Icon(Icons.flag_rounded, color: GameColors.text),
        ),
        const SizedBox(width: 10),
        const Icon(Icons.favorite, color: GameColors.red, size: 22),
        const SizedBox(width: 3),
        StrokeText('${_d.lives}', size: 20),
        const SizedBox(width: 12),
        _Crumbs(_d.crumbs, enough: true, big: true),
        const Spacer(),
        StrokeText(
          'Волна ${min(_d.nextWave, DefenseGame.waves)}/${DefenseGame.waves}',
          size: 18,
        ),
      ],
    ),
  );

  /// Панель тапков внизу: тащи на поле.
  Widget _panel() {
    final owned = [
      for (final k in SlipperCatalog.all)
        if (game.count(k.id) > 0) k,
    ];
    return Container(
      decoration: const BoxDecoration(
        color: GameColors.panel,
        border: Border(top: BorderSide(color: GameColors.outline, width: 3)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 92,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
            children: [
              for (final k in owned)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _card(k),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _card(SlipperKind k) {
    final price = Tower.priceOf(k.id);
    final enough = _d.crumbs >= price;
    final card = GamePanel(
      color: enough ? GameColors.panelLight : GameColors.panelDark,
      padding: const EdgeInsets.fromLTRB(6, 4, 6, 4),
      child: SizedBox(
        width: 66,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Opacity(
              opacity: enough ? 1 : 0.45,
              child: SlipperSprite(
                fighter: Slipper(name: k.name, kindId: k.id),
                width: 58,
                animate: false,
                showSize: false,
              ),
            ),
            const SizedBox(height: 4),
            _Crumbs(price, enough: enough),
          ],
        ),
      ),
    );
    return Draggable<String>(
      data: k.id,
      maxSimultaneousDrags: enough ? 1 : 0,
      dragAnchorStrategy: pointerDragAnchorStrategy,
      // Тапок висит над пальцем — там же, где встанет.
      feedback: Transform.translate(
        offset: Offset(-0.6 * _cell, -(0.3 + _lift) * _cell),
        child: IgnorePointer(
          child: SlipperSprite(
            fighter: Slipper(name: k.name, kindId: k.id),
            width: _cell * 1.2,
            animate: false,
            showSize: false,
          ),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.5, child: card),
      onDragUpdate: (d) => _dragTo(k.id, d.globalPosition),
      onDraggableCanceled: (_, _) => setState(() => _drag = null),
      onDragEnd: (_) {
        if (_drag != null) setState(() => _drag = null);
      },
      child: GestureDetector(
        onTap: () => showToast(
          context,
          'Перетащи тапок на поле',
          icon: const Icon(Icons.touch_app_rounded, size: 20),
        ),
        child: card,
      ),
    );
  }

  Widget _field(double w, double h) {
    // Поле во всю ширину; карта по центру, лишнее — тоже лужайка.
    final cell = min(w / DefenseMap.cols, h / DefenseMap.rows);
    _cell = cell;
    _ox = (w / cell - DefenseMap.cols) / 2;
    _oy = (h / cell - DefenseMap.rows) / 2;
    _d.minY = -_oy;
    _d.maxY = DefenseMap.rows + _oy;
    final drag = _drag;
    final towers = [..._d.towers]..sort((a, b) => a.y.compareTo(b.y));
    return DragTarget<String>(
      onWillAcceptWithDetails: (_) => true,
      onLeave: (_) => setState(() => _drag = null),
      onAcceptWithDetails: (_) => _drop(),
      builder: (context, _, _) => GestureDetector(
        key: _fieldKey,
        behavior: HitTestBehavior.opaque,
        onTapUp: (d) => _tapField(d.localPosition),
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _BoardPainter(
                  cell: cell,
                  ox: _ox,
                  oy: _oy,
                  selected: _selected,
                ),
              ),
            ),
            Positioned(
              left: _ox * cell,
              top: _oy * cell,
              width: DefenseMap.cols * cell,
              height: DefenseMap.rows * cell,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: _ShadowPainter(cell: cell, game: _d),
                      ),
                    ),
                  ),
                  if (drag != null)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: CustomPaint(
                          painter: _GhostPainter(
                            cell: cell,
                            x: drag.x,
                            y: drag.y,
                            range: TowerSpec.of(drag.kind).range,
                            ok: _d.canPlace(drag.x, drag.y),
                          ),
                        ),
                      ),
                    ),
                  for (final t in towers)
                    Positioned(
                      left: t.x * cell - cell * 0.6,
                      top: t.y * cell - cell * 0.3,
                      width: cell * 1.2,
                      child: IgnorePointer(
                        child: Column(
                          children: [
                            _TowerSprite(tower: t, cell: cell),
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
                    ),
                  for (final b in _d.bugs)
                    if (b.dist >= 0) _bug(b, cell),
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: _ShotsPainter(
                          cell: cell,
                          shots: _d.shots,
                          missiles: _d.missiles,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (_d.towers.isEmpty && !_d.waveActive && drag == null)
              const Positioned(
                left: 0,
                right: 0,
                top: 10,
                child: IgnorePointer(
                  child: Center(
                    child: StrokeText('Перетащи тапок на поле', size: 18),
                  ),
                ),
              ),
            Positioned(right: 12, bottom: 12, child: _waveButton()),
          ],
        ),
      ),
    );
  }

  /// Круглая кнопка в углу: между волнами — начать волну, во время — скорость.
  Widget _waveButton() {
    final active = _d.waveActive;
    final fast = _speed == 2;
    final color = !active
        ? GameColors.green
        : fast
        ? GameColors.gold
        : GameColors.panelLight;
    return GestureDetector(
      onTap: () {
        if (_d.over) return;
        setState(() {
          if (active) {
            _speed = fast ? 1 : 2;
          } else {
            _d.startWave();
          }
        });
      },
      child: Container(
        width: 62,
        height: 62,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: GameColors.outline, width: 3.5),
          boxShadow: const [
            BoxShadow(color: GameColors.outline, offset: Offset(0, 4)),
          ],
        ),
        child: Icon(
          active ? Icons.fast_forward_rounded : Icons.play_arrow_rounded,
          size: 38,
          color: active && !fast ? GameColors.text : GameColors.outline,
        ),
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
    if (b.slowLeft > 0) {
      img = ColorFiltered(
        colorFilter: const ColorFilter.mode(
          Color(0x667FDBFF),
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

/// Поле: лужайка с цветами, каменная тропа, кусты по краям и сахарница;
/// у выбранного тапка — круг дальности.
class _BoardPainter extends CustomPainter {
  _BoardPainter({
    required this.cell,
    required this.ox,
    required this.oy,
    required this.selected,
  });
  final double cell;

  /// Сдвиг карты внутри экрана поля, в клетках.
  final double ox;
  final double oy;
  final Tower? selected;

  // Картинка поля без выбранного тапка — рисуется один раз на размер.
  static ui.Picture? _cache;
  static String _cacheKey = '';

  static const _grass = Color(0xFF6DBE45);
  static const _grassLight = Color(0xFF86D35A);
  static const _grassDark = Color(0xFF5AAA3A);
  static const _stoneEdge = Color(0xFF7F7B70);
  static const _stoneBed = Color(0xFFB9B3A3);
  static const _stone = Color(0xFFDAD5C7);
  static const _stoneLine = Color(0xFF9C9686);

  @override
  void paint(Canvas c, Size size) {
    final key = '$size $cell';
    if (_cache == null || _cacheKey != key) {
      final rec = ui.PictureRecorder();
      _paintField(Canvas(rec), size);
      _cache = rec.endRecording();
      _cacheKey = key;
    }
    c.drawPicture(_cache!);

    // Дальность выбранного тапка.
    final t = selected;
    if (t != null) {
      final (x, y) = t.center;
      final o = Offset((x + ox) * cell, (y + oy) * cell);
      c.drawCircle(o, t.range * cell, Paint()..color = const Color(0x33FFFFFF));
      c.drawCircle(
        o,
        t.range * cell,
        Paint()
          ..color = const Color(0xCCFFFFFF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }

  void _paintField(Canvas c, Size size) {
    final rnd = Random(42);
    c.save();
    c.clipRect(Offset.zero & size);

    // Трава: основа, светлые и тёмные пятна.
    c.drawRect(Offset.zero & size, Paint()..color = _grass);
    for (var i = 0; i < 40; i++) {
      final o = Offset(
        rnd.nextDouble() * size.width,
        rnd.nextDouble() * size.height,
      );
      final r = cell * (0.5 + rnd.nextDouble() * 1.1);
      final color = rnd.nextBool() ? _grassLight : _grassDark;
      c.drawCircle(
        o,
        r,
        Paint()
          ..shader = RadialGradient(
            colors: [color.withValues(alpha: 0.55), color.withValues(alpha: 0)],
          ).createShader(Rect.fromCircle(center: o, radius: r)),
      );
    }
    // Травинки.
    final tuft = Paint()
      ..color = const Color(0xFF4E9A32)
      ..strokeWidth = cell * 0.035
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 70; i++) {
      final o = Offset(
        rnd.nextDouble() * size.width,
        rnd.nextDouble() * size.height,
      );
      final h = cell * (0.08 + rnd.nextDouble() * 0.06);
      c.drawLine(o, o + Offset(-h * 0.5, -h), tuft);
      c.drawLine(o, o + Offset(0, -h * 1.2), tuft);
      c.drawLine(o, o + Offset(h * 0.5, -h), tuft);
    }
    // Цветы: белые и жёлтые.
    for (var i = 0; i < 55; i++) {
      final o = Offset(
        rnd.nextDouble() * size.width,
        rnd.nextDouble() * size.height,
      );
      final r = cell * (0.035 + rnd.nextDouble() * 0.02);
      final petal = rnd.nextDouble() < 0.75
          ? Colors.white
          : const Color(0xFFFFE066);
      for (var k = 0; k < 5; k++) {
        final a = k * 2 * pi / 5;
        c.drawCircle(
          o + Offset(cos(a), sin(a)) * r,
          r * 0.8,
          Paint()..color = petal,
        );
      }
      c.drawCircle(o, r * 0.6, Paint()..color = const Color(0xFFFFB82E));
    }

    // Тропа: тёмный край, подложка и камни — в координатах карты.
    c.save();
    c.translate(ox * cell, oy * cell);
    final path = Path();
    for (var i = 0; i < DefenseMap.waypoints.length; i++) {
      final (x, y) = DefenseMap.waypoints[i];
      final p = Offset((x + 0.5) * cell, (y + 0.5) * cell);
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    Paint road(Color color, double w) => Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = cell * w
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    c.drawPath(
      path.shift(Offset(0, cell * 0.06)),
      road(const Color(0x33000000), 0.92),
    );
    c.drawPath(path, road(_stoneEdge, 0.92));
    c.drawPath(path, road(_stoneBed, 0.8));
    _stones(c, rnd);
    _sugar(c);
    c.restore();

    // Кусты по углам и краям.
    // Доли ширины и высоты поля.
    for (final (bx, by, br) in const [
      (0.0, 0.0, 1.1),
      (1.0, 0.02, 0.9),
      (0.0, 1.0, 1.0),
      (1.0, 0.55, 0.7),
      (0.0, 0.5, 0.6),
      (0.45, 1.0, 0.7),
    ]) {
      _bush(c, Offset(bx * size.width, by * size.height), br * cell, rnd);
    }
    c.restore();
  }

  /// Булыжники вдоль тропы.
  void _stones(Canvas c, Random rnd) {
    final pts = DefenseMap.waypoints;
    for (var i = 0; i < pts.length - 1; i++) {
      final a = Offset(pts[i].$1 + 0.5, pts[i].$2 + 0.5) * cell;
      final b = Offset(pts[i + 1].$1 + 0.5, pts[i + 1].$2 + 0.5) * cell;
      final len = (b - a).distance;
      final n = (b - a) / len;
      final side = Offset(-n.dy, n.dx);
      final step = cell * 0.27;
      for (var d = 0.0; d <= len; d += step) {
        for (final s in const [-0.21, 0.0, 0.21]) {
          if (rnd.nextDouble() < 0.12) continue;
          final o =
              a +
              n * (d + (rnd.nextDouble() - 0.5) * cell * 0.06) +
              side * cell * (s + (rnd.nextDouble() - 0.5) * 0.05);
          final w = cell * (0.19 + rnd.nextDouble() * 0.06);
          final h = cell * (0.15 + rnd.nextDouble() * 0.05);
          c.save();
          c.translate(o.dx, o.dy);
          c.rotate(atan2(n.dy, n.dx) + (rnd.nextDouble() - 0.5) * 0.5);
          final r = RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset.zero, width: w, height: h),
            Radius.circular(h * 0.45),
          );
          c.drawRRect(r, Paint()..color = _stone);
          c.drawRRect(
            r,
            Paint()
              ..color = _stoneLine
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.2,
          );
          // Блик сверху.
          c.drawLine(
            Offset(-w * 0.25, -h * 0.22),
            Offset(w * 0.15, -h * 0.22),
            Paint()
              ..color = Colors.white.withValues(alpha: 0.6)
              ..strokeWidth = 1.2
              ..strokeCap = StrokeCap.round,
          );
          c.restore();
        }
      }
    }
  }

  /// Куст: несколько кругов листвы с бликами.
  void _bush(Canvas c, Offset o, double r, Random rnd) {
    c.drawCircle(
      o + Offset(r * 0.1, r * 0.15),
      r,
      Paint()..color = const Color(0x33000000),
    );
    for (var i = 0; i < 7; i++) {
      final a = rnd.nextDouble() * 2 * pi;
      final d = r * 0.5 * rnd.nextDouble();
      final p = o + Offset(cos(a), sin(a)) * d;
      final rr = r * (0.45 + rnd.nextDouble() * 0.3);
      c.drawCircle(p, rr, Paint()..color = const Color(0xFF3E8E2E));
      c.drawCircle(
        p + Offset(-rr * 0.2, -rr * 0.2),
        rr * 0.7,
        Paint()..color = const Color(0xFF52A83A),
      );
      c.drawCircle(
        p + Offset(-rr * 0.35, -rr * 0.35),
        rr * 0.3,
        Paint()..color = const Color(0xFF6CC24A),
      );
    }
  }

  /// Сахарница в конце тропы.
  void _sugar(Canvas c) {
    final s = DefenseMap.sugar;
    final center = Offset((s.col + 0.5) * cell, (s.row + 0.5) * cell);
    final bowl = Rect.fromCenter(
      center: center + Offset(0, cell * 0.12),
      width: cell * 0.9,
      height: cell * 0.55,
    );
    c.drawOval(
      bowl.shift(Offset(cell * 0.04, cell * 0.1)),
      Paint()..color = const Color(0x40000000),
    );
    c.drawOval(bowl, Paint()..color = Colors.white);
    c.drawOval(
      bowl,
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
  }

  @override
  bool shouldRepaint(_BoardPainter old) =>
      old.selected != selected || old.cell != cell;
}

/// Мягкие тени под жуками — рисуются на траве, под спрайтами.
class _ShadowPainter extends CustomPainter {
  _ShadowPainter({required this.cell, required this.game});
  final double cell;
  final DefenseGame game;

  @override
  void paint(Canvas c, Size size) {
    final paint = Paint()
      ..color = const Color(0x40000000)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);
    for (final b in game.bugs) {
      if (b.dist < 0) continue;
      final (x, y) = b.pos;
      final w = cell * (b.boss ? 1.3 : 0.75);
      c.drawOval(
        Rect.fromCenter(
          center: Offset(x * cell, y * cell + cell * (b.boss ? 0.26 : 0.18)),
          width: w,
          height: w * 0.3,
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_ShadowPainter old) => true;
}

/// Где встанет перетаскиваемый тапок: круг дальности, красный — нельзя.
class _GhostPainter extends CustomPainter {
  _GhostPainter({
    required this.cell,
    required this.x,
    required this.y,
    required this.range,
    required this.ok,
  });
  final double cell;
  final double x;
  final double y;
  final double range;
  final bool ok;

  @override
  void paint(Canvas c, Size size) {
    final o = Offset(x * cell, y * cell);
    final color = ok ? Colors.white : const Color(0xFFFF4D4D);
    c.drawCircle(
      o,
      range * cell,
      Paint()..color = color.withValues(alpha: 0.2),
    );
    c.drawCircle(
      o,
      range * cell,
      Paint()
        ..color = color.withValues(alpha: 0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    // Пятно под тапком: сколько места он занимает.
    c.drawCircle(
      o,
      DefenseGame.towerGap / 2 * cell,
      Paint()..color = color.withValues(alpha: 0.35),
    );
  }

  @override
  bool shouldRepaint(_GhostPainter old) =>
      old.x != x || old.y != y || old.ok != ok;
}

/// Удары и снаряды тапков: пинок, холод, молния, огонь, когти, лазер, волна.
class _ShotsPainter extends CustomPainter {
  _ShotsPainter({
    required this.cell,
    required this.shots,
    required this.missiles,
  });
  final double cell;
  final List<Shot> shots;
  final List<Missile> missiles;

  static const _rainbow = [
    Color(0xFFFF4D6D),
    Color(0xFFFFB03A),
    Color(0xFFFFF35C),
    Color(0xFF5CFF8F),
    Color(0xFF4FD8FF),
    Color(0xFFB06BFF),
  ];

  Offset _o((double, double) p) => Offset(p.$1 * cell, p.$2 * cell);

  @override
  void paint(Canvas c, Size size) {
    for (final s in shots) {
      final t = (s.age / s.life).clamp(0.0, 1.0);
      final from = _o(s.from);
      final to = _o(s.to);
      switch (s.fx) {
        case ShotFx.kick:
          _kick(c, to, t);
        case ShotFx.frost:
          _frost(c, from, to, t);
        case ShotFx.lightning:
          _lightning(c, from, to, t, s.seed);
        case ShotFx.explosion:
          _explosion(c, to, s.radius * cell, t);
        case ShotFx.nova:
          _nova(c, from, s.radius * cell, t);
        case ShotFx.slash:
          _slash(c, from, to, t, s.seed);
        case ShotFx.laser:
          _laser(c, from, to, t, 1);
        case ShotFx.laserLong:
          _laser(c, from, to, t, 1.6);
      }
    }
    for (final m in missiles) {
      switch (m.kind) {
        case MissileKind.fireball:
          _fireball(c, m);
        case MissileKind.wave:
          _wave(c, m);
      }
    }
  }

  /// Пинок: белая вспышка-звезда у цели, без линии.
  void _kick(Canvas c, Offset at, double t) {
    final a = (1 - t);
    final r = cell * (0.12 + 0.3 * Curves.easeOut.transform(t));
    c.drawCircle(
      at,
      r,
      Paint()..color = Colors.white.withValues(alpha: 0.35 * a),
    );
    final ray = Paint()
      ..color = Colors.white.withValues(alpha: a)
      ..strokeWidth = cell * 0.06
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 6; i++) {
      final ang = i * pi / 3 + 0.3;
      final d = Offset(cos(ang), sin(ang));
      c.drawLine(at + d * r * 0.6, at + d * r * 1.2, ray);
    }
  }

  /// Холод: голубое облачко летит от тапка к цели, у цели — снежинка.
  void _frost(Canvas c, Offset from, Offset to, double t) {
    final a = sin(pi * t).clamp(0.0, 1.0);
    final dir = to - from;
    final len = dir.distance;
    if (len == 0) return;
    final n = dir / len;
    final side = Offset(-n.dy, n.dx);
    // Мягкий конус холода.
    final cone = Path()
      ..moveTo(from.dx, from.dy)
      ..lineTo((to + side * cell * 0.32).dx, (to + side * cell * 0.32).dy)
      ..lineTo((to - side * cell * 0.32).dx, (to - side * cell * 0.32).dy)
      ..close();
    c.drawPath(
      cone,
      Paint()..color = const Color(0xFFBFEFFF).withValues(alpha: 0.28 * a),
    );
    // Летящие хлопья.
    final rnd = Random(7);
    for (var i = 0; i < 9; i++) {
      final k = ((i / 9) + t * 0.8) % 1.0;
      final spread = (rnd.nextDouble() - 0.5) * cell * 0.55 * k;
      final p = from + n * len * k + side * spread;
      c.drawCircle(
        p,
        cell * (0.035 + 0.04 * k),
        Paint()..color = Colors.white.withValues(alpha: 0.85 * a),
      );
    }
    // Снежинка на цели.
    final flake = Paint()
      ..color = const Color(0xFF7FDBFF).withValues(alpha: a)
      ..strokeWidth = cell * 0.045
      ..strokeCap = StrokeCap.round;
    final r = cell * 0.22 * (0.6 + 0.4 * t);
    for (var i = 0; i < 3; i++) {
      final ang = i * pi / 3 + t;
      final d = Offset(cos(ang), sin(ang)) * r;
      c.drawLine(to - d, to + d, flake);
    }
  }

  /// Молния: ломаная линия с фиолетовым свечением, мерцает.
  void _lightning(Canvas c, Offset from, Offset to, double t, int seed) {
    final flicker = (t * 12).floor().isEven ? 1.0 : 0.6;
    final a = (1 - t) * flicker;
    final rnd = Random(seed);
    final dir = to - from;
    final len = dir.distance;
    if (len == 0) return;
    final side = Offset(-dir.dy, dir.dx) / len;
    final path = Path()..moveTo(from.dx, from.dy);
    const segs = 7;
    for (var i = 1; i < segs; i++) {
      final p =
          from +
          dir * (i / segs) +
          side * (rnd.nextDouble() - 0.5) * cell * 0.35;
      path.lineTo(p.dx, p.dy);
    }
    path.lineTo(to.dx, to.dy);
    c.drawPath(
      path,
      Paint()
        ..color = const Color(0xFFC77DFF).withValues(alpha: 0.55 * a)
        ..style = PaintingStyle.stroke
        ..strokeWidth = cell * 0.16
        ..strokeJoin = StrokeJoin.round,
    );
    c.drawPath(
      path,
      Paint()
        ..color = Colors.white.withValues(alpha: a)
        ..style = PaintingStyle.stroke
        ..strokeWidth = cell * 0.045
        ..strokeJoin = StrokeJoin.round,
    );
    c.drawCircle(
      to,
      cell * 0.14 * (1 - t),
      Paint()..color = const Color(0xFFFFF59D).withValues(alpha: a),
    );
  }

  /// Взрыв огненного шара.
  void _explosion(Canvas c, Offset at, double radius, double t) {
    final a = 1 - t;
    final r = radius * Curves.easeOut.transform(t).clamp(0.25, 1.0);
    c.drawCircle(
      at,
      r,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFFFF3B0).withValues(alpha: a),
            const Color(0xFFFF9F43).withValues(alpha: 0.8 * a),
            const Color(0xFFE8452C).withValues(alpha: 0.0),
          ],
          stops: const [0, 0.45, 1],
        ).createShader(Rect.fromCircle(center: at, radius: r)),
    );
  }

  /// Ударная волна Карбона: огненное кольцо от тапка.
  void _nova(Canvas c, Offset at, double radius, double t) {
    final a = 1 - t;
    final r = radius * Curves.easeOutCubic.transform(t);
    c.drawCircle(
      at,
      r,
      Paint()..color = const Color(0xFFFF9F43).withValues(alpha: 0.18 * a),
    );
    c.drawCircle(
      at,
      r,
      Paint()
        ..color = const Color(0xFFFFC56B).withValues(alpha: a)
        ..style = PaintingStyle.stroke
        ..strokeWidth = cell * 0.14 * a + 1,
    );
  }

  /// Когти Адского: три красных росчерка поперёк цели.
  void _slash(Canvas c, Offset from, Offset to, double t, int streak) {
    final a = 1 - t;
    final grow = Curves.easeOut.transform((t / 0.4).clamp(0.0, 1.0));
    final dir = to - from;
    final len = dir.distance;
    final n = len == 0 ? const Offset(1, 0) : dir / len;
    // Росчерк идёт по диагонали к направлению удара.
    final cut = Offset(n.dx * 0.6 - n.dy * 0.8, n.dy * 0.6 + n.dx * 0.8);
    final side = Offset(-cut.dy, cut.dx);
    // Чем дольше режет одну цель, тем ярче.
    final hot = Color.lerp(
      const Color(0xFFFF4D4D),
      const Color(0xFFFFD84D),
      streak / 5,
    )!;
    for (var i = -1; i <= 1; i++) {
      final start = to - cut * cell * 0.35 + side * cell * 0.13 * i.toDouble();
      final end = start + cut * cell * 0.7 * grow;
      c.drawLine(
        start,
        end,
        Paint()
          ..color = hot.withValues(alpha: 0.7 * a)
          ..strokeWidth = cell * 0.1
          ..strokeCap = StrokeCap.round,
      );
      c.drawLine(
        start,
        end,
        Paint()
          ..color = Colors.white.withValues(alpha: a)
          ..strokeWidth = cell * 0.03
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  /// Радужный лазер, как в основной игре: свечение-радуга и белое ядро.
  void _laser(Canvas c, Offset from, Offset to, double t, double width) {
    final a = sin(pi * t).clamp(0.0, 1.0);
    final len = Curves.easeOutQuart.transform((t / 0.35).clamp(0.0, 1.0));
    final end = Offset.lerp(from, to, len)!;
    final shader = LinearGradient(
      colors: _rainbow,
    ).createShader(Rect.fromPoints(from, to));
    c.drawLine(
      from,
      end,
      Paint()
        ..shader = shader
        ..strokeCap = StrokeCap.round
        ..strokeWidth = cell * 0.3 * width * a,
    );
    c.drawLine(
      from,
      end,
      Paint()
        ..color = Colors.white.withValues(alpha: a)
        ..strokeCap = StrokeCap.round
        ..strokeWidth = cell * 0.08 * width * a,
    );
    c.drawCircle(
      from,
      cell * 0.12 * a,
      Paint()..color = Colors.white.withValues(alpha: a),
    );
  }

  /// Огненный шар с хвостом.
  void _fireball(Canvas c, Missile m) {
    final at = _o(m.pos);
    final back = Offset(m.dir.$1, m.dir.$2) * -cell;
    for (var i = 3; i >= 1; i--) {
      c.drawCircle(
        at + back * 0.12 * i.toDouble(),
        cell * (0.15 - 0.03 * i),
        Paint()
          ..color = const Color(0xFFFF6B2C).withValues(alpha: 0.5 - 0.12 * i),
      );
    }
    c.drawCircle(at, cell * 0.17, Paint()..color = const Color(0xFFFF7A2C));
    c.drawCircle(at, cell * 0.09, Paint()..color = const Color(0xFFFFF3B0));
  }

  /// Воздушная волна Инь-Яна: дуги поперёк полёта шириной 1.5 клетки.
  void _wave(Canvas c, Missile m) {
    final total = m.tower.range + 0.4;
    final k = (1 - m.travel / total).clamp(0.0, 1.0);
    final a = k < 0.15 ? k / 0.15 : (1 - k).clamp(0.0, 1.0) / 0.85;
    final at = _o(m.pos);
    c.save();
    c.translate(at.dx, at.dy);
    c.rotate(atan2(m.dir.$2, m.dir.$1));
    final h = Missile.waveHalfWidth * cell;
    for (var i = 0; i < 3; i++) {
      final rect = Rect.fromCenter(
        center: Offset(-cell * (0.18 * i + 0.25), 0),
        width: cell * 0.5,
        height: h * 2 * (1 - 0.15 * i),
      );
      c.drawArc(
        rect,
        -pi / 2,
        pi,
        false,
        Paint()
          ..color = (i == 0 ? Colors.white : const Color(0xFFD9F2FF))
              .withValues(alpha: a * (0.9 - 0.25 * i))
          ..style = PaintingStyle.stroke
          ..strokeWidth = cell * (0.1 - 0.025 * i)
          ..strokeCap = StrokeCap.round,
      );
    }
    c.restore();
  }

  @override
  bool shouldRepaint(_ShotsPainter old) => true;
}

/// Строка характеристики: сейчас → после улучшения.
class _StatLine extends StatelessWidget {
  const _StatLine({required this.label, required this.now, this.next});
  final String label;
  final String now;
  final String? next;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GamePanel(
      color: GameColors.panelDark,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Text(label, style: theme.textTheme.bodyMedium),
          const Spacer(),
          Text(now, style: theme.textTheme.titleSmall),
          if (next != null) ...[
            const SizedBox(width: 6),
            const Icon(
              Icons.arrow_forward_rounded,
              size: 16,
              color: GameColors.textDim,
            ),
            const SizedBox(width: 6),
            Text(
              next!,
              style: theme.textTheme.titleSmall?.copyWith(
                color: GameColors.green,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Способность ★3: описание; закрыта — с замком и звездой.
class _AbilityBox extends StatelessWidget {
  const _AbilityBox({required this.tower});
  final Tower tower;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final open = tower.hasAbility;
    return GamePanel(
      color: open ? GameColors.panelLight : GameColors.panelDark,
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: open ? GameColors.gold : GameColors.panel,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: GameColors.outline, width: 2.5),
            ),
            child: Icon(
              open ? Icons.auto_awesome_rounded : Icons.lock_rounded,
              size: 18,
              color: open ? GameColors.outline : GameColors.textDim,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        tower.spec.ability,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: open ? GameColors.text : GameColors.textDim,
                        ),
                      ),
                    ),
                    if (!open) ...[
                      const SizedBox(width: 6),
                      Text(
                        '★${Tower.abilityLevel}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: GameColors.gold,
                        ),
                      ),
                    ],
                  ],
                ),
                Text(tower.spec.abilityText, style: theme.textTheme.bodySmall),
                if (!open)
                  Text(
                    'Откроется на ★${Tower.abilityLevel} — улучши тапок здесь',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: GameColors.gold,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Тапок-защитник: смотрит на цель и бьёт своей анимацией. Удар случается
/// в начале анимации — в тот же миг, когда появляется эффект.
class _TowerSprite extends StatelessWidget {
  const _TowerSprite({required this.tower, required this.cell});
  final Tower tower;
  final double cell;

  @override
  Widget build(BuildContext context) {
    final t = tower;
    final role = t.spec.role;
    // Адский режет сериями — его взмах короче.
    final anim = role == TowerRole.slash ? 0.2 : 0.36;
    final active = t.sinceShot < anim;
    final p = active ? t.sinceShot / anim : 1.0;
    final dx = cos(t.aim);
    final dy = sin(t.aim);
    final dir = Offset(dx, dy);
    // Носок на цель: справа — как есть, слева — зеркально, чтобы не висеть
    // вверх ногами.
    final flip = dx < 0;
    // Знак поворота «носком вверх» с учётом зеркала.
    final up = flip ? 1.0 : -1.0;
    var angle = flip ? t.aim - pi : t.aim;
    var offset = Offset.zero;
    var scaleX = 1.0;
    var scaleY = 1.0;
    Color? glow;
    var glowSize = 0.0;

    // Быстрый выброс к пику на [peak] и плавный возврат.
    double snap(double peak) => !active
        ? 0
        : p < peak
        ? Curves.easeOut.transform(p / peak)
        : 1 - Curves.easeInOut.transform((p - peak) / (1 - peak));

    switch (role) {
      case TowerRole.strike:
        // Пыр: резкий тычок носком к цели.
        final k = snap(0.2);
        offset = dir * cell * 0.34 * k;
        angle += up * -0.15 * k;
      case TowerRole.frost:
        // Выдох холода: тапок раздувается и подаётся вперёд, вокруг иней.
        final k = snap(0.25);
        offset = dir * cell * 0.1 * k;
        scaleX = 1 + 0.12 * k;
        scaleY = 1 + 0.08 * k;
        glow = const Color(0xFF9FE6FF);
        glowSize = k;
      case TowerRole.fireball:
        // Запуск шара: отдача назад, носок вверх, огонь у носка.
        final k = snap(0.18);
        offset = -dir * cell * 0.18 * k;
        angle += up * 0.35 * k;
        glow = const Color(0xFFFF8A3D);
        glowSize = k;
        if (t.special && active) {
          // Ударная волна: подпрыгивает и бьёт о пол.
          offset = Offset(0, -cell * 0.25 * snap(0.3));
          scaleY = 1 - 0.2 * snap(0.3);
          scaleX = 1 + 0.15 * snap(0.3);
        }
      case TowerRole.lightning:
        // Разряд: дрожь и электрическая вспышка.
        final k = snap(0.15);
        offset = Offset(
          sin(p * 50) * cell * 0.06 * k,
          cos(p * 37) * cell * 0.03 * k,
        );
        scaleX = scaleY = 1 + 0.12 * k;
        glow = (p * 10).floor().isEven
            ? const Color(0xFFC77DFF)
            : const Color(0xFFFFF59D);
        glowSize = k;
      case TowerRole.slash:
        // Резанье: взмах по диагонали сверху вниз с подшагом к цели.
        if (active) {
          final k = Curves.easeOutCubic.transform(p);
          angle += up * (0.7 - 1.4 * k) * (1 - p * 0.5);
          offset = dir * cell * 0.15 * sin(pi * p);
        }
        if (t.special && active) {
          glow = const Color(0xFFFF4D4D);
          glowSize = 0.7;
        }
      case TowerRole.laser:
        // Луч: заряд у носка, отдача назад и носок вверх.
        final k = snap(0.15);
        offset = -dir * cell * 0.2 * k;
        angle += up * 0.25 * k;
        glow = Colors.white;
        glowSize = k * (t.special ? 1.3 : 0.8);
      case TowerRole.wave:
        // Взмах веером: замах назад и широкая отмашка вперёд.
        if (active) {
          final double swing;
          if (p < 0.12) {
            swing = -0.6 * Curves.easeOut.transform(p / 0.12);
          } else if (p < 0.4) {
            swing =
                -0.6 + 1.2 * Curves.easeOutBack.transform((p - 0.12) / 0.28);
          } else {
            swing = 0.6 * (1 - Curves.easeInOut.transform((p - 0.4) / 0.6));
          }
          angle += up * -swing;
          offset = dir * cell * 0.1 * sin(pi * p);
        }
    }
    Widget sprite = SlipperSprite(
      fighter: Slipper(name: t.kindId, kindId: t.kindId),
      width: cell * 1.2,
      animate: false,
      showSize: false,
    );
    if (flip) sprite = Transform.flip(flipX: true, child: sprite);
    return Transform.translate(
      offset: offset,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          if (glow != null && glowSize > 0)
            Transform.translate(
              // Свечение у носка: со стороны цели.
              offset: dir * cell * 0.3,
              child: Container(
                width: cell * 0.9 * glowSize,
                height: cell * 0.9 * glowSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      glow.withValues(alpha: 0.8 * glowSize.clamp(0.0, 1.0)),
                      glow.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
          Transform.rotate(
            angle: angle,
            child: Transform.scale(
              scaleX: scaleX,
              scaleY: scaleY,
              child: sprite,
            ),
          ),
        ],
      ),
    );
  }
}
