import 'package:flutter/material.dart';

import '../../game/game_state.dart';
import '../format.dart';
import '../settings_dialog.dart';
import '../theme.dart';
import 'game_widgets.dart';

/// Панель с валютами и силой тапка. Общая для всех вкладок.
class ResourceHeader extends StatelessWidget {
  const ResourceHeader({super.key, required this.game});
  final GameState game;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: game,
      builder: (context, _) => GamePanel(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            const ThreadIcon(size: 30),
            const SizedBox(width: 6),
            StrokeText(
              fmtNum(game.threads.floor()),
              size: 20,
              color: GameColors.thread,
            ),
            const SizedBox(width: 12),
            const CoinIcon(size: 30),
            const SizedBox(width: 6),
            StrokeText(fmtNum(game.coins), size: 20, color: GameColors.gold),
            const Spacer(),
            const PowerIcon(size: 22),
            const SizedBox(width: 4),
            StrokeText('${game.slipper.power}', size: 20),
            const SizedBox(width: 10),
            // Настройки звука.
            GestureDetector(
              onTap: () => showSettingsDialog(context),
              child: const Icon(
                Icons.settings_rounded,
                size: 26,
                color: GameColors.textDim,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
