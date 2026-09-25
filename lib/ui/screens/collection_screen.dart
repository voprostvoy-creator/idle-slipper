import 'package:flutter/material.dart';

import '../../game/game_state.dart';
import '../../game/slipper.dart';
import '../../game/slipper_kind.dart';
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
