import 'package:flutter/material.dart';

import '../../game/economy.dart';
import '../../game/game_state.dart';
import '../../game/slipper.dart';
import '../../game/slipper_kind.dart';
import '../format.dart';
import '../slipper_sprite.dart';
import '../theme.dart';
import '../widgets/game_widgets.dart';

/// Главный экран: тапок на коврике, монеты, прокачка.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.game});
  final GameState game;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _tapAnim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 160),
  );

  // Всплывающие «+N» при тапе.
  final List<_FloatingCoin> _floats = [];

  @override
  void dispose() {
    _tapAnim.dispose();
    super.dispose();
  }

  void _onTap(TapDownDetails d) {
    widget.game.tap();
    _tapAnim.forward(from: 0);
    final id = DateTime.now().microsecondsSinceEpoch;
    setState(() {
      _floats.add(_FloatingCoin(
        id: id,
        at: d.localPosition,
        amount: Economy.tapReward(widget.game.slipper),
      ));
    });
    Future.delayed(const Duration(milliseconds: 700), () {
      if (mounted) setState(() => _floats.removeWhere((f) => f.id == id));
    });
  }

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    return ListenableBuilder(
      listenable: game,
      builder: (context, _) {
        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: _CoinsHeader(game: game),
              ),
            ),
            SliverToBoxAdapter(
              child: Center(
                child: GestureDetector(
                  onTapDown: _onTap,
                  behavior: HitTestBehavior.opaque,
                  child: SizedBox(
                    width: 340,
                    height: 200,
                    child: Stack(
                      alignment: Alignment.center,
                      clipBehavior: Clip.none,
                      children: [
                        const Positioned(bottom: 6, child: Rug(width: 340, aspect: 0.3)),
                        Positioned(
                          bottom: 26,
                          child: AnimatedBuilder(
                            animation: _tapAnim,
                            builder: (_, child) {
                              final t = Curves.easeOut.transform(_tapAnim.value);
                              final squash = 1 - 0.12 * (1 - t);
                              final active = _tapAnim.isAnimating;
                              return Transform.scale(
                                scaleY: active ? squash : 1,
                                scaleX: active ? 2 - squash : 1,
                                alignment: Alignment.bottomCenter,
                                child: child,
                              );
                            },
                            child: SlipperSprite(slipper: game.slipper, width: 320),
                          ),
                        ),
                        for (final f in _floats)
                          Positioned(
                            left: f.at.dx - 20,
                            top: f.at.dy - 30,
                            child: _FloatingLabel(text: '+${f.amount}'),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(child: _NameRow(game: game)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
                child: Row(
                  children: [
                    const StrokeText('Прокачка', size: 24),
                    const Spacer(),
                    Text(
                      'Тапни по тапку — +${Economy.tapReward(game.slipper)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              sliver: SliverList.separated(
                itemCount: Stat.values.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (_, i) => _UpgradeTile(game: game, stat: Stat.values[i]),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _FloatingCoin {
  _FloatingCoin({required this.id, required this.at, required this.amount});
  final int id;
  final Offset at;
  final int amount;
}

class _FloatingLabel extends StatelessWidget {
  const _FloatingLabel({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOut,
      builder: (_, t, child) => Opacity(
        opacity: 1 - t,
        child: Transform.translate(offset: Offset(0, -40 * t), child: child),
      ),
      child: StrokeText(text, size: 24, color: GameColors.gold),
    );
  }
}

class _CoinsHeader extends StatelessWidget {
  const _CoinsHeader({required this.game});
  final GameState game;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GamePanel(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          const CoinIcon(size: 36),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              StrokeText(fmtNum(game.coins.floor()), size: 26, color: GameColors.gold),
              Text('+${fmtNum(game.incomePerSecond)} / с', style: theme.textTheme.bodySmall),
            ],
          ),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                children: [
                  const Icon(Icons.bolt, color: GameColors.orange, size: 18),
                  Text('${game.slipper.power}', style: theme.textTheme.titleMedium),
                ],
              ),
              Row(
                children: [
                  const Icon(Icons.emoji_events, color: GameColors.blue, size: 16),
                  const SizedBox(width: 2),
                  Text('${game.rating}', style: theme.textTheme.bodySmall),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NameRow extends StatelessWidget {
  const _NameRow({required this.game});
  final GameState game;

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
    return Column(
      children: [
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
            GameBadge(text: '${kind.rarity.label} · ${kind.name}', color: kind.rarity.color),
            for (final e in kind.bonuses.entries)
              GameBadge(text: e.key.format(e.value), color: GameColors.green),
          ],
        ),
        const SizedBox(height: 10),
        GameButton(
          color: GameColors.blue,
          height: 38,
          onPressed: () => _pickKind(context),
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

  /// Выбор вида из каталога. Пока доступны все — кейсы и коллекция позже.
  Future<void> _pickKind(BuildContext context) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _KindPicker(current: game.slipper.kindId),
    );
    if (picked != null) game.equip(picked);
  }
}

class _KindPicker extends StatelessWidget {
  const _KindPicker({required this.current});
  final String current;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + MediaQuery.paddingOf(context).bottom),
      decoration: const BoxDecoration(
        color: GameColors.panelDark,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: GameColors.outline, width: 3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const StrokeText('Коллекция', size: 24),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.6),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: SlipperCatalog.all.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final kind = SlipperCatalog.all[i];
                final selected = kind.id == current;
                return GamePanel(
                  padding: const EdgeInsets.all(10),
                  onTap: () => Navigator.pop(context, kind.id),
                  child: Row(
                    children: [
                      SlipperSprite(
                        slipper: Slipper(name: kind.id, kindId: kind.id),
                        width: 120,
                        animate: false,
                        showSize: false,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(kind.name, style: theme.textTheme.titleMedium),
                            const SizedBox(height: 4),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                GameBadge(text: kind.rarity.label, color: kind.rarity.color),
                                for (final e in kind.bonuses.entries)
                                  GameBadge(text: e.key.format(e.value), color: GameColors.green),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (selected)
                        const Icon(Icons.check_circle, color: GameColors.gold, size: 28)
                      else
                        const Icon(Icons.chevron_right, color: GameColors.textDim),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
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
      Stat.attack => '${s.attack.toStringAsFixed(0)} урона · крит ${(s.critChance * 100).round()}%',
      Stat.defense => '−${(100 - 10000 / (100 + s.defense)).round()}% входящего урона',
      Stat.health => '${s.maxHp.round()} HP · размер ${(s.sizeFactor * 100).round()}%',
      Stat.speed => '${s.speed.round()} скорости · уворот ${(s.dodgeChance * 100).round()}%',
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
                Row(
                  children: [
                    Text(stat.label, style: theme.textTheme.titleMedium),
                    const SizedBox(width: 8),
                    GameBadge(text: 'ур. ${game.slipper.level(stat)}', color: color),
                  ],
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
                const CoinIcon(size: 16),
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
