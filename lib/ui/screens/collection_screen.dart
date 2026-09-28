import 'package:flutter/material.dart';

import '../../game/battle/skill_catalog.dart';
import '../../game/battle/skills.dart';
import '../../game/game_state.dart';
import '../../game/slipper.dart';
import '../../game/slipper_kind.dart';
import '../../game/stars.dart';
import '../format.dart';
import '../gems_ui.dart';
import '../slipper_sprite.dart';
import '../theme.dart';
import '../widgets/game_widgets.dart';

/// Коллекция: тапки по редкостям, от обычных к мифическим. Свои можно
/// открыть — там надеть и улучшить; чужие показаны тёмным силуэтом.
class CollectionScreen extends StatefulWidget {
  const CollectionScreen({super.key, required this.game});
  final GameState game;

  @override
  State<CollectionScreen> createState() => _CollectionScreenState();
}

class _CollectionScreenState extends State<CollectionScreen> {
  /// Открыта вкладка гемов, а не тапков.
  bool _gems = false;

  GameState get game => widget.game;

  Widget _tab(String label, bool gems) {
    final active = _gems == gems;
    return Expanded(
      child: GameButton(
        color: active ? GameColors.gold : GameColors.panelLight,
        height: 40,
        onPressed: () => setState(() => _gems = gems),
        child: Text(
          label,
          style: TextStyle(
            color: active ? GameColors.outline : GameColors.text,
          ),
        ),
      ),
    );
  }

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
                _gems
                    ? 'Гемов: ${game.gems.length}'
                    : 'Собрано $owned из ${kinds.length}',
                style: theme.textTheme.bodySmall,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _tab('Тапки', false),
                const SizedBox(width: 10),
                _tab('Гемы', true),
              ],
            ),
            if (_gems) ...[const SizedBox(height: 14), GemsTab(game: game)],
            if (!_gems)
              for (final rarity in Rarity.values)
                if (SlipperCatalog.byRarity(rarity).isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _RarityHeader(game: game, rarity: rarity),
                  const SizedBox(height: 8),
                  GridView(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          mainAxisExtent: 156,
                        ),
                    children: [
                      for (final kind in SlipperCatalog.byRarity(rarity))
                        _KindCard(game: game, kind: kind),
                    ],
                  ),
                ],
          ],
        );
      },
    );
  }
}

class _RarityHeader extends StatelessWidget {
  const _RarityHeader({required this.game, required this.rarity});

  final GameState game;
  final Rarity rarity;

  @override
  Widget build(BuildContext context) {
    final kinds = SlipperCatalog.byRarity(rarity);
    final owned = kinds.where((k) => game.count(k.id) > 0).length;
    return Row(
      children: [
        StrokeText(rarity.label, size: 22, color: rarity.color),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            height: 3,
            color: rarity.color.withValues(alpha: 0.5),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '$owned/${kinds.length}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
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
    final stars = game.starsOf(kind.id);

    final sprite = SlipperSprite(
      fighter: Slipper(name: kind.id, kindId: kind.id),
      width: 136,
      animate: false,
      showSize: false,
    );

    return GamePanel(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      color: equipped ? GameColors.panelLight : GameColors.panel,
      onTap: have ? () => showKindSheet(context, game, kind) : null,
      child: Stack(
        children: [
          Positioned.fill(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
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
                const SizedBox(height: 6),
                Text(
                  have ? kind.name : '???',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: have ? GameColors.text : GameColors.textDim,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (have) ...[
                  const SizedBox(height: 4),
                  _StarsLine(stars: stars, size: 16),
                ],
              ],
            ),
          ),
          if (equipped)
            const Positioned(
              right: 0,
              top: 0,
              child: Icon(Icons.check_circle, color: GameColors.gold, size: 24),
            )
          else if (!have)
            const Positioned(
              right: 0,
              top: 0,
              child: Icon(
                Icons.lock_rounded,
                color: GameColors.textDim,
                size: 20,
              ),
            ),
          if (count > 1)
            Positioned(
              left: 0,
              top: 0,
              child: GameBadge(text: '×$count', color: GameColors.blue),
            ),
          // Можно улучшить — золотая звезда в углу, чтобы было видно из списка.
          if (game.canStarUp(kind.id))
            const Positioned(
              right: 0,
              bottom: 0,
              child: Icon(
                Icons.arrow_circle_up_rounded,
                color: GameColors.gold,
                size: 24,
              ),
            ),
        ],
      ),
    );
  }
}

class _StarsLine extends StatelessWidget {
  const _StarsLine({required this.stars, required this.size});
  final int stars;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < Stars.max; i++)
          Icon(
            i < stars ? Icons.star_rounded : Icons.star_outline_rounded,
            size: size,
            color: i < stars ? GameColors.gold : GameColors.textDim,
          ),
      ],
    );
  }
}

