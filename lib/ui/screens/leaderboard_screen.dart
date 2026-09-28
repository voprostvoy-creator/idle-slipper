import 'dart:math';

import 'package:flutter/material.dart';

import '../../game/game_state.dart';
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
    return ListenableBuilder(
      listenable: game,
      builder: (context, _) => _build(context),
    );
  }

  Widget _build(BuildContext context) {
    final board = game.arenaBoard;
    // Строки с сервера: место, тапок, очки, «это я». Себя, если не попал
    // в топ, добавляем в конец со своим местом.
    final rows = <(int, Slipper, int, bool)>[
      if (board != null)
        for (final e in board.top)
          (e.place, e.slipper, e.rating, e.id == board.me.id),
      if (board != null && !board.top.any((e) => e.id == board.me.id))
        (board.me.place, game.slipper, board.me.rating, true),
    ];
    final myIndex = rows.indexWhere((r) => r.$4);
    // Сразу показываем игрока, а не верх списка.
    final controller = ScrollController(
      initialScrollOffset: max(0, (myIndex - 2) * _rowExtent),
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
                      child: const Icon(
                        Icons.arrow_back_rounded,
                        color: GameColors.text,
                      ),
                    ),
                    const Expanded(
                      child: Center(child: StrokeText('Рейтинг', size: 30)),
                    ),
                    const SizedBox(width: 44),
                  ],
                ),
              ),
              Expanded(
                child: board == null
                    ? Center(
                        child: Text(
                          game.arenaError ?? 'Загрузка…',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      )
                    : ListView.builder(
                        controller: controller,
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        itemExtent: _rowExtent,
                        itemCount: rows.length,
                        itemBuilder: (context, i) {
                          final (place, slipper, rating, isMe) = rows[i];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _Row(
                              place: place,
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
          SlipperSprite(
            fighter: slipper,
            width: 72,
            animate: false,
            showSize: false,
          ),
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
                    const PowerIcon(size: 14),
                    const SizedBox(width: 3),
                    Text('${slipper.power}', style: theme.textTheme.bodySmall),
                    if (slipper.stars > 0) ...[
                      const SizedBox(width: 6),
                      Text(
                        '★' * slipper.stars,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: GameColors.gold,
                        ),
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
