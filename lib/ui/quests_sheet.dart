import 'package:flutter/material.dart';

import '../game/daily.dart';
import '../game/game_state.dart';
import 'format.dart';
import 'theme.dart';
import 'widgets/game_widgets.dart';

/// Плитка «Задания дня» на главной: прогресс и отметка, что есть награда.
class QuestsTile extends StatelessWidget {
  const QuestsTile({super.key, required this.game});
  final GameState game;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final quests = game.quests;
    final claimed = quests.where(game.questClaimedToday).length;
    final ready = game.questsReady;
    return GamePanel(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      color: ready ? GameColors.panelLight : GameColors.panel,
      onTap: () => showQuestsSheet(context, game),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: GameColors.gold,
              border: Border.all(color: GameColors.outline, width: 3),
            ),
            child: const Icon(Icons.assignment_turned_in_rounded,
                color: GameColors.outline, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Задания дня', style: theme.textTheme.titleMedium),
                Text(
                  'Выполнено $claimed из ${quests.length}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          if (ready)
            const GameBadge(text: 'Забрать!', color: GameColors.red)
          else
            const Icon(Icons.chevron_right, color: GameColors.textDim),
        ],
      ),
    );
  }
}

Future<void> showQuestsSheet(BuildContext context, GameState game) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: GameColors.panel,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      side: BorderSide(color: GameColors.outline, width: 3),
    ),
    builder: (_) => ListenableBuilder(
      listenable: game,
      builder: (context, _) => _QuestsSheet(game: game),
    ),
  );
}

class _QuestsSheet extends StatelessWidget {
  const _QuestsSheet({required this.game});
  final GameState game;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final quests = game.quests;
    final allDone = quests.every(game.questClaimedToday);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const StrokeText('Задания дня', size: 26),
            Text(
              'Новые через ${fmtClock(untilMidnight(game.clock()))}',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 14),
            for (final q in quests) ...[
              _QuestRow(
                title: q.title,
                value: game.questValue(q),
                target: q.target,
                coins: q.coins,
                claimed: game.questClaimedToday(q),
                onClaim: game.canClaimQuest(q) ? () => game.claimQuest(q) : null,
              ),
              const SizedBox(height: 10),
            ],
            _QuestRow(
              title: 'Все задания дня',
              value: quests.where(game.questClaimedToday).length,
              target: quests.length,
              coins: DailyQuests.bonusCoins,
              claimed: game.questBonusClaimed,
              onClaim: game.canClaimQuestBonus ? game.claimQuestBonus : null,
              bonus: true,
            ),
            if (allDone && game.questBonusClaimed) ...[
              const SizedBox(height: 10),
              Text(
                'На сегодня всё — возвращайся завтра!',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _QuestRow extends StatelessWidget {
  const _QuestRow({
    required this.title,
    required this.value,
    required this.target,
    required this.coins,
    required this.claimed,
    required this.onClaim,
    this.bonus = false,
  });

  final String title;
  final int value;
  final int target;
  final int coins;
  final bool claimed;
  final VoidCallback? onClaim;
  final bool bonus;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GamePanel(
      color: bonus ? GameColors.panelDark : GameColors.panelLight,
      padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleSmall),
                const SizedBox(height: 6),
                GameBar(
                  value: value / target,
                  height: 16,
                  color: bonus ? GameColors.gold : GameColors.green,
                  label: '$value/$target',
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 84,
            child: claimed
                ? const Icon(Icons.check_circle, color: GameColors.green, size: 30)
                : GameButton(
                    color: onClaim != null ? GameColors.gold : GameColors.panelDark,
                    height: 38,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    onPressed: onClaim,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CoinIcon(size: 16),
                        const SizedBox(width: 4),
                        Text('+$coins'),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
