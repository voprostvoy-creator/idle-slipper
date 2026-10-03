import 'package:flutter/material.dart';

import '../../game/game_state.dart';
import '../../game/slipper.dart';
import '../../game/stars.dart';
import '../format.dart';
import '../duty_chest.dart';
import '../quests_sheet.dart';
import '../slipper_sprite.dart';
import '../theme.dart';
import '../widgets/game_widgets.dart';

/// Главный экран: тапок на коврике, монеты, прокачка.
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.game,
    required this.onOpenCollection,
  });
  final GameState game;

  /// Переход во вкладку «Коллекция» — там меняется тапок.
  final VoidCallback onOpenCollection;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _tapAnim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 160),
  );

  @override
  void dispose() {
    _tapAnim.dispose();
    super.dispose();
  }

  /// Тапок пружинит от тапа — просто приятно, наград за это нет.
  void _onTap(TapDownDetails d) => _tapAnim.forward(from: 0);

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    return ListenableBuilder(
      listenable: game,
      builder: (context, _) {
        return CustomScrollView(
          slivers: [
            const SliverToBoxAdapter(child: SizedBox(height: 8)),
            SliverToBoxAdapter(
              child: LayoutBuilder(
                builder: (context, c) {
                  final spriteW = c.maxWidth * 0.82;
                  return GestureDetector(
                    onTapDown: _onTap,
                    behavior: HitTestBehavior.opaque,
                    child: SizedBox(
                      width: c.maxWidth,
                      // Тапок рисуется уменьшенным (размер от Здоровья) и прижат
                      // к низу — высота по реальному размеру, без пустоты сверху.
                      height:
                          spriteW /
                              SlipperSprite.aspect *
                              game.slipper.sizeFactor +
                          20,
                      child: Stack(
                        alignment: Alignment.bottomCenter,
                        clipBehavior: Clip.none,
                        children: [
                          Positioned(
                            bottom: 8,
                            child: AnimatedBuilder(
                              animation: _tapAnim,
                              builder: (_, child) {
                                final t = Curves.easeOut.transform(
                                  _tapAnim.value,
                                );
                                final squash = 1 - 0.12 * (1 - t);
                                final active = _tapAnim.isAnimating;
                                return Transform.scale(
                                  scaleY: active ? squash : 1,
                                  scaleX: active ? 2 - squash : 1,
                                  alignment: Alignment.bottomCenter,
                                  child: child,
                                );
                              },
                              child: SlipperSprite(
                                fighter: game.slipper,
                                width: spriteW,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            SliverToBoxAdapter(
              child: _NameRow(
                game: game,
                onOpenCollection: widget.onOpenCollection,
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: QuestsTile(game: game),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: DutyChestTile(game: game),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
                child: Row(children: [const StrokeText('Прокачка', size: 24)]),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              sliver: SliverList.separated(
                itemCount: Stat.values.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (_, i) =>
                    _UpgradeTile(game: game, stat: Stat.values[i]),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _NameRow extends StatelessWidget {
  const _NameRow({required this.game, required this.onOpenCollection});
  final GameState game;
  final VoidCallback onOpenCollection;

  Future<void> _edit(BuildContext context) async {
    final controller = TextEditingController(text: game.slipper.name);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const StrokeText('Имя тапка', size: 22),
        content: TextField(
          controller: controller,
          maxLength: 18,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Имя'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          GameButton(
            color: GameColors.green,
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
    if (ok == true) game.rename(controller.text);
  }

  @override
  Widget build(BuildContext context) {
    final kind = game.slipper.kind;
    final stars = game.slipper.stars;
    return Column(
      children: [
        // Звёзды тапка — сразу под ним.
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < Stars.max; i++)
              Icon(
                i < stars ? Icons.star_rounded : Icons.star_outline_rounded,
                size: 26,
                color: i < stars ? GameColors.gold : GameColors.textDim,
              ),
          ],
        ),
        const SizedBox(height: 2),
        GestureDetector(
          onTap: () => _edit(context),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              StrokeText(game.slipper.name, size: 24),
              const SizedBox(width: 6),
              const Icon(Icons.edit, size: 18, color: GameColors.textDim),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            GameBadge(
              text: '${kind.rarity.label} · ${kind.name}',
              color: kind.rarity.color,
            ),
            for (final e in kind.bonuses.entries)
              GameBadge(text: e.key.format(e.value), color: GameColors.green),
          ],
        ),
        const SizedBox(height: 10),
        GameButton(
          color: GameColors.blue,
          height: 38,
          onPressed: onOpenCollection,
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.checkroom, size: 18),
              SizedBox(width: 6),
              Text('Сменить тапок'),
            ],
          ),
        ),
      ],
    );
  }
}

class _UpgradeTile extends StatelessWidget {
  const _UpgradeTile({required this.game, required this.stat});
  final GameState game;
  final Stat stat;

  (IconData, Color) get _look => switch (stat) {
    Stat.attack => (Icons.flash_on, GameColors.orange),
    Stat.defense => (Icons.shield, GameColors.blue),
    Stat.health => (Icons.favorite, GameColors.red),
    Stat.speed => (Icons.speed, GameColors.green),
  };

  String _value() {
    final s = game.slipper;
    return switch (stat) {
      Stat.attack =>
        '${s.attack.toStringAsFixed(0)} урона · крит ${(s.critChance * 100).round()}%',
      Stat.defense =>
        '−${(100 - 10000 / (100 + s.defense)).round()}% входящего урона',
      Stat.health => '${s.maxHp.round()} HP',
      Stat.speed =>
        '${s.speed.round()} скорости · уворот ${(s.dodgeChance * 100).round()}%',
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cost = game.upgradeCost(stat);
    final affordable = game.canUpgrade(stat);
    final (icon, color) = _look;
    return GamePanel(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color.lerp(color, Colors.white, 0.3)!, color],
              ),
              border: Border.all(color: GameColors.outline, width: 3),
            ),
            child: Icon(icon, color: GameColors.outline, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // На больших уровнях «Здоровье ур. 55» не влезает рядом с ценой —
                // строка ужимается, а не наезжает на кнопку.
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Row(
                    children: [
                      Text(stat.label, style: theme.textTheme.titleMedium),
                      const SizedBox(width: 8),
                      GameBadge(
                        text: 'ур. ${game.slipper.level(stat)}',
                        color: color,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 3),
                Text(_value(), style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GameButton(
            onPressed: affordable ? () => game.upgrade(stat) : null,
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const ThreadIcon(size: 16),
                const SizedBox(width: 5),
                Text(fmtNum(cost)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
