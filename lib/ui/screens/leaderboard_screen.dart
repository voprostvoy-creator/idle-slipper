import 'dart:math';

import 'package:flutter/material.dart';

import '../../game/game_state.dart';
import '../../game/leaderboard.dart';
import '../../game/slipper.dart';
import '../slipper_sprite.dart';
import '../theme.dart';
import '../widgets/game_widgets.dart';

/// Рейтинг арены: все участники по очкам, игрок среди них подсвечен.
class LeaderboardScreen extends StatelessWidget {
  const LeaderboardScreen({super.key, required this.game});
  final GameState game;

  static const _rowExtent = 84.0;

  @override
  Widget build(BuildContext context) {
    final place = game.arenaPlace;
    final rows = <(Slipper, int, bool)>[
      for (final b in Leaderboard.bots) (b.slipper, b.rating, false),
    ]..insert(place - 1, (game.slipper, game.rating, true));
    // Сразу показываем игрока, а не верх списка.
    final controller = ScrollController(
      initialScrollOffset: max(0, (place - 3) * _rowExtent),
    );
    return Scaffold(
      body: GameBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Row(
                  children: [
                    GameButton(
                      onPressed: () => Navigator.of(context).pop(),
                      color: GameColors.panelLight,
                      height: 36,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: const Icon(Icons.arrow_back_rounded, color: GameColors.text),
                    ),
                    const Expanded(child: Center(child: StrokeText('Рейтинг', size: 30))),
                    const SizedBox(width: 44),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  controller: controller,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemExtent: _rowExtent,
                  itemCount: rows.length,
                  itemBuilder: (context, i) {
                    final (slipper, rating, isMe) = rows[i];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _Row(
                        place: i + 1,
                        slipper: slipper,
                        rating: rating,
                        isMe: isMe,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.place,
    required this.slipper,
    required this.rating,
    required this.isMe,
  });

  final int place;
  final Slipper slipper;
  final int rating;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final medal = switch (place) {
      1 => GameColors.gold,
      2 => const Color(0xFFD9DDE6),
      3 => const Color(0xFFD08A4E),
      _ => GameColors.panelDark,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: isMe ? GameColors.panelLight : GameColors.panel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isMe ? GameColors.gold : GameColors.outline,
          width: isMe ? 3.5 : 3,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: medal,
              border: Border.all(color: GameColors.outline, width: 2.5),
            ),
            child: Text(
              '$place',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: place <= 3 ? GameColors.outline : GameColors.text,
              ),
            ),
          ),
          const SizedBox(width: 8),
          SlipperSprite(fighter: slipper, width: 72, animate: false, showSize: false),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isMe ? 'Ты · ${slipper.name}' : slipper.name,
                  style: theme.textTheme.titleSmall,
                  overflow: TextOverflow.ellipsis,
                ),
                Row(
                  children: [
                    const Icon(Icons.bolt, color: GameColors.orange, size: 15),
                    Text('${slipper.power}', style: theme.textTheme.bodySmall),
                    if (slipper.stars > 0) ...[
                      const SizedBox(width: 6),
                      Text(
                        '★' * slipper.stars,
                        style: theme.textTheme.bodySmall?.copyWith(color: GameColors.gold),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const Icon(Icons.emoji_events, color: GameColors.blue, size: 18),
          const SizedBox(width: 3),
          Text('$rating', style: theme.textTheme.titleMedium),
        ],
      ),
    );
  }
}
