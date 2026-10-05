import 'package:flutter/material.dart';

import '../game/game_state.dart';
import '../game/weekly.dart';
import '../net/server_api.dart';
import 'format.dart';
import 'pick_card.dart';
import 'screens/leaderboard_screen.dart';
import 'theme.dart';
import 'toast.dart';
import 'widgets/game_widgets.dart';

/// Блок «Призы недели» на арене: таймер до итогов, приз за текущее место,
/// кнопка забрать приз за прошлую неделю.
class WeeklyPrizesPanel extends StatefulWidget {
  const WeeklyPrizesPanel({super.key, required this.game});
  final GameState game;

  @override
  State<WeeklyPrizesPanel> createState() => _WeeklyPrizesPanelState();
}

class _WeeklyPrizesPanelState extends State<WeeklyPrizesPanel> {
  bool _claiming = false;

  GameState get game => widget.game;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = game.clock();
    final ends = game.arenaWeekly?.endsAt ?? ArenaWeek.endOf(now);
    final left = ends.difference(now);
    final pending = game.arenaWeekly?.pending;
    final board = game.arenaBoard;
    final place = board != null && board.me.ranked ? board.me.place : null;
    final prize = place == null ? null : WeeklyPrize.forPlace(place);
    return GamePanel(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      // Нажатие — рейтинг с призами каждого места.
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => LeaderboardScreen(game: game, prizes: true),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.emoji_events_rounded,
                color: GameColors.gold,
                size: 26,
              ),
              const SizedBox(width: 8),
              Text('Призы недели', style: theme.textTheme.titleMedium),
              const Spacer(),
              Text(
                'Итоги через ${_fmtLeft(left)}',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (pending != null) ...[
            GameButton(
              color: GameColors.gold,
              height: 50,
              onPressed: _claiming ? null : () => _claim(context),
              child: Text('Забрать приз за ${pending.place} место'),
            ),
            const SizedBox(height: 8),
          ],
          if (prize != null)
            Row(
              children: [
                Text('Сейчас #$place: ', style: theme.textTheme.bodyMedium),
                Expanded(child: PrizeLine(prize: prize)),
              ],
            )
          else
            Text(
              'Займи место в топ-${WeeklyPrize.places} до конца недели — получишь нитки и монеты, '
              'а топ-20 ещё и карту выбора тапка.',
              style: theme.textTheme.bodySmall,
            ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => _showTable(context),
              child: const Text('Все призы'),
            ),
          ),
        ],
      ),
    );
  }

  static String _fmtLeft(Duration d) {
    if (d.isNegative) return '0 мин';
    if (d.inDays > 0) return '${d.inDays} д ${d.inHours.remainder(24)} ч';
    if (d.inHours > 0) return '${d.inHours} ч ${d.inMinutes.remainder(60)} мин';
    return '${d.inMinutes} мин';
  }

  Future<void> _claim(BuildContext context) async {
    setState(() => _claiming = true);
    final WeeklyReward r;
    try {
      r = await game.claimWeekly();
    } on ServerException catch (e) {
      if (context.mounted) showToast(context, e.message, kind: ToastKind.warn);
      return;
    } finally {
      if (mounted) setState(() => _claiming = false);
    }
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Column(
          children: [
            const Icon(
              Icons.emoji_events_rounded,
              color: GameColors.gold,
              size: 48,
            ),
            StrokeText('${r.place} место!', size: 26, color: GameColors.gold),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Награда за прошлую неделю на арене:',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            PrizeLine(prize: r.prize, big: true, center: true),
            if (r.prize.card != null) ...[
              const SizedBox(height: 12),
              PickCardIcon(card: r.prize.card!, size: 64),
              const SizedBox(height: 6),
              Text(
                '${r.prize.card!.title} — в инвентаре коллекции',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
        actions: [
          GameButton(
            color: GameColors.gold,
            onPressed: () => Navigator.pop(context),
            child: const Text('Отлично!'),
          ),
        ],
      ),
    );
  }

  void _showTable(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: GameColors.panel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        side: BorderSide(color: GameColors.outline, width: 3),
      ),
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Center(child: StrokeText('Призы недели', size: 22)),
              const SizedBox(height: 4),
              Text(
                'Итоги — каждый понедельник в 00:00 по Москве',
                textAlign: TextAlign.center,
                style: Theme.of(sheet).textTheme.bodySmall,
              ),
              const SizedBox(height: 10),
              for (final (from, to, prize) in WeeklyPrize.table) ...[
                GamePanel(
                  color: GameColors.panelDark,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 64,
                        child: Text(
                          from == to ? '#$from' : '#$from–$to',
                          style: Theme.of(sheet).textTheme.titleSmall,
                        ),
                      ),
                      Expanded(child: PrizeLine(prize: prize)),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Строка приза: нитки, монеты и карта, если есть.
class PrizeLine extends StatelessWidget {
  const PrizeLine({
    super.key,
    required this.prize,
    this.big = false,
    this.center = false,
  });
  final WeeklyPrize prize;
  final bool big;
  final bool center;

  @override
  Widget build(BuildContext context) {
    final style = big
        ? Theme.of(context).textTheme.titleMedium
        : Theme.of(context).textTheme.bodyMedium;
    final icon = big ? 22.0 : 16.0;
    return Wrap(
      alignment: center ? WrapAlignment.center : WrapAlignment.start,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 10,
      runSpacing: 4,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ThreadIcon(size: icon),
            const SizedBox(width: 3),
            Text(fmtNum(prize.threads), style: style),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CoinIcon(size: icon),
            const SizedBox(width: 3),
            Text(fmtNum(prize.coins), style: style),
          ],
        ),
        if (prize.card != null)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              PickCardIcon(card: prize.card!, size: icon * 1.3),
              const SizedBox(width: 4),
              Text(
                prize.card == PickCard.superCard
                    ? 'Супер карта'
                    : 'Карта выбора',
                style: style?.copyWith(
                  color: prize.card == PickCard.superCard
                      ? const Color(0xFFFF8BC4)
                      : GameColors.gold,
                ),
              ),
            ],
          ),
      ],
    );
  }
}
