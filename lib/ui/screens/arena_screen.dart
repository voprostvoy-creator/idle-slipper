import 'package:flutter/material.dart';

import '../../game/game_state.dart';
import '../../game/leaderboard.dart';
import '../slipper_sprite.dart';
import '../theme.dart';
import '../widgets/game_widgets.dart';
import 'battle_hub_screen.dart';
import 'battle_screen.dart';
import 'leaderboard_screen.dart';

/// Арена: очки и место в рейтинге, кнопка поиска соперника.
/// Соперник — тапок, стоящий в рейтинге сразу выше игрока.
class ArenaScreen extends StatelessWidget {
  const ArenaScreen({super.key, required this.game, required this.onBack});
  final GameState game;

  /// Возврат к выбору режима во вкладке «В бой».
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListenableBuilder(
      listenable: game,
      builder: (context, _) {
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          children: [
            BackToModes(title: 'Арена', onBack: onBack),
            const SizedBox(height: 12),
            GamePanel(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              onTap: () => _openLeaderboard(context),
              child: Column(
                children: [
                  SlipperSprite(fighter: game.slipper, width: 200),
                  const SizedBox(height: 4),
                  StrokeText(game.slipper.name, size: 22),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _BigStat(
                          icon: Icons.emoji_events_rounded,
                          color: GameColors.blue,
                          value: '${game.rating}',
                          label: 'Очки',
                        ),
                      ),
                      Container(width: 2, height: 56, color: GameColors.outline),
                      Expanded(
                        child: _BigStat(
                          icon: Icons.military_tech_rounded,
                          color: GameColors.gold,
                          value: '#${game.arenaPlace}',
                          label: 'Место из ${Leaderboard.size}',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Открыть рейтинг', style: theme.textTheme.bodySmall),
                      const Icon(Icons.chevron_right, size: 18, color: GameColors.textDim),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: GameButton(
                color: GameColors.red,
                height: 60,
                onPressed: () => _fight(context),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.search_rounded, size: 26),
                    SizedBox(width: 8),
                    Text('Найти соперника', style: TextStyle(fontSize: 20)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Соперник — тапок, который стоит в рейтинге сразу над тобой. '
              'Победишь — заберёшь его очки и получишь нитки, проиграешь — '
              'ничего не потеряешь.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
          ],
        );
      },
    );
  }

  void _openLeaderboard(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => LeaderboardScreen(game: game)),
    );
  }

  void _fight(BuildContext context) {
    // Бой считается мгновенно; экран боя лишь проигрывает запись.
    final me = game.slipper;
    final outcome = game.fightArena();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BattleScreen(
          player: me,
          opponent: outcome.opponent.slipper,
          result: outcome.result,
          ratingDelta: outcome.ratingDelta,
          threadsDelta: outcome.threads,
          intro: BattleIntro(
            playerRating: outcome.ratingBefore,
            opponentRating: outcome.opponent.rating,
          ),
        ),
      ),
    );
  }
}

class _BigStat extends StatelessWidget {
  const _BigStat({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final Color color;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 30),
            const SizedBox(width: 4),
            StrokeText(value, size: 34, color: color),
          ],
        ),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
