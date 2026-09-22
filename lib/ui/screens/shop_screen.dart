import 'package:flutter/material.dart';

import '../../game/case_box.dart';
import '../../game/game_state.dart';
import '../format.dart';
import '../theme.dart';
import '../widgets/game_widgets.dart';
import 'case_open_screen.dart';

/// Магазин: кейсы с тапками.
class ShopScreen extends StatelessWidget {
  const ShopScreen({super.key, required this.game});
  final GameState game;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListenableBuilder(
      listenable: game,
      builder: (context, _) {
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          children: [
            const Center(child: StrokeText('Магазин', size: 30)),
            const SizedBox(height: 14),
            for (final type in CaseCatalog.all) ...[
              _CaseCard(game: game, type: type),
              const SizedBox(height: 14),
            ],
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
                          style: theme.textTheme.titleMedium
                              ?.copyWith(color: GameColors.textDim),
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
}

class _CaseCard extends StatelessWidget {
  const _CaseCard({required this.game, required this.type});

  final GameState game;
  final CaseType type;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chances = type.chances();
    final canOpen = game.canOpen(type);
    return GamePanel(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          Row(
            children: [
              CaseIcon(size: 58, free: type.isFree),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(type.name, style: theme.textTheme.titleLarge),
                    const SizedBox(height: 4),
                    Text(type.description, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Полоса шансов: ширина сегмента пропорциональна вероятности.
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Row(
              children: [
                for (final e in chances.entries)
                  Expanded(
                    flex: (e.value * 1000).round(),
                    child: Container(height: 8, color: e.key.color),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 10,
            runSpacing: 4,
            children: [
              for (final e in chances.entries)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(color: e.key.color, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${(e.value * 100).toStringAsFixed(e.value < 0.1 ? 1 : 0)}%',
                      style: theme.textTheme.labelSmall?.copyWith(color: e.key.color),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: GameButton(
              color: canOpen
                  ? (type.isFree ? GameColors.green : GameColors.gold)
                  : GameColors.panelLight,
              height: 50,
              onPressed: canOpen ? () => _open(context) : null,
              child: type.isFree
                  ? const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.play_circle_fill_rounded, size: 20),
                        SizedBox(width: 6),
                        Text('Открыть бесплатно'),
                      ],
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Открыть за '),
                        const ThreadIcon(size: 20),
                        const SizedBox(width: 4),
                        Text(fmtNum(type.price)),
                      ],
                    ),
            ),
          ),
          if (!canOpen) ...[
            const SizedBox(height: 6),
            Text('Не хватает ниток', style: theme.textTheme.bodySmall),
          ],
        ],
      ),
    );
  }

  void _open(BuildContext context) {
    final kind = game.openCase(type);
    if (kind == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CaseOpenScreen(game: game, type: type, prize: kind),
      ),
    );
  }
}

/// Иконка кейса: ящик с крышкой и замком. Бесплатный — зелёный.
class CaseIcon extends StatelessWidget {
  const CaseIcon({super.key, this.size = 48, this.free = false});
  final double size;
  final bool free;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: _CasePainter(free: free));
}

class _CasePainter extends CustomPainter {
  _CasePainter({required this.free});
  final bool free;

  @override
  void paint(Canvas c, Size s) {
    final w = s.width;
    final h = s.height;
    final outline = Paint()
      ..color = GameColors.outline
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.06
      ..strokeJoin = StrokeJoin.round;
    final dark = free ? const Color(0xFF2E6B4A) : const Color(0xFF6B4A2F);
    final light = free ? const Color(0xFF3F8F62) : const Color(0xFF8A6039);

    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.08, h * 0.38, w * 0.84, h * 0.5),
      Radius.circular(w * 0.07),
    );
    c.drawRRect(body, Paint()..color = dark);
    c.save();
    c.clipRRect(body);
    c.drawRect(
      Rect.fromLTWH(w * 0.08, h * 0.38, w * 0.84, h * 0.1),
      Paint()..color = light,
    );
    c.restore();
    c.drawRRect(body, outline);

    final lid = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.04, h * 0.2, w * 0.92, h * 0.22),
      Radius.circular(w * 0.06),
    );
    c.drawRRect(lid, Paint()..color = light);
    c.drawRRect(lid, outline);

    final lock = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.4, h * 0.36, w * 0.2, h * 0.22),
      Radius.circular(w * 0.04),
    );
    c.drawRRect(lock, Paint()..color = GameColors.gold);
    c.drawRRect(lock, outline);
    c.drawCircle(Offset(w * 0.5, h * 0.47), w * 0.04, Paint()..color = GameColors.outline);
  }

  @override
  bool shouldRepaint(_CasePainter old) => old.free != free;
}
