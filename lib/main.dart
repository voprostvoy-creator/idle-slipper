import 'package:flutter/material.dart';

import 'game/game_state.dart';
import 'ui/format.dart';
import 'ui/screens/arena_screen.dart';
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

class _RootShellState extends State<RootShell> {
  int _tab = 0;

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
    if (game.pendingOfflineThreads <= 0 || _offlineDialogOpen || !mounted)
      return;
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
      HomeScreen(game: game),
      ArenaScreen(game: game),
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
                child: IndexedStack(index: _tab, children: pages),
              ),
            ],
          ),
        ),
      ),
    );
    return Scaffold(
      body: GameBackground(child: content),
      bottomNavigationBar: _GameNavBar(
        index: _tab,
        onChanged: (i) => setState(() => _tab = i),
      ),
    );
  }
}

/// Нижняя навигация в стиле игры: панель с тремя объёмными кнопками.
class _GameNavBar extends StatelessWidget {
  const _GameNavBar({required this.index, required this.onChanged});
  final int index;
  final ValueChanged<int> onChanged;

  static const _items = [
    (Icons.home_rounded, 'Тапок'),
    (Icons.sports_mma_rounded, 'Арена'),
    (Icons.storefront_rounded, 'Магазин'),
    (Icons.person_rounded, 'Профиль'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        8,
        8,
        8,
        8 + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: const BoxDecoration(
        color: GameColors.panelDark,
        border: Border(top: BorderSide(color: GameColors.outline, width: 3)),
      ),
      child: Row(
        children: [
          for (final (i, (icon, label)) in _items.indexed) ...[
            if (i > 0) const SizedBox(width: 6),
            Expanded(
              child: GameButton(
                height: 50,
                color: i == index ? GameColors.gold : GameColors.panelLight,
                onPressed: () => onChanged(i),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      icon,
                      size: 22,
                      color: i == index ? GameColors.outline : GameColors.text,
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
                          color: i == index
                              ? GameColors.outline
                              : GameColors.text,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
