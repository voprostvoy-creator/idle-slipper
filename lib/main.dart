import 'dart:math';

import 'package:flutter/material.dart';

import 'game/game_state.dart';
import 'ui/format.dart';
import 'ui/screens/battle_hub_screen.dart';
import 'ui/screens/collection_screen.dart';
import 'ui/screens/home_screen.dart';
import 'ui/screens/rating_screen.dart';
import 'ui/screens/shop_screen.dart';
import 'ui/theme.dart';
import 'ui/widgets/game_widgets.dart';
import 'ui/widgets/resource_header.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final game = await GameState.load();
  runApp(SlipperApp(game: game));
}

class SlipperApp extends StatelessWidget {
  const SlipperApp({super.key, required this.game});
  final GameState game;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Бои Тапков',
      debugShowCheckedModeBanner: false,
      theme: buildGameTheme(),
      home: RootShell(game: game),
    );
  }
}

class RootShell extends StatefulWidget {
  const RootShell({super.key, required this.game});
  final GameState game;

  @override
  State<RootShell> createState() => _RootShellState();
}

/// Вкладки нижнего меню. «В бой» — центральная, крупная.
enum _Tab { home, collection, battle, shop, profile }

class _RootShellState extends State<RootShell> {
  _Tab _tab = _Tab.home;

  /// Открытый режим во вкладке «В бой»; null — экран выбора режима.
  BattleMode? _battleMode;

  void _select(_Tab tab) => setState(() {
    // Повторное нажатие на «В бой» возвращает к выбору режима.
    if (tab == _Tab.battle && _tab == _Tab.battle) _battleMode = null;
    _tab = tab;
  });

  @override
  void initState() {
    super.initState();
    widget.game.addListener(_maybeShowOffline);
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowOffline());
  }

  @override
  void dispose() {
    widget.game.removeListener(_maybeShowOffline);
    super.dispose();
  }

  bool _offlineDialogOpen = false;

  /// Показывает «пока тебя не было…» один раз на каждое возвращение.
  void _maybeShowOffline() {
    final game = widget.game;
    if (game.pendingOfflineThreads <= 0 || _offlineDialogOpen || !mounted) {
      return;
    }
    _offlineDialogOpen = true;
    final threads = game.pendingOfflineThreads;
    final away = game.pendingOfflineDuration;
    game.acknowledgeOffline();
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const StrokeText('С возвращением!', size: 22),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Пока тебя не было (${fmtDuration(away)}), тапок заработал:'),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const ThreadIcon(size: 28),
                const SizedBox(width: 8),
                StrokeText(
                  fmtNum(threads.floor()),
                  size: 28,
                  color: GameColors.thread,
                ),
              ],
            ),
          ],
        ),
        actions: [
          GameButton(
            color: GameColors.green,
            onPressed: () => Navigator.pop(context),
            child: const Text('Забрать'),
          ),
        ],
      ),
    ).whenComplete(() => _offlineDialogOpen = false);
  }

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    final pages = [
      HomeScreen(game: game, onOpenCollection: () => _select(_Tab.collection)),
      CollectionScreen(game: game),
      BattleHubScreen(
        game: game,
        mode: _battleMode,
        onMode: (m) => setState(() => _battleMode = m),
      ),
      ShopScreen(game: game),
      RatingScreen(game: game),
    ];
    // Главная идёт на фоне комнаты, остальные вкладки — на обычном фоне.
    final content = SafeArea(
      child: Center(
        // На широком экране держим мобильную ширину.
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                child: ResourceHeader(game: game),
              ),
              Expanded(
                child: IndexedStack(index: _tab.index, children: pages),
              ),
            ],
          ),
        ),
      ),
    );
    return Scaffold(
      body: GameBackground(child: content),
      bottomNavigationBar: ListenableBuilder(
        listenable: game,
        builder: (context, _) => _GameNavBar(
          tab: _tab,
          onChanged: _select,
          // Точка — есть что забрать: награда за задание или ежедневный кейс.
          dots: {
            if (game.questsReady) _Tab.home,
            if (game.dailyCaseAvailable) _Tab.shop,
          },
        ),
      ),
    );
  }
}

/// Нижняя навигация: четыре вкладки по бокам и крупная кнопка «В бой»
/// посередине, приподнятая над панелью.
class _GameNavBar extends StatelessWidget {
  const _GameNavBar({
    required this.tab,
    required this.onChanged,
    this.dots = const {},
  });
  final _Tab tab;
  final ValueChanged<_Tab> onChanged;
  final Set<_Tab> dots;

  static const _side = [
    (_Tab.home, Icons.home_rounded, 'Тапок'),
    (_Tab.collection, Icons.checkroom_rounded, 'Коллекция'),
    (_Tab.shop, Icons.storefront_rounded, 'Магазин'),
    (_Tab.profile, Icons.person_rounded, 'Профиль'),
  ];

  /// Насколько центральная кнопка выступает над панелью.
  static const _lift = 18.0;

  /// Зазор между кнопками меню.
  static const _gap = 3.0;

