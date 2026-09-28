import 'package:flutter/material.dart';

import '../game/game_state.dart';
import '../game/gems.dart';
import '../game/slipper_kind.dart';
import 'gem_icon.dart';
import 'theme.dart';
import 'widgets/game_widgets.dart';

/// Вкладка «Гемы» в коллекции: все гемы, сначала самые редкие.
class GemsTab extends StatelessWidget {
  const GemsTab({super.key, required this.game});
  final GameState game;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gems = [...game.gems]
      ..sort((a, b) {
        final r = b.rarity.index.compareTo(a.rarity.index);
        if (r != 0) return r;
        final t = a.type.index.compareTo(b.type.index);
        return t != 0 ? t : b.level.compareTo(a.level);
      });
    if (gems.isEmpty) {
      return GamePanel(
        color: GameColors.panelDark,
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            const Icon(Icons.diamond_outlined, size: 44, color: GameColors.textDim),
            const SizedBox(height: 8),
            Text('Гемов пока нет', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Их можно найти «Под диваном» — режим во вкладке «В бой».',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Три одинаковых гема сливаются в один уровнем выше. '
          'Вставляются в окне тапка.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 12,
          children: [
            for (final g in gems)
              GestureDetector(
                onTap: () => showGemSheet(context, game, g.id),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    GemIcon(gem: g, size: 56),
                    // Вставлен в тапок — отметка в углу.
                    if (game.socketedIn(g.id) != null)
                      const Positioned(
                        left: -4,
                        top: -4,
                        child: Icon(Icons.check_circle, size: 18, color: GameColors.gold),
                      ),
                    // Можно слить — стрелка вверх.
                    if (game.canMerge(g))
                      const Positioned(
                        right: -4,
                        top: -4,
                        child: Icon(Icons.arrow_circle_up_rounded, size: 18, color: GameColors.green),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}

Future<void> _sheet(BuildContext context, GameState game, WidgetBuilder builder) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: GameColors.panel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        side: BorderSide(color: GameColors.outline, width: 3),
      ),
      builder: (context) => ListenableBuilder(
        listenable: game,
        builder: (context, _) => SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: builder(context),
          ),
        ),
      ),
    );

/// Окно гема: что даёт, где стоит, слияние.
Future<void> showGemSheet(BuildContext context, GameState game, int gemId) =>
    _sheet(context, game, (context) {
      final theme = Theme.of(context);
      final gem = game.gemById(gemId);
      if (gem == null) return const SizedBox(height: 40);
      final where = game.socketedIn(gem.id);
      final mates = game.mergeMates(gem);
      final maxed = gem.level >= Gem.maxLevel;
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GemIcon(gem: gem, size: 88),
          const SizedBox(height: 10),
          StrokeText(gemTitle(gem), size: 20, color: gem.rarity.color),
          Text('Уровень ${gem.level} из ${Gem.maxLevel}', style: theme.textTheme.bodySmall),
          const SizedBox(height: 8),
          GameBadge(text: gem.bonusText, color: GameColors.green),
          const SizedBox(height: 8),
          Text(
            where == null
                ? 'Лежит свободно'
                : 'Вставлен в тапок «${SlipperCatalog.byId(where).name}»',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 14),
          GamePanel(
            color: GameColors.panelDark,
            padding: const EdgeInsets.all(12),
            child: maxed
                ? Text('Максимальный уровень', style: theme.textTheme.titleSmall)
                : Column(
                    children: [
                      Text(
                        'Слияние: этот гем + 2 таких же → уровень ${gem.level + 1} '
                        '(${gem.copyWith(level: gem.level + 1).bonusText})',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Таких же свободных: ${mates > 2 ? 2 : mates}/2',
                        style: theme.textTheme.titleSmall,
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: GameButton(
              color: game.canMerge(gem) ? GameColors.gold : GameColors.panelDark,
              height: 50,
              onPressed: game.canMerge(gem) ? () => game.mergeGem(gem) : null,
              child: const Text('Слить'),
            ),
          ),
        ],
      );
    });

/// Слоты гемов тапка — в окне тапка в коллекции.
class GemSlotsRow extends StatelessWidget {
  const GemSlotsRow({super.key, required this.game, required this.kindId});

  final GameState game;
  final String kindId;

  @override
  Widget build(BuildContext context) {
    final open = game.socketsOf(kindId);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < Gems.maxSlots; i++) ...[
          if (i > 0) const SizedBox(width: 12),
          if (i >= open.length)
            GemSlotBox(size: 52, lockedStar: Gems.slotStar(i))
          else
            GestureDetector(
              onTap: () => _pick(context, i),
              child: open[i] == null
                  ? const GemSlotBox(size: 52)
                  : GemIcon(gem: open[i]!, size: 52),
            ),
        ],
      ],
    );
  }

  /// Выбор гема для слота: текущий можно снять, любой свободный — вставить.
  void _pick(BuildContext context, int slot) {
    _sheet(context, game, (context) {
      final theme = Theme.of(context);
      final current = game.socketsOf(kindId)[slot];
      final free = [...game.freeGems]
        ..sort((a, b) => b.rarity.index != a.rarity.index
            ? b.rarity.index.compareTo(a.rarity.index)
            : b.level.compareTo(a.level));
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(child: StrokeText('Слот ${slot + 1}', size: 22)),
          const SizedBox(height: 10),
          if (current != null) ...[
            Row(
              children: [
                GemIcon(gem: current, size: 48),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(gemTitle(current), style: theme.textTheme.titleSmall),
                      Text(current.bonusText, style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
                GameButton(
                  color: GameColors.panelLight,
                  height: 38,
                  onPressed: () {
                    game.removeGem(kindId, slot);
                    Navigator.pop(context);
                  },
                  child: const Text('Снять', style: TextStyle(color: GameColors.text)),
                ),
              ],
            ),
            const SizedBox(height: 14),
          ],
          Text(
            free.isEmpty ? 'Свободных гемов нет' : 'Вставить:',
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 12,
            children: [
              for (final g in free)
                GestureDetector(
                  onTap: () {
                    game.insertGem(kindId, slot, g.id);
                    Navigator.pop(context);
                  },
                  child: Column(
                    children: [
                      GemIcon(gem: g, size: 52),
                      const SizedBox(height: 4),
                      SizedBox(
                        width: 64,
                        child: Text(
                          g.bonusText,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          style: theme.textTheme.labelSmall?.copyWith(color: GameColors.text),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      );
    });
  }
}
