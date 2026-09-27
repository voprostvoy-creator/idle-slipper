import 'package:flutter/material.dart';

import '../../game/game_state.dart';
import '../../game/slipper.dart';
import '../../game/slipper_kind.dart';
import '../../game/stars.dart';
import '../slipper_sprite.dart';
import '../theme.dart';
import '../widgets/game_widgets.dart';

/// Коллекция: все тапки каталога. Свои можно надеть, чужие показаны
/// тёмным силуэтом — видно, что ещё предстоит выбить из кейсов.
class CollectionScreen extends StatelessWidget {
  const CollectionScreen({super.key, required this.game});
  final GameState game;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListenableBuilder(
      listenable: game,
      builder: (context, _) {
        final kinds = SlipperCatalog.all;
        final owned = kinds.where((k) => game.count(k.id) > 0).length;
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          children: [
            const Center(child: StrokeText('Коллекция', size: 30)),
            const SizedBox(height: 4),
            Center(
              child: Text(
                'Собрано $owned из ${kinds.length}',
                style: theme.textTheme.bodySmall,
              ),
            ),
            const SizedBox(height: 14),
            for (final kind in kinds) ...[
              _KindCard(game: game, kind: kind),
              const SizedBox(height: 10),
            ],
          ],
        );
      },
    );
  }
}

class _KindCard extends StatelessWidget {
  const _KindCard({required this.game, required this.kind});

  final GameState game;
  final SlipperKind kind;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final count = game.count(kind.id);
    final have = count > 0;
    final equipped = kind.id == game.slipper.kindId;

    final sprite = SlipperSprite(
      fighter: Slipper(name: kind.id, kindId: kind.id),
      width: 116,
      animate: false,
      showSize: false,
    );

    return GamePanel(
      padding: const EdgeInsets.all(10),
      color: equipped ? GameColors.panelLight : GameColors.panel,
      onTap: have && !equipped ? () => game.equip(kind.id) : null,
      child: Row(
        children: [
          // Нераскрытый тапок — чёрный силуэт: форму видно, детали нет.
          have
              ? sprite
              : ColorFiltered(
                  colorFilter: const ColorFilter.mode(
                    Color(0xFF120A1C),
                    BlendMode.srcIn,
                  ),
                  child: Opacity(opacity: 0.85, child: sprite),
                ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        have ? kind.name : '???',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: have ? GameColors.text : GameColors.textDim,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (count > 1) ...[
                      const SizedBox(width: 6),
                      GameBadge(text: '×$count', color: GameColors.panelLight),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    GameBadge(
                      text: '${kind.rarity.label} · ${kind.rarity.tier}',
                      color: kind.rarity.color,
                    ),
                    if (have)
                      for (final e in kind.bonuses.entries)
                        GameBadge(text: e.key.format(e.value), color: GameColors.green),
                  ],
                ),
                if (!have) ...[
                  const SizedBox(height: 4),
                  Text('Выпадает из кейсов', style: theme.textTheme.bodySmall),
                ] else ...[
                  const SizedBox(height: 6),
                  _StarsRow(game: game, kind: kind),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (equipped)
            const Icon(Icons.check_circle, color: GameColors.gold, size: 28)
          else if (have)
            const Icon(Icons.chevron_right, color: GameColors.textDim)
          else
            const Icon(Icons.lock_rounded, color: GameColors.textDim, size: 22),
        ],
      ),
    );
  }
}

/// Звёзды вида, копии к следующей и кнопка улучшения.
class _StarsRow extends StatelessWidget {
  const _StarsRow({required this.game, required this.kind});

  final GameState game;
  final SlipperKind kind;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stars = game.starsOf(kind.id);
    final cost = game.nextStarCost(kind.id);
    return Row(
      children: [
        for (var i = 0; i < Stars.max; i++)
          Icon(
            i < stars ? Icons.star_rounded : Icons.star_outline_rounded,
            size: 15,
            color: i < stars ? GameColors.gold : GameColors.textDim,
          ),
        const SizedBox(width: 6),
        if (cost == null)
          Text('Максимум', style: theme.textTheme.labelSmall)
        else if (game.canStarUp(kind.id))
          GameButton(
            color: GameColors.gold,
            height: 28,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            onPressed: () => _confirm(context, cost),
            child: const Text('★ Улучшить', style: TextStyle(fontSize: 12)),
          )
        else
          Flexible(
            child: Text(
              'копии ${game.copiesOf(kind.id)}/${cost.copies}',
              style: theme.textTheme.labelSmall,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
    );
  }

  Future<void> _confirm(BuildContext context, ({int copies, int coins}) cost) async {
    final next = game.starsOf(kind.id) + 1;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: StrokeText('${kind.name}: ★$next', size: 20),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Удар, прочность и здоровье: '
                '+${(Stars.perStar * 100).round()}% за звезду.'),
            const SizedBox(height: 10),
            Row(
              children: [
                Text('Цена: ${cost.copies} ${_copiesWord(cost.copies)} и '),
                const CoinIcon(size: 16),
                Text(' ${cost.coins}'),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          GameButton(
            color: GameColors.gold,
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Улучшить'),
          ),
        ],
      ),
    );
    if (ok == true) game.starUp(kind.id);
  }

  static String _copiesWord(int n) {
    final mod10 = n % 10;
    final mod100 = n % 100;
    if (mod10 == 1 && mod100 != 11) return 'копия';
    if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) return 'копии';
    return 'копий';
  }
}
