import 'package:flutter/material.dart';

import '../../game/game_state.dart';
import '../../game/slipper_kind.dart';
import '../../game/story/chapters.dart';
import '../slipper_sprite.dart';
import '../theme.dart';
import '../widgets/game_widgets.dart';
import 'battle_hub_screen.dart';
import 'battle_screen.dart';

/// Сюжет: главы из десяти боёв подряд, в конце — босс.
/// Бои открываются по одному, главы — по порядку; пройденные бои можно
/// переигрывать за часть награды.
class StoryScreen extends StatefulWidget {
  const StoryScreen({super.key, required this.game, required this.onBack});

  final GameState game;
  final VoidCallback onBack;

  @override
  State<StoryScreen> createState() => _StoryScreenState();
}

class _StoryScreenState extends State<StoryScreen> {
  GameState get game => widget.game;

  /// Выбранная глава; по умолчанию — последняя открытая.
  late Chapter chapter = game.currentChapter;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: game,
      builder: (context, _) {
        final cleared = game.cleared(chapter);
        final done = cleared >= chapter.stages.length;
        final i = StoryCatalog.chapters.indexOf(chapter);
        final next = i + 1 < StoryCatalog.chapters.length ? StoryCatalog.chapters[i + 1] : null;
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          children: [
            BackToModes(title: 'Сюжет', onBack: widget.onBack),
            const SizedBox(height: 10),
            Row(
              children: [
                for (final (k, c) in StoryCatalog.chapters.indexed) ...[
                  if (k > 0) const SizedBox(width: 8),
                  Expanded(child: _chapterTab(c)),
                ],
              ],
            ),
            const SizedBox(height: 12),
            _ChapterHeader(
              chapter: chapter,
              cleared: cleared,
              replaysLeft: game.storyReplaysLeft,
            ),
            const SizedBox(height: 14),
            for (final (i, stage) in chapter.stages.indexed) ...[
              _StageCard(
                number: i + 1,
                stage: stage,
                state: i < cleared
                    ? _StageState.cleared
                    : i == cleared
                        ? _StageState.current
                        : _StageState.locked,
                onFight: () => _fight(context, i),
              ),
              const SizedBox(height: 10),
            ],
            if (done)
              GamePanel(
                color: GameColors.panelDark,
                padding: const EdgeInsets.all(14),
                child: Text(
                  next == null
                      ? 'Глава пройдена! Следующая скоро появится.'
                      : 'Глава пройдена! Открыта глава ${next.number} «${next.title}».',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _chapterTab(Chapter c) {
    final open = game.chapterOpen(c);
    final active = c == chapter;
    return GameButton(
      color: active ? GameColors.gold : (open ? GameColors.panelLight : GameColors.panelDark),
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      onPressed: open
          ? () => setState(() => chapter = c)
          : () => ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(
              content: Text('Глава ${c.number} откроется, когда пройдёшь главу ${c.number - 1}'),
            )),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!open) ...[
              const Icon(Icons.lock_rounded, size: 16, color: GameColors.textDim),
              const SizedBox(width: 4),
            ],
            Text(
              'Глава ${c.number}',
              style: TextStyle(
                fontSize: 15,
                color: active ? GameColors.outline : (open ? GameColors.text : GameColors.textDim),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _fight(BuildContext context, int index) {
    // Как и на арене: бой считается сразу, экран лишь проигрывает запись.
    final me = game.slipper;
    final outcome = game.fightStage(chapter, index);
    if (outcome == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(
          content: Text('Повторы на сегодня кончились — завтра будут новые'),
        ));
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BattleScreen(
          player: me,
          opponent: chapter.stages[index].enemy,
          result: outcome.result,
          threadsDelta: outcome.threads,
          coinsDelta: outcome.coins,
          rewardKind: outcome.kind,
          exitLabel: 'К главе',
        ),
      ),
    );
  }
}

class _ChapterHeader extends StatelessWidget {
  const _ChapterHeader({
    required this.chapter,
    required this.cleared,
    required this.replaysLeft,
  });

  final Chapter chapter;
  final int cleared;
  final int replaysLeft;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = chapter.stages.length;
    return GamePanel(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      child: Column(
        children: [
          Text('Глава ${chapter.number}', style: theme.textTheme.bodySmall),
          StrokeText(chapter.title, size: 26, color: GameColors.gold),
          const SizedBox(height: 4),
          Text(
            chapter.intro,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 10),
          GameBar(
            value: cleared / total,
            color: GameColors.orange,
            label: 'Пройдено $cleared из $total',
          ),
          if (cleared > 0) ...[
            const SizedBox(height: 6),
            Text(
              'Повторов сегодня: $replaysLeft из ${GameState.storyReplaysPerDay}',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

enum _StageState { cleared, current, locked }

class _StageCard extends StatelessWidget {
  const _StageCard({
    required this.number,
    required this.stage,
    required this.state,
    required this.onFight,
  });

  final int number;
  final Stage stage;
  final _StageState state;
  final VoidCallback onFight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enemy = stage.enemy;
    final locked = state == _StageState.locked;
    final current = state == _StageState.current;
    final reward = stage.rewardKindId == null
        ? null
        : SlipperCatalog.byId(stage.rewardKindId!);

    final card = GamePanel(
      padding: const EdgeInsets.all(10),
      color: current ? GameColors.panelLight : GameColors.panel,
      onTap: locked ? null : onFight,
      child: Row(
        children: [
          Container(
            width: 88,
            height: 62,
            decoration: BoxDecoration(
              color: GameColors.panelDark,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: stage.boss ? GameColors.gold : GameColors.outline,
                width: 2.5,
              ),
            ),
            child: SlipperSprite(
              fighter: enemy,
              width: 82,
              flip: true,
              animate: false,
              // В списке все в одном масштабе, иначе муха теряется.
              showSize: false,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('Бой $number', style: theme.textTheme.labelSmall),
                    if (stage.boss) ...[
                      const SizedBox(width: 6),
                      const GameBadge(text: 'Босс', color: GameColors.gold),
                    ] else if (stage.elite) ...[
                      const SizedBox(width: 6),
                      const GameBadge(text: '★ Элита', color: GameColors.red),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  enemy.name,
                  style: theme.textTheme.titleMedium,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                _Reward(stage: stage, cleared: state == _StageState.cleared, kind: reward),
              ],
            ),
          ),
          const SizedBox(width: 6),
          switch (state) {
            _StageState.cleared =>
              const Icon(Icons.check_circle, color: GameColors.green, size: 30),
            _StageState.current => Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: GameColors.red,
                  border: Border.all(color: GameColors.outline, width: 2.5),
                ),
                child: const Icon(Icons.sports_mma, size: 20, color: GameColors.outline),
              ),
            _StageState.locked =>
              const Icon(Icons.lock_rounded, color: GameColors.textDim, size: 24),
          },
        ],
      ),
    );
    // Закрытые бои видны заранее, но приглушены — понятно, что впереди.
    return locked ? Opacity(opacity: 0.5, child: card) : card;
  }
}

/// Награда этапа: нитки и монеты за первую победу, треть ниток — за повтор.
class _Reward extends StatelessWidget {
  const _Reward({required this.stage, required this.cleared, required this.kind});

  final Stage stage;
  final bool cleared;
  final SlipperKind? kind;

  static Widget _item(Widget icon, String text, TextStyle? style) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [icon, const SizedBox(width: 3), Text(text, style: style)],
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.bodySmall?.copyWith(color: GameColors.text);
    return Wrap(
      spacing: 8,
      runSpacing: 2,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _item(
          const ThreadIcon(size: 16),
          cleared ? 'повтор +${stage.replayThreads}' : '+${stage.threads}',
          style,
        ),
        if (!cleared) _item(const CoinIcon(size: 16), '+${stage.coins}', style),
        if (kind != null && !cleared)
          Text(
            '+ тапок «${kind!.name}»',
            style: style?.copyWith(color: kind!.rarity.color),
          ),
      ],
    );
  }
}
