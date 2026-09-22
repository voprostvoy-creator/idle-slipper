import 'package:flutter/material.dart';

import '../../game/game_state.dart';
import '../format.dart';
import '../theme.dart';
import 'game_widgets.dart';

/// Панель с валютами и силой тапка. Общая для всех вкладок.
class ResourceHeader extends StatelessWidget {
  const ResourceHeader({super.key, required this.game});
  final GameState game;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListenableBuilder(
      listenable: game,
      builder: (context, _) => GamePanel(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            const ThreadIcon(size: 30),
            const SizedBox(width: 6),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                StrokeText(fmtNum(game.threads.floor()), size: 20, color: GameColors.thread),
                Text('+${fmtNum(game.incomePerSecond)} / с', style: theme.textTheme.bodySmall),
              ],
            ),
            const SizedBox(width: 12),
            const CoinIcon(size: 30),
            const SizedBox(width: 6),
            StrokeText(fmtNum(game.coins), size: 20, color: GameColors.gold),
            const Spacer(),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  children: [
                    const Icon(Icons.bolt, color: GameColors.orange, size: 18),
                    Text('${game.slipper.power}', style: theme.textTheme.titleMedium),
                  ],
                ),
                Row(
                  children: [
                    const Icon(Icons.emoji_events, color: GameColors.blue, size: 16),
                    const SizedBox(width: 2),
                    Text('${game.rating}', style: theme.textTheme.bodySmall),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