  @override
  Widget build(BuildContext context) {
    Widget sideButton((_Tab, IconData, String) item) {
      final (t, icon, label) = item;
      final active = t == tab;
      final button = GameButton(
        height: 50,
        color: active ? GameColors.gold : GameColors.panelLight,
        padding: const EdgeInsets.symmetric(horizontal: 2),
        onPressed: () => onChanged(t),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 21,
              color: active ? GameColors.outline : GameColors.text,
            ),
            // На узких экранах подпись ужимается, а не переносится.
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                softWrap: false,
                style: TextStyle(
                  fontSize: 11,
                  color: active ? GameColors.outline : GameColors.text,
                ),
              ),
            ),
          ],
        ),
      );
      return Expanded(
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            button,
            if (dots.contains(t))
              Positioned(
                top: -3,
                right: -2,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: GameColors.red,
                    border: Border.all(color: GameColors.outline, width: 2),
                  ),
                ),
              ),
          ],
        ),
      );
    }

    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        Container(
          padding: EdgeInsets.fromLTRB(4, 8, 4, 8 + bottomInset),
          decoration: const BoxDecoration(
            color: GameColors.panelDark,
            border: Border(
              top: BorderSide(color: GameColors.outline, width: 3),
            ),
          ),
          child: Row(
            children: [
              sideButton(_side[0]),
              const SizedBox(width: _gap),
              sideButton(_side[1]),
              // Место под центральную кнопку — вплотную к ней.
              const SizedBox(width: _FightButtonState._size + _gap * 2),
              sideButton(_side[2]),
              const SizedBox(width: _gap),
              sideButton(_side[3]),
            ],
          ),
        ),
        Positioned(
          top: -_lift,
          child: _FightButton(
            active: tab == _Tab.battle,
            onTap: () => onChanged(_Tab.battle),
          ),
        ),
      ],
    );
  }
}

/// Центральная кнопка «В бой»: крупная, красная, со скрещёнными мечами.
class _FightButton extends StatefulWidget {
  const _FightButton({required this.active, required this.onTap});
  final bool active;
  final VoidCallback onTap;

  @override
  State<_FightButton> createState() => _FightButtonState();
}

class _FightButtonState extends State<_FightButton> {
  bool _down = false;

  static const _size = 76.0;
  static const _depth = 5.0;

  @override
  Widget build(BuildContext context) {
    final color = widget.active ? GameColors.gold : GameColors.red;
    final light = Color.lerp(color, Colors.white, 0.35)!;
    final dark = Color.lerp(color, Colors.black, 0.45)!;
    final sink = _down ? _depth - 1 : 0.0;
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      onTap: widget.onTap,
      child: SizedBox(
        width: _size,
        height: _size + _depth,
        child: Stack(
          children: [
            // Нижняя плита — объём, как у остальных игровых кнопок.
            Positioned(
              top: _depth,
              child: Container(
                width: _size,
                height: _size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: dark,
                  border: Border.all(color: GameColors.outline, width: 3.5),
                ),
              ),
            ),
            Positioned(
              top: sink,
              child: Container(
                width: _size,
                height: _size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    center: const Alignment(-0.3, -0.4),
                    colors: [light, color],
                  ),
                  border: Border.all(color: GameColors.outline, width: 3.5),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x66000000),
                      blurRadius: 8,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CustomPaint(
                      size: Size(32, 32),
                      painter: _SwordsPainter(),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      'В БОЙ',
                      style: const TextStyle(
                        color: GameColors.outline,
                        fontSize: 12,
                        height: 1,
                        fontVariations: [FontVariation('wght', 900)],
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Два скрещённых меча — значок кнопки «В бой».
class _SwordsPainter extends CustomPainter {
  const _SwordsPainter();

  @override
  void paint(Canvas c, Size size) {
    final s = size.width;
    for (final angle in [-pi / 4, pi / 4]) {
      c.save();
      c.translate(s / 2, s / 2);
      c.rotate(angle);
      // Клинок.
      final blade = Path()
        ..moveTo(0, -s * 0.46)
        ..lineTo(s * 0.07, -s * 0.34)
        ..lineTo(s * 0.07, s * 0.14)
        ..lineTo(-s * 0.07, s * 0.14)
        ..lineTo(-s * 0.07, -s * 0.34)
        ..close();
      c.drawPath(blade, Paint()..color = const Color(0xFFE6E9EE));
      c.drawPath(
        blade,
        Paint()
          ..color = GameColors.outline
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * 0.05
          ..strokeJoin = StrokeJoin.round,
      );
      // Гарда и рукоять.
      final guard = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(0, s * 0.17),
          width: s * 0.34,
          height: s * 0.09,
        ),
        Radius.circular(s * 0.03),
      );
      c.drawRRect(guard, Paint()..color = GameColors.gold);
      c.drawRRect(
        guard,
        Paint()
          ..color = GameColors.outline
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * 0.045,
      );
      final grip = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(0, s * 0.33),
          width: s * 0.1,
          height: s * 0.2,
        ),
        Radius.circular(s * 0.03),
      );
      c.drawRRect(grip, Paint()..color = const Color(0xFF6B4A2F));
      c.drawRRect(
        grip,
        Paint()
          ..color = GameColors.outline
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * 0.045,
      );
      c.restore();
    }
  }

  @override
  bool shouldRepaint(_SwordsPainter old) => false;
}