/// Окно тапка: что даёт, что нужно для следующей звезды, надеть и улучшить.
Future<void> showKindSheet(
  BuildContext context,
  GameState game,
  SlipperKind kind,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: GameColors.panel,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      side: BorderSide(color: GameColors.outline, width: 3),
    ),
    builder: (_) => ListenableBuilder(
      listenable: game,
      builder: (context, _) => _KindSheet(game: game, kind: kind),
    ),
  );
}

class _KindSheet extends StatelessWidget {
  const _KindSheet({required this.game, required this.kind});

  final GameState game;
  final SlipperKind kind;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stars = game.starsOf(kind.id);
    final cost = game.nextStarCost(kind.id);
    final equipped = kind.id == game.slipper.kindId;
    final copies = game.copiesOf(kind.id);
    final bonusNow = (Stars.perStar * stars * 100).round();

    final skills = SkillCatalog.forKind(kind.id);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SlipperSprite(
              fighter: Slipper(name: kind.name, kindId: kind.id, stars: stars),
              width: 200,
              showSize: false,
            ),
            const SizedBox(height: 6),
            StrokeText(kind.name, size: 24, color: kind.rarity.color),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              alignment: WrapAlignment.center,
              children: [
                GameBadge(text: kind.rarity.label, color: kind.rarity.color),
                for (final e in kind.bonuses.entries)
                  GameBadge(
                    text: e.key.format(e.value),
                    color: GameColors.green,
                  ),
              ],
            ),
            const SizedBox(height: 10),
            _StarsLine(stars: stars, size: 30),
            if (stars > 0)
              Text(
                'Сейчас: удар, прочность и здоровье +$bonusNow%',
                style: theme.textTheme.bodySmall,
              ),
            const SizedBox(height: 12),
            Text('Гемы', style: theme.textTheme.titleSmall),
            const SizedBox(height: 6),
            GemSlotsRow(game: game, kindId: kind.id),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _SkillTile(
                    index: 1,
                    unlockStar: SkillSet.activeStar,
                    stars: stars,
                    name: skills.active.name,
                    description: skills.active.description,
                    note: 'Перезарядка: ${fmtTurns(skills.activeCooldown)}',
                    color: GameColors.blue,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _SkillTile(
                    index: 2,
                    unlockStar: SkillSet.passiveStar,
                    stars: stars,
                    name: skills.passive.name,
                    description: skills.passive.description,
                    color: GameColors.green,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _SkillTile(
                    index: 3,
                    unlockStar: SkillSet.ultimateStar,
                    stars: stars,
                    name: skills.ultimate.name,
                    description: skills.ultimate.description,
                    note: 'Заряжается от урона: нанесённого и полученного',
                    color: GameColors.gold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            GamePanel(
              color: GameColors.panelDark,
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: cost == null
                  ? Text('Максимум звёзд', style: theme.textTheme.titleMedium)
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Для ★${stars + 1} нужно собрать:',
                          style: theme.textTheme.titleSmall,
                        ),
                        const SizedBox(height: 8),
                        _Need(
                          icon: const Icon(
                            Icons.layers_rounded,
                            color: GameColors.blue,
                            size: 22,
                          ),
                          label: 'Копии тапка',
                          have: copies,
                          need: cost.copies,
                          color: GameColors.blue,
                        ),
                        const SizedBox(height: 8),
                        _Need(
                          icon: const CoinIcon(size: 22),
                          label: 'Монеты',
                          have: game.coins,
                          need: cost.coins,
                          color: GameColors.gold,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '★${stars + 1}: удар, прочность и здоровье '
                          '+${(Stars.perStar * 100).round()}%'
                          '${_unlocks(skills, stars + 1)}. '
                          'Копии выпадают из кейсов.',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: GameButton(
                    color: equipped ? GameColors.panelDark : GameColors.blue,
                    height: 50,
                    onPressed: equipped ? null : () => game.equip(kind.id),
                    child: Text(equipped ? 'Надет' : 'Использовать'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GameButton(
                    color: game.canStarUp(kind.id)
                        ? GameColors.gold
                        : GameColors.panelDark,
                    height: 50,
                    onPressed: game.canStarUp(kind.id)
                        ? () => game.starUp(kind.id)
                        : null,
                    child: const Text('Улучшить'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Скилл в окне тапка: номер в цвете вида скилла и название;
/// по нажатию — описание, как в бою.
class _SkillTile extends StatelessWidget {
  const _SkillTile({
    required this.index,
    required this.name,
    required this.description,
    required this.color,
    required this.unlockStar,
    required this.stars,
    this.note,
  });

  /// 1 — активный, 2 — пассивный, 3 — ульта.
  final int index;

  /// На какой звезде открывается и сколько звёзд у тапка сейчас.
  final int unlockStar;
  final int stars;

  bool get _locked => stars < unlockStar;
  final String name;
  final String description;
  final Color color;
  final String? note;

  String get _kind => switch (index) {
    1 => 'Скилл',
    2 => 'Пассивный',
    _ => 'Ульта',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GamePanel(
      color: GameColors.panelLight,
      padding: const EdgeInsets.fromLTRB(6, 8, 6, 8),
      onTap: () => _show(context),
      child: Column(
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _locked ? GameColors.panelDark : color,
              borderRadius: BorderRadius.circular(7),
              border: Border.all(color: GameColors.outline, width: 2.5),
            ),
            child: _locked
                ? const Icon(
                    Icons.lock_rounded,
                    size: 16,
                    color: GameColors.textDim,
                  )
                : Text(
                    '$index',
                    style: const TextStyle(
                      color: GameColors.outline,
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                    ),
                  ),
          ),
          const SizedBox(height: 5),
          Text(
            name,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: _locked ? GameColors.textDim : GameColors.text,
            ),
          ),
          if (_locked)
            Text(
              '★$unlockStar',
              style: theme.textTheme.labelSmall?.copyWith(
                color: GameColors.gold,
              ),
            ),
        ],
      ),
    );
  }

  void _show(BuildContext context) {
    final theme = Theme.of(context);
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GameBadge(text: _kind, color: color),
            const SizedBox(height: 8),
            StrokeText(name, size: 20),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_locked) ...[
              Text(
                'Откроется на ★$unlockStar',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: GameColors.gold,
                ),
              ),
              const SizedBox(height: 6),
            ],
            Text(description),
            if (note != null) ...[
              const SizedBox(height: 8),
              Text(note!, style: theme.textTheme.bodySmall),
            ],
          ],
        ),
        actions: [
          GameButton(
            color: GameColors.gold,
            onPressed: () => Navigator.pop(context),
            child: const Text('Понятно'),
          ),
        ],
      ),
    );
  }
}

