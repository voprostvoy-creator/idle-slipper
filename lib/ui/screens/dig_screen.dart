import 'package:flutter/material.dart';

import '../../game/daily.dart';
import '../../game/dig.dart';
import '../../game/game_state.dart';
import '../format.dart';
import '../gem_icon.dart';
import '../slipper_sprite.dart';
import '../theme.dart';
import '../widgets/game_widgets.dart';
import 'battle_hub_screen.dart';
import 'battle_screen.dart';
import 'shop_screen.dart';

/// «Под диваном»: поле пыли 6×8, каждый взмах тапком снимает слой.
/// Под пылью — нитки, монеты, гемы, клад и насекомые-стражи.
/// Цифра на расчищенной клетке — сколько гемов спрятано рядом.
class DigScreen extends StatelessWidget {
  const DigScreen({super.key, required this.game, required this.onBack});

  final GameState game;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListenableBuilder(
      listenable: game,
      builder: (context, _) {
        final board = game.digBoard;
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          children: [
            BackToModes(title: 'Под диваном', onBack: onBack),
            const SizedBox(height: 10),
            GamePanel(
              color: GameColors.panelDark,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.back_hand_rounded, color: GameColors.orange, size: 22),
                  const SizedBox(width: 6),
                  Text(
                    '${game.digSwingsLeft}',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Ещё взмахи — за задания дня',
                      style: theme.textTheme.bodySmall,
                      textAlign: TextAlign.end,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Под каждой клеткой что-то есть, одна клетка — один взмах. '
              'Цифра — сколько гемов спрятано рядом. '
              'Новое поле через ${fmtClock(untilMidnight(game.clock()))}.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 10),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: DigBoard.cols,
                mainAxisSpacing: 5,
                crossAxisSpacing: 5,
              ),
              itemCount: DigBoard.size,
              itemBuilder: (context, i) => _DigCellView(
                game: game,
                board: board,
                index: i,
                onTap: () => _tap(context, board, i),
              ),
            ),
          ],
        );
      },
    );
  }

  void _toast(BuildContext context, String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text), duration: const Duration(milliseconds: 1400)));
  }

  void _tap(BuildContext context, DigBoard board, int i) {
    if (game.digGuardWaiting(i)) {
      _guardDialog(context, i);
      return;
    }
    if (game.digRevealed(i)) return;
    if (game.digSwingsLeft == 0) {
      _toast(context, 'Взмахи на сегодня кончились — завтра новое поле');
      return;
    }
    final out = game.dig(i);
    if (out == null || !out.revealed) return;
    final gem = out.gem;
    final text = switch (board.cells[i].loot) {
      DigLoot.threads => '+${fmtNum(out.threads)} ниток',
      DigLoot.coins => '+${out.coins} монет',
      DigLoot.gem => 'Гем! ${gemTitle(gem!)}',
      DigLoot.treasure => 'Клад! ${gemTitle(gem!)}',
      DigLoot.guard => 'Страж! Победи его, чтобы забрать гем',
      DigLoot.empty => 'Пусто',
    };
    _toast(context, text);
  }

  Future<void> _guardDialog(BuildContext context, int i) async {
    final enemy = game.digGuard(i);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: StrokeText(enemy.name, size: 20),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SlipperSprite(fighter: enemy, width: 180, flip: true, showSize: false),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const PowerIcon(size: 18),
                const SizedBox(width: 4),
                Text('${enemy.power}  (у тебя ${game.slipper.power})'),
              ],
            ),
            const SizedBox(height: 6),
            const Text('Сторожит редкий гем. Бой стоит один взмах.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Потом'),
          ),
          GameButton(
            color: GameColors.red,
            onPressed: game.digSwingsLeft > 0 ? () => Navigator.pop(context, true) : null,
            child: const Text('В бой'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final me = game.slipper;
    final out = game.fightDigGuard(i);
    if (out == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BattleScreen(
          player: me,
          opponent: out.enemy,
          result: out.result,
          rewardGem: out.gem,
          exitLabel: 'Под диван',
        ),
      ),
    );
  }
}

class _DigCellView extends StatelessWidget {
  const _DigCellView({
    required this.game,
    required this.board,
    required this.index,
    required this.onTap,
  });

