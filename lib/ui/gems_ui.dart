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
      return Padding(
        padding: const EdgeInsets.only(top: 24),
        child: Center(
          child: Text('Пока пусто', style: theme.textTheme.titleMedium),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
                        child: Icon(
                          Icons.check_circle,
                          size: 18,
                          color: GameColors.gold,
                        ),
                      ),
                    // Можно улучшить — зелёный кружок в углу.
                    if (game.canMerge(g))
                      Positioned(
                        right: -3,
                        top: -3,
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: GameColors.green,
                            border: Border.all(
                              color: GameColors.outline,
                              width: 2,
                            ),
                          ),
                        ),
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

Future<void> _sheet(
  BuildContext context,
  GameState game,
  WidgetBuilder builder,
) => showModalBottomSheet<void>(
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

/// Окно гема: что даёт, где стоит, улучшение. Открытое из слота тапка
/// ([kindId], [slot]) — ещё и кнопка «Извлечь».
Future<void> showGemSheet(
  BuildContext context,
  GameState game,
  int gemId, {
  String? kindId,
  int? slot,
}) => _sheet(context, game, (context) {
  final theme = Theme.of(context);
  final gem = game.gemById(gemId);
  if (gem == null) return const SizedBox(height: 40);
  final where = game.socketedIn(gem.id);
  final mates = game.mergeMates(gem);
  final maxed = gem.level >= Gem.maxLevel;
  final fromSlot = kindId != null && slot != null;
  final canUp = game.canMerge(gem);
  return Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      GemIcon(gem: gem, size: 88),
      const SizedBox(height: 10),
      StrokeText(gemTitle(gem), size: 20, color: gem.rarity.color),
      Text(
        'Уровень ${gem.level} из ${Gem.maxLevel}',
        style: theme.textTheme.bodySmall,
      ),
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
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: maxed
            ? Text('Максимальный уровень', style: theme.textTheme.titleSmall)
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Для уровня ${gem.level + 1} нужно собрать:',
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      GemIcon(gem: gem, size: 24, showLevel: false),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 96,
                        child: Text(
                          'Таких же',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                      Expanded(
                        child: GameBar(
                          value: (mates / 2).clamp(0.0, 1.0),
                          height: 18,
                          color: mates >= 2
                              ? GameColors.green
                              : GameColors.blue,
                          label: '${mates > 2 ? 2 : mates}/2',
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        mates >= 2
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                        size: 20,
                        color: mates >= 2
                            ? GameColors.green
                            : GameColors.textDim,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Уровень ${gem.level + 1}: ${gem.copyWith(level: gem.level + 1).bonusText}. '
                    'Гемы находятся «Под диваном».',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
      ),
      const SizedBox(height: 14),
      Row(
        children: [
          if (fromSlot) ...[
            Expanded(
              child: GameButton(
                color: GameColors.panelLight,
                height: 50,
                onPressed: () {
                  game.removeGem(kindId, slot);
                  Navigator.pop(context);
                },
                child: const Text(
                  'Извлечь',
                  style: TextStyle(color: GameColors.text),
                ),
              ),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: GameButton(
              color: canUp ? GameColors.gold : GameColors.panelDark,
              height: 50,
              onPressed: canUp ? () => game.mergeGem(gem) : null,
              child: const Text('Улучшить'),
            ),
          ),
        ],
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
              onTap: () => open[i] == null
                  ? _pick(context, i)
                  : showGemSheet(
                      context,
                      game,
                      open[i]!.id,
                      kindId: kindId,
                      slot: i,
                    ),
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
        ..sort(
          (a, b) => b.rarity.index != a.rarity.index
              ? b.rarity.index.compareTo(a.rarity.index)
              : b.level.compareTo(a.level),
        );
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
                      Text(
                        gemTitle(current),
                        style: theme.textTheme.titleSmall,
                      ),
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
                  child: const Text(
                    'Снять',
                    style: TextStyle(color: GameColors.text),
                  ),
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
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: GameColors.text,
                          ),
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
