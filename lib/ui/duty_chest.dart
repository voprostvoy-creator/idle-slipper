import 'package:flutter/material.dart';

import '../game/game_state.dart';
import 'format.dart';
import 'screens/shop_screen.dart';
import 'theme.dart';
import 'widgets/game_widgets.dart';

/// Сундук дежурства: пока игрока нет, тапок сторожит дом и копит нитки.
/// Полный за 8 часов, дальше не растёт — повод заглядывать пару раз в день.
class DutyChestTile extends StatelessWidget {
  const DutyChestTile({super.key, required this.game});
  final GameState game;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final amount = game.chestThreads;
    final fullIn = game.chestFullIn;
    return GamePanel(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      color: game.chestFull ? GameColors.panelLight : GameColors.panel,
      child: Row(
        children: [
          const CaseIcon(size: 42),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text('Сундук дежурства', style: theme.textTheme.titleMedium),
                ),
                const SizedBox(height: 4),
                GameBar(
                  value: game.chestFill,
                  height: 14,
                  color: GameColors.thread,
                ),
                const SizedBox(height: 3),
                Text(
                  fullIn == null
                      ? 'Полный — забирай!'
                      : 'Полный через ${fmtClock(fullIn)}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          GameButton(
            color: amount > 0 ? GameColors.gold : GameColors.panelDark,
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            onPressed: amount > 0 ? game.collectChest : null,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const ThreadIcon(size: 16),
                const SizedBox(width: 4),
                Text('+${fmtNum(amount)}'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
