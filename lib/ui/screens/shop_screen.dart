import 'package:flutter/material.dart';

import '../../game/case_box.dart';
import '../../game/game_state.dart';
import '../../game/slipper_kind.dart';
import '../format.dart';
import '../theme.dart';
import '../widgets/game_widgets.dart';
import 'case_open_screen.dart';

/// Магазин: пока один кейс с тапками за нитки.
class ShopScreen extends StatelessWidget {
  const ShopScreen({super.key, required this.game});
  final GameState game;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListenableBuilder(
      listenable: game,
      builder: (context, _) {
        final chances = CaseBox.chances();
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          children: [
            const Center(child: StrokeText('Магазин', size: 30)),
            const SizedBox(height: 16),
            GamePanel(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  Row(
                    children: [
                      const CaseIcon(size: 64),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Кейс с тапками', style: theme.textTheme.titleLarge),
                            const SizedBox(height: 4),
                            Text(
                              'Внутри случайный тапок. Выпавшее можно оставить '
                              'или сразу продать.',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Шансы по редкостям.
                  Row(
                    children: [
                      for (final r in Rarity.values)
                        if ((chances[r] ?? 0) > 0)
                          Expanded(
                            child: Column(
                              children: [
                                Container(
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: r.color,
                                    borderRadius: BorderRadius.circular(3),
                                    border: Border.all(color: GameColors.outline, width: 1.5),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${(chances[r]! * 100).toStringAsFixed(chances[r]! < 0.1 ? 1 : 0)}%',
                                  style: theme.textTheme.labelSmall?.copyWith(color: r.color),
                                ),
                              ],
                            ),
                          ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: GameButton(
                      color: game.canOpenCase ? GameColors.gold : GameColors.panelLight,
                      height: 52,
                      onPressed: game.canOpenCase ? () => _open(context) : null,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('Открыть за '),
                          const ThreadIcon(size: 20),
                          const SizedBox(width: 4),
                          Text(fmtNum(CaseBox.price)),
                        ],
                      ),
                    ),
                  ),
                  if (!game.canOpenCase) ...[
                    const SizedBox(height: 6),
                    Text('Не хватает ниток', style: theme.textTheme.bodySmall),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),
            GamePanel(
              color: GameColors.panelDark,
              child: Row(
                children: [
                  const CoinIcon(size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Лавка за монеты',
                          style: theme.textTheme.titleMedium?.copyWith(color: GameColors.textDim),
                        ),
                        Text('Скоро', style: theme.textTheme.bodySmall),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  void _open(BuildContext context) {
    final kind = game.openCase();
    if (kind == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => CaseOpenScreen(game: game, prize: kind)),
    );
  }
}

/// Иконка кейса: ящик с крышкой и замком.
class CaseIcon extends StatelessWidget {
  const CaseIcon({super.key, this.size = 48});
  final double size;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: _CasePainter());
}

class _CasePainter extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    final w = s.width;
    final h = s.height;
    final outline = Paint()
      ..color = GameColors.outline
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.06
      ..strokeJoin = StrokeJoin.round;

    // Корпус.
    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.08, h * 0.38, w * 0.84, h * 0.5),
      Radius.circular(w * 0.07),
    );
    c.drawRRect(body, Paint()..color = const Color(0xFF6B4A2F));
    c.save();
    c.clipRRect(body);
    c.drawRect(
      Rect.fromLTWH(w * 0.08, h * 0.38, w * 0.84, h * 0.1),
      Paint()..color = const Color(0xFF8A6039),
    );
    c.restore();
    c.drawRRect(body, outline);

    // Крышка.
    final lid = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.04, h * 0.2, w * 0.92, h * 0.22),
      Radius.circular(w * 0.06),
    );
    c.drawRRect(lid, Paint()..color = const Color(0xFF8A6039));
    c.drawRRect(lid, outline);

    // Металлические уголки и замок.
    final metal = Paint()..color = GameColors.gold;
    final lock = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.4, h * 0.36, w * 0.2, h * 0.22),
      Radius.circular(w * 0.04),
    );
    c.drawRRect(lock, metal);
    c.drawRRect(lock, outline);
    c.drawCircle(Offset(w * 0.5, h * 0.47), w * 0.04, Paint()..color = GameColors.outline);
  }

  @override
  bool shouldRepaint(_CasePainter old) => false;
}
