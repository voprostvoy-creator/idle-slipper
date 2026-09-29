import 'package:flutter/material.dart';

import '../../game/case_box.dart';
import '../../game/daily.dart';
import '../../game/game_state.dart';
import '../../game/slipper.dart';
import '../../game/slipper_kind.dart';
import '../format.dart';
import '../slipper_sprite.dart';
import '../theme.dart';
import '../widgets/game_widgets.dart';
import 'case_open_screen.dart';

/// Магазин: кейсы с тапками.
class ShopScreen extends StatelessWidget {
  const ShopScreen({super.key, required this.game});
  final GameState game;

  @override
  Widget build(BuildContext context) {
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
            _CoinShop(game: game),
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
              CaseIcon(size: 58, free: type.isFree && !type.daily),
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
              child: type.daily
                  ? Text(canOpen
                      ? 'Забрать бесплатно'
                      : 'Новый через ${fmtClock(untilMidnight(game.clock()))}')
                  : type.isFree
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
          if (!canOpen && !type.daily) ...[
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

/// Лавка за монеты: три случайных тапка (кроме обычных), новые каждый день.
class _CoinShop extends StatelessWidget {
  const _CoinShop({required this.game});
  final GameState game;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GamePanel(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: Column(
        children: [
          Row(
            children: [
              const CoinIcon(size: 26),
              const SizedBox(width: 8),
              Text('Лавка за монеты', style: theme.textTheme.titleLarge),
            ],
          ),
          const SizedBox(height: 2),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Новые тапки через ${fmtClock(untilMidnight(game.clock()))}',
              style: theme.textTheme.bodySmall,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final (i, k) in game.shopOffers.indexed) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(child: _Offer(game: game, kind: k)),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _Offer extends StatelessWidget {
  const _Offer({required this.game, required this.kind});

  final GameState game;
  final SlipperKind kind;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sold = game.shopSold(kind);
    final price = CoinShop.priceOf(kind.rarity);
    final can = game.canBuy(kind);
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 8, 6, 8),
      decoration: BoxDecoration(
        color: GameColors.panelDark,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kind.rarity.color, width: 2.5),
      ),
      child: Column(
        children: [
          Opacity(
            opacity: sold ? 0.4 : 1,
            child: SlipperSprite(
              fighter: Slipper(name: kind.name, kindId: kind.id),
              width: 86,
              animate: false,
              showSize: false,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            kind.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(color: GameColors.text),
          ),
          Text(
            kind.rarity.label,
            style: theme.textTheme.labelSmall?.copyWith(color: kind.rarity.color),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            child: GameButton(
              color: sold
                  ? GameColors.panelDark
                  : (can ? GameColors.gold : GameColors.panelLight),
              height: 34,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              onPressed: can ? () => game.buyFromShop(kind) : null,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: sold
                    ? const Text('Куплено', style: TextStyle(fontSize: 13))
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CoinIcon(size: 14),
                          const SizedBox(width: 3),
                          Text(fmtNum(price), style: const TextStyle(fontSize: 13)),
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Иконка кейса — прорисованный сундук: доски, кованые полосы с
/// заклёпками, золотой кант и замок. Бесплатный — в зелёной окраске.
class CaseIcon extends StatelessWidget {
  const CaseIcon({super.key, this.size = 48, this.free = false});
  final double size;
  final bool free;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: _ChestPainter(free: free));
}

class _ChestPainter extends CustomPainter {
  _ChestPainter({required this.free});
  final bool free;

  @override
  void paint(Canvas c, Size s) {
    final w = s.width;
    final h = s.height;
    Offset p(double x, double y) => Offset(w * x, h * y);
    final outline = Paint()
      ..color = GameColors.outline
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.045
      ..strokeJoin = StrokeJoin.round;

    final woodLight = free ? const Color(0xFF4FAE78) : const Color(0xFFB4743F);
    final woodMid = free ? const Color(0xFF3A8A5C) : const Color(0xFF8E5528);
    final woodDark = free ? const Color(0xFF245C3C) : const Color(0xFF5E3417);
    const metal = Color(0xFF5B5F6B);
    const metalLight = Color(0xFF9BA1AE);
    const gold = GameColors.gold;
    const goldDark = GameColors.goldDark;

    // Тень под сундуком.
    c.drawOval(
      Rect.fromCenter(center: p(0.5, 0.93), width: w * 0.84, height: h * 0.1),
      Paint()..color = const Color(0x55000000),
    );

    // Корпус.
    final body = RRect.fromRectAndRadius(Rect.fromLTRB(w * 0.1, h * 0.46, w * 0.9, h * 0.9), Radius.circular(w * 0.06));
    c.drawRRect(
      body,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [woodMid, woodDark],
        ).createShader(body.outerRect),
    );
    // Доски.
    final plank = Paint()
      ..color = woodDark.withValues(alpha: 0.8)
      ..strokeWidth = w * 0.02;
    for (final y in [0.61, 0.75]) {
      c.drawLine(p(0.12, y), p(0.88, y), plank);
    }

    // Крышка: полукруглый верх.
    final lid = Path()
      ..moveTo(w * 0.1, h * 0.47)
      ..lineTo(w * 0.1, h * 0.34)
      ..quadraticBezierTo(w * 0.1, h * 0.12, w * 0.5, h * 0.12)
      ..quadraticBezierTo(w * 0.9, h * 0.12, w * 0.9, h * 0.34)
      ..lineTo(w * 0.9, h * 0.47)
      ..close();
    c.drawPath(
      lid,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [woodLight, woodMid],
        ).createShader(Rect.fromLTRB(0, h * 0.12, w, h * 0.47)),
    );
    // Блик на крышке.
    c.drawPath(
      Path()
        ..moveTo(w * 0.2, h * 0.3)
        ..quadraticBezierTo(w * 0.3, h * 0.19, w * 0.48, h * 0.18),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.035
        ..strokeCap = StrokeCap.round,
    );

    // Кованые полосы с заклёпками — через крышку и корпус.
    for (final x in [0.26, 0.74]) {
      final band = RRect.fromRectAndRadius(
        Rect.fromCenter(center: p(x, 0.52), width: w * 0.1, height: h * 0.76),
        Radius.circular(w * 0.02),
      );
      c.save();
      c.clipPath(Path()..addPath(lid, Offset.zero)..addRRect(body));
      c.drawRRect(
        band,
        Paint()
          ..shader = const LinearGradient(colors: [metalLight, metal]).createShader(band.outerRect),
      );
      c.restore();
      for (final y in [0.3, 0.58, 0.82]) {
        c.drawCircle(p(x, y), w * 0.018, Paint()..color = metalLight);
      }
    }

    // Золотой кант между крышкой и корпусом.
    final rim = RRect.fromRectAndRadius(
      Rect.fromLTRB(w * 0.07, h * 0.43, w * 0.93, h * 0.51),
      Radius.circular(w * 0.03),
    );
    c.drawRRect(
      rim,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [GameColors.goldLight, goldDark],
        ).createShader(rim.outerRect),
    );
    c.drawRRect(rim, outline);

    // Контуры корпуса и крышки.
    c.drawRRect(body, outline);
    c.drawPath(lid, outline);

    // Замок.
    final lock = RRect.fromRectAndRadius(
      Rect.fromCenter(center: p(0.5, 0.56), width: w * 0.22, height: h * 0.24),
      Radius.circular(w * 0.05),
    );
    c.drawRRect(
      lock,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [GameColors.goldLight, gold, goldDark],
        ).createShader(lock.outerRect),
    );
    c.drawRRect(lock, outline);
    // Замочная скважина.
    c.drawCircle(p(0.5, 0.535), w * 0.032, Paint()..color = GameColors.outline);
    c.drawPath(
      Path()
        ..moveTo(w * 0.485, h * 0.55)
        ..lineTo(w * 0.515, h * 0.55)
        ..lineTo(w * 0.525, h * 0.62)
        ..lineTo(w * 0.475, h * 0.62)
        ..close(),
      Paint()..color = GameColors.outline,
    );
  }

  @override
  bool shouldRepaint(_ChestPainter old) => old.free != free;
}
