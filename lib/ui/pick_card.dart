import 'package:flutter/material.dart';

import '../game/game_state.dart';
import '../game/slipper.dart';
import '../game/slipper_kind.dart';
import '../game/weekly.dart';
import 'slipper_sprite.dart';
import 'theme.dart';
import 'toast.dart';
import 'widgets/game_widgets.dart';

/// Карта выбора тапка: розово-золотая супер карта и золотисто-синяя обычная.
class PickCardIcon extends StatelessWidget {
  const PickCardIcon({super.key, required this.card, this.size = 56});
  final PickCard card;
  final double size;

  @override
  Widget build(BuildContext context) {
    final superCard = card == PickCard.superCard;
    final colors = superCard
        ? const [Color(0xFFFF8BC4), Color(0xFFFF5FA2), Color(0xFFFFC93C)]
        : const [Color(0xFFFFE27A), Color(0xFFFFC93C), Color(0xFF5BC8FF)];
    return Container(
      width: size * 0.74,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.12),
        border: Border.all(color: GameColors.outline, width: size * 0.05),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
        boxShadow: [
          BoxShadow(
            color: colors[1].withValues(alpha: 0.6),
            blurRadius: size * 0.2,
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(
            Icons.question_mark_rounded,
            size: size * 0.5,
            color: Colors.white.withValues(alpha: 0.9),
          ),
          Positioned(
            top: size * 0.06,
            child: Icon(
              superCard ? Icons.auto_awesome_rounded : Icons.star_rounded,
              size: size * 0.22,
              color: GameColors.outline,
            ),
          ),
        ],
      ),
    );
  }
}

/// Карты выбора в инвентаре: по нажатию — выбор тапка.
class PickCardsSection extends StatelessWidget {
  const PickCardsSection({super.key, required this.game});
  final GameState game;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cards = [
      for (final c in PickCard.values)
        if (game.cardCount(c) > 0) c,
    ];
    if (cards.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Карты выбора', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        for (final c in cards) ...[
          GamePanel(
            padding: const EdgeInsets.all(10),
            onTap: () => showPickCardSheet(context, game, c),
            child: Row(
              children: [
                PickCardIcon(card: c, size: 52),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c.title, style: theme.textTheme.titleSmall),
                      Text(c.description, style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
                StrokeText('×${game.cardCount(c)}', size: 20),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
        const SizedBox(height: 8),
      ],
    );
  }
}

/// Выбор тапка по карте: сетка всех тапков, которые карта позволяет взять.
Future<void> showPickCardSheet(
  BuildContext context,
  GameState game,
  PickCard card,
) {
  final kinds = [
    for (final r in Rarity.values.reversed)
      for (final k in SlipperCatalog.byRarity(r))
        if (GameState.cardAllows(card, k)) k,
  ];
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: GameColors.panel,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      side: BorderSide(color: GameColors.outline, width: 3),
    ),
    builder: (sheet) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(sheet).size.height * 0.8,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              StrokeText(card.title, size: 22),
              const SizedBox(height: 4),
              Text(
                'Выбери тапок — он добавится в коллекцию',
                style: Theme.of(sheet).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.05,
                children: [
                  for (final k in kinds)
                    _Choice(
                      kind: k,
                      have: game.count(k.id),
                      onTap: () => _confirm(sheet, game, card, k),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

Future<void> _confirm(
  BuildContext sheet,
  GameState game,
  PickCard card,
  SlipperKind kind,
) async {
  final ok = await showDialog<bool>(
    context: sheet,
    builder: (context) => AlertDialog(
      title: StrokeText(kind.name, size: 22, color: kind.rarity.color),
      content: Text(
        game.count(kind.id) > 0
            ? 'У тебя уже есть этот тапок — придёт ещё один (пригодится для звёзд). Забрать?'
            : 'Забрать этот тапок за «${card.title}»?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Назад'),
        ),
        GameButton(
          color: GameColors.green,
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Забрать'),
        ),
      ],
    ),
  );
  if (ok != true || !sheet.mounted) return;
  if (!game.usePickCard(card, kind.id)) return;
  showToast(sheet, '${kind.name} — в коллекции!', kind: ToastKind.reward);
  Navigator.pop(sheet);
}

class _Choice extends StatelessWidget {
  const _Choice({required this.kind, required this.have, required this.onTap});
  final SlipperKind kind;
  final int have;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = kind.rarity.color;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: GameColors.outline, width: 2.5),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color.lerp(c, Colors.black, 0.45)!,
              Color.lerp(c, Colors.black, 0.7)!,
            ],
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: SlipperSprite(
                  fighter: Slipper(name: kind.id, kindId: kind.id),
                  width: 120,
                  animate: false,
                  showSize: false,
                ),
              ),
            ),
            Text(
              kind.name,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            Text(
              have > 0
                  ? '${kind.rarity.label} · есть ×$have'
                  : kind.rarity.label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(color: c),
            ),
          ],
        ),
      ),
    );
  }
}