/// Какой скилл откроет звезда [star] — хвост фразы или пустая строка.
String _unlocks(SkillSet skills, int star) => switch (star) {
  SkillSet.activeStar => ' и откроет скилл «${skills.active.name}»',
  SkillSet.passiveStar => ' и откроет пассивку «${skills.passive.name}»',
  SkillSet.ultimateStar => ' и откроет ульту «${skills.ultimate.name}»',
  _ => '',
};

/// Строка требования: иконка, название, полоса «есть/нужно».
class _Need extends StatelessWidget {
  const _Need({
    required this.icon,
    required this.label,
    required this.have,
    required this.need,
    required this.color,
  });

  final Widget icon;
  final String label;
  final int have;
  final int need;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final done = have >= need;
    return Row(
      children: [
        icon,
        const SizedBox(width: 8),
        SizedBox(
          width: 96,
          child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ),
        Expanded(
          child: GameBar(
            value: need == 0 ? 1 : have / need,
            height: 18,
            color: done ? GameColors.green : color,
            label: '${have > need ? need : have}/$need',
          ),
        ),
        const SizedBox(width: 6),
        Icon(
          done ? Icons.check_circle : Icons.radio_button_unchecked,
          size: 20,
          color: done ? GameColors.green : GameColors.textDim,
        ),
      ],
    );
  }
}