  final GameState game;
  final DigBoard board;
  final int index;
  final VoidCallback onTap;

  static const _dust = [Color(0xFF8C7A64), Color(0xFF6F5E4B), Color(0xFF524436)];

  @override
  Widget build(BuildContext context) {
    final layers = game.digLayers.length > index ? game.digLayers[index] : 1;
    final cell = board.cells[index];
    final Widget child;
    if (layers > 0) {
      // Пыль: чем больше слоёв, тем темнее и тем больше крошек.
      child = Container(
        decoration: BoxDecoration(
          color: _dust[(layers - 1).clamp(0, 2)],
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: GameColors.outline, width: 2),
        ),
        child: CustomPaint(painter: _CrumbsPainter(layers: layers, seed: index)),
      );
    } else {
      final taken = game.digTaken.contains(index);
      final hint = board.hintAt(index);
      final content = switch (cell.loot) {
        DigLoot.threads => const ThreadIcon(size: 26),
        DigLoot.coins => const CoinIcon(size: 26),
        DigLoot.gem || DigLoot.treasure => Icon(
            cell.loot == DigLoot.treasure ? Icons.auto_awesome : Icons.diamond_rounded,
            size: 26,
            color: cell.gemRarity!.color,
          ),
        DigLoot.guard => taken
            ? const Icon(Icons.check_rounded, color: GameColors.green, size: 26)
            : SlipperSprite(
                fighter: game.digGuard(index),
                width: 46,
                flip: true,
                animate: false,
                showSize: false,
              ),
        DigLoot.empty => hint > 0
            ? Text(
                '$hint',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                  color: hint >= 3 ? GameColors.gold : GameColors.text,
                ),
              )
            : const SizedBox.shrink(),
      };
      final waiting = game.digGuardWaiting(index);
      child = Container(
        decoration: BoxDecoration(
          color: waiting ? const Color(0xFF5A2233) : GameColors.panelDark,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
            color: waiting ? GameColors.red : GameColors.outline,
            width: waiting ? 2.5 : 2,
          ),
        ),
        child: Stack(
          children: [
            Center(
              child: Opacity(
                opacity: taken && cell.loot != DigLoot.guard ? 0.45 : 1,
                child: content,
              ),
            ),
            // Подсказка и на клетках с находкой — мелко в углу.
            if (cell.loot != DigLoot.empty && hint > 0)
              Positioned(
                right: 3,
                top: 1,
                child: Text(
                  '$hint',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: GameColors.textDim,
                  ),
                ),
              ),
          ],
        ),
      );
    }
    return GestureDetector(onTap: onTap, child: child);
  }
}

/// Крошки и пылинки на неразрытой клетке.
class _CrumbsPainter extends CustomPainter {
  _CrumbsPainter({required this.layers, required this.seed});

  final int layers;
  final int seed;

  @override
  void paint(Canvas c, Size size) {
    final light = Paint()..color = const Color(0x55FFF3DC);
    final dark = Paint()..color = const Color(0x55000000);
    var x = seed * 37 % 100;
    for (var i = 0; i < 3 + layers * 3; i++) {
      x = (x * 57 + 23) % 100;
      final y = (x * 31 + i * 17) % 100;
      final p = Offset(size.width * (0.12 + 0.76 * x / 100), size.height * (0.12 + 0.76 * y / 100));
      c.drawCircle(p, size.width * (i.isEven ? 0.05 : 0.035), i.isEven ? light : dark);
    }
  }

  @override
  bool shouldRepaint(_CrumbsPainter old) => old.layers != layers;
}

/// Картинка карточки режима: сундук в пыли и россыпь гемов.
class DigArt extends StatelessWidget {
  const DigArt({super.key});

  @override
  Widget build(BuildContext context) {
    return const Stack(
      alignment: Alignment.center,
      children: [
        Positioned(left: 6, bottom: 6, child: Icon(Icons.diamond_rounded, size: 22, color: Color(0xFF5BC8FF))),
        Positioned(right: 8, top: 8, child: Icon(Icons.diamond_rounded, size: 18, color: Color(0xFFC77DFF))),
        Positioned(right: 10, bottom: 8, child: Icon(Icons.auto_awesome, size: 18, color: GameColors.gold)),
        CaseIcon(size: 54),
      ],
    );
  }
}
