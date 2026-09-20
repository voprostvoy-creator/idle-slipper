import 'package:flutter/material.dart';

import '../../game/game_state.dart';
import '../../game/slipper.dart';
import '../slipper_painter.dart';
import '../theme.dart';
import '../widgets/game_widgets.dart';

/// Профиль и статистика. Таблица лидеров появится вместе с сервером.
class RatingScreen extends StatelessWidget {
  const RatingScreen({super.key, required this.game});
  final GameState game;

  static const _statColors = {
    Stat.attack: GameColors.orange,
    Stat.defense: GameColors.blue,
    Stat.health: GameColors.red,
    Stat.speed: GameColors.green,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListenableBuilder(
      listenable: game,
      builder: (context, _) {
        final total = game.wins + game.losses;
        final winRate = total == 0 ? 0 : (game.wins * 100 / total).round();
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Center(child: StrokeText('Профиль', size: 30)),
            const SizedBox(height: 12),
            GamePanel(
              child: Column(
                children: [
                  SlipperView(slipper: game.slipper, width: 190),
                  const SizedBox(height: 4),
                  StrokeText(game.slipper.name, size: 22),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _Metric(label: 'Рейтинг', value: '${game.rating}', color: GameColors.blue),
                      _Metric(label: 'Побед', value: '${game.wins}', color: GameColors.green),
                      _Metric(label: 'Поражений', value: '${game.losses}', color: GameColors.red),
                      _Metric(label: 'Винрейт', value: '$winRate%', color: GameColors.gold),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            GamePanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Характеристики', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 10),
                  for (final s in Stat.values)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Row(
                        children: [
                          SizedBox(width: 96, child: Text(s.label, style: theme.textTheme.bodyMedium)),
                          Expanded(
                            child: GameBar(
                              value: game.slipper.level(s) / 60,
                              color: _statColors[s]!,
                              height: 16,
                            ),
                          ),
                          const SizedBox(width: 10),
                          SizedBox(
                            width: 30,
                            child: StrokeText('${game.slipper.level(s)}', size: 16, strokeWidth: 3),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            GamePanel(
              color: GameColors.panelDark,
              child: Row(
                children: [
                  const Icon(Icons.leaderboard, color: GameColors.textDim),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Таблица лидеров', style: theme.textTheme.titleMedium?.copyWith(color: GameColors.textDim)),
                        Text('Появится после подключения сервера', style: theme.textTheme.bodySmall),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Center(
              child: TextButton.icon(
                onPressed: () => _confirmReset(context),
                icon: const Icon(Icons.restart_alt, color: GameColors.textDim),
                label: Text('Сбросить прогресс', style: theme.textTheme.bodySmall),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _confirmReset(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const StrokeText('Сбросить прогресс?', size: 20),
        content: const Text('Все монеты, уровни и рейтинг будут потеряны.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          GameButton(
            color: GameColors.red,
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Сбросить'),
          ),
        ],
      ),
    );
    if (ok == true) game.reset();
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        StrokeText(value, size: 22, color: color),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}
