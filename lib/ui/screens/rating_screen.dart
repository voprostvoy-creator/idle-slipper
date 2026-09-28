import 'package:flutter/material.dart';

import '../../game/game_state.dart';
import '../../game/slipper.dart';
import '../../net/server_api.dart';
import '../account_dialog.dart';
import '../slipper_sprite.dart';
import '../theme.dart';
import '../widgets/game_widgets.dart';

/// Профиль: тапок, статистика, аккаунт.
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
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          children: [
            const Center(child: StrokeText('Профиль', size: 30)),
            const SizedBox(height: 12),
            GamePanel(
              child: Column(
                children: [
                  SlipperSprite(fighter: game.slipper, width: 190),
                  const SizedBox(height: 4),
                  StrokeText(game.slipper.name, size: 22),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    alignment: WrapAlignment.center,
                    children: [
                      GameBadge(
                        text:
                            '${game.slipper.kind.rarity.label} · ${game.slipper.kind.name}',
                        color: game.slipper.kind.rarity.color,
                      ),
                      for (final e in game.slipper.kind.bonuses.entries)
                        GameBadge(
                          text: e.key.format(e.value),
                          color: GameColors.green,
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _Metric(
                        label: 'Рейтинг',
                        value: '${game.rating}',
                        color: GameColors.blue,
                      ),
                      _Metric(
                        label: 'Побед',
                        value: '${game.wins}',
                        color: GameColors.green,
                      ),
                      _Metric(
                        label: 'Поражений',
                        value: '${game.losses}',
                        color: GameColors.red,
                      ),
                      _Metric(
                        label: 'Винрейт',
                        value: '$winRate%',
                        color: GameColors.gold,
                      ),
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
                          SizedBox(
                            width: 96,
                            child: Text(
                              s.label,
                              style: theme.textTheme.bodyMedium,
                            ),
                          ),
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
                            child: StrokeText(
                              '${game.slipper.level(s)}',
                              size: 16,
                              strokeWidth: 3,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            GamePanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.account_circle_rounded,
                        color: GameColors.gold,
                      ),
                      const SizedBox(width: 8),
                      Text('Аккаунт', style: theme.textTheme.titleMedium),
                      const Spacer(),
                      Text(
                        game.server.credentials?.login ?? 'нет аккаунта',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (!game.server.hasAccount)
                    Row(
                      children: [
                        Expanded(
                          child: GameButton(
                            color: GameColors.gold,
                            height: 40,
                            onPressed: () => _createAccount(context),
                            child: const FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                'Создать аккаунт',
                                style: TextStyle(fontSize: 14),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: GameButton(
                            color: GameColors.panelLight,
                            height: 40,
                            onPressed: () => showLoginDialog(context, game),
                            child: const Text(
                              'Войти',
                              style: TextStyle(
                                fontSize: 14,
                                color: GameColors.text,
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  else
                    Row(
                      children: [
                        Expanded(
                          child: GameButton(
                            color: GameColors.gold,
                            height: 40,
                            onPressed: () => showAccountDialog(context, game),
                            child: const FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                'Логин и пароль',
                                style: TextStyle(fontSize: 14),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: GameButton(
                            color: GameColors.panelLight,
                            height: 40,
                            onPressed: () => showLoginDialog(context, game),
                            child: const FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                'Другой аккаунт',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: GameColors.text,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // TODO: убрать отладочную панель перед релизом.
            GamePanel(
              color: GameColors.panelDark,
              child: Row(
                children: [
                  const Icon(Icons.bug_report, color: GameColors.textDim),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text('Отладка', style: theme.textTheme.titleMedium),
                  ),
                  GameButton(
                    color: GameColors.gold,
                    height: 38,
                    onPressed: () => game.cheatThreads(100000),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ThreadIcon(size: 16),
                        SizedBox(width: 5),
                        Text('+100K'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: GameButton(
                    color: GameColors.gold,
                    height: 38,
                    onPressed: () => game.cheatCoins(1000),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CoinIcon(size: 16),
                        SizedBox(width: 5),
                        Text('+1K'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GameButton(
                    color: GameColors.blue,
                    height: 38,
                    onPressed: game.cheatNewDay,
                    child: const Text('Новый день'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: GameButton(
                    color: GameColors.green,
                    height: 38,
                    onPressed: game.cheatOneOfEach,
                    child: const Text('+1 тапки'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GameButton(
                    color: const Color(0xFFC77DFF),
                    height: 38,
                    onPressed: game.cheatGems,
                    child: const Text('+гемы'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Center(
              child: TextButton.icon(
                onPressed: () => _confirmReset(context),
                icon: const Icon(Icons.restart_alt, color: GameColors.textDim),
                label: Text(
                  'Сбросить прогресс',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _createAccount(BuildContext context) async {
    try {
      await game.createAccount();
      if (context.mounted) {
        await showAccountDialog(context, game, firstTime: true);
      }
    } on ServerException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    }
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
  const _Metric({
    required this.label,
    required this.value,
    required this.color,
  });
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
