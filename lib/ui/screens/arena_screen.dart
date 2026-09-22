import 'package:flutter/material.dart';

import '../../game/game_state.dart';
import '../../game/opponents.dart';
import '../../game/slipper.dart';
import '../slipper_sprite.dart';
import '../theme.dart';
import '../widgets/game_widgets.dart';
import 'battle_screen.dart';

/// Арена: три соперника на выбор.
class ArenaScreen extends StatelessWidget {
  const ArenaScreen({super.key, required this.game});
  final GameState game;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListenableBuilder(
      listenable: game,
      builder: (context, _) {
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          children: [
            const Center(child: StrokeText('Арена', size: 30)),
            const SizedBox(height: 4),
            Text(
              'Выбери соперника. Бой идёт сам — исход решают характеристики тапков.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            for (final (i, o) in game.opponents.indexed) ...[
              _OpponentCard(
                opponent: o,
                difficulty: i,
                onFight: () => _fight(context, o),
              ),
              const SizedBox(height: 14),
            ],
          ],
        );
      },
    );
  }

  void _fight(BuildContext context, Opponent opponent) {
    // Бой считается мгновенно; экран боя лишь проигрывает запись.
    final me = game.slipper;
    final ratingBefore = game.rating;
    final threadsBefore = game.threads;
    final result = game.fight(opponent);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BattleScreen(
          player: me,
          opponent: opponent.slipper,
          result: result,
          ratingDelta: game.rating - ratingBefore,
          threadsDelta: (game.threads - threadsBefore).round(),
        ),
      ),
    );
  }
}

class _OpponentCard extends StatelessWidget {
  const _OpponentCard({
    required this.opponent,
    required this.difficulty,
    required this.onFight,
  });

  final Opponent opponent;
  final int difficulty;
  final VoidCallback onFight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = opponent.slipper;
    final (label, color) = switch (difficulty) {
      0 => ('Разминка', GameColors.green),
      1 => ('Ровня', GameColors.orange),
      _ => ('Опасно', GameColors.red),
    };
    return GamePanel(
      padding: const EdgeInsets.all(12),
      onTap: onFight,
      child: Row(
        children: [
          // Бейдж сложности живёт под превью — имени остаётся вся ширина строки.
          Column(
            children: [
              Container(
                width: 88,
                height: 62,
                decoration: BoxDecoration(
                  color: GameColors.panelDark,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: GameColors.outline, width: 2.5),
                ),
                child: SlipperSprite(slipper: s, width: 82, flip: true, animate: false),
              ),
              const SizedBox(height: 5),
              GameBadge(text: label, color: color),
            ],
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.name,
                  style: theme.textTheme.titleMedium,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    const Icon(Icons.bolt, color: GameColors.orange, size: 16),
                    Text('${s.power}', style: theme.textTheme.bodyMedium),
                    const SizedBox(width: 10),
                    const Icon(Icons.emoji_events, color: GameColors.blue, size: 15),
                    const SizedBox(width: 2),
                    Text('${opponent.rating}', style: theme.textTheme.bodyMedium),
                  ],
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 10,
                  runSpacing: 2,
                  children: [
                    for (final st in Stat.values)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('${st.short} ', style: theme.textTheme.labelSmall),
                          Text('${s.level(st)}',
                              style: theme.textTheme.bodySmall?.copyWith(color: GameColors.text)),
                        ],
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          // Вся карточка — кнопка боя, отдельная кнопка съедала ширину.
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: GameColors.red,
              border: Border.all(color: GameColors.outline, width: 2.5),
            ),
            child: const Icon(Icons.sports_mma, size: 20, color: GameColors.outline),
          ),
        ],
      ),
    );
  }
}
