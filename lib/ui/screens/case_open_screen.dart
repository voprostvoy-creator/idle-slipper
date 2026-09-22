import 'dart:math';

import 'package:flutter/material.dart';

import '../../game/case_box.dart';
import '../../game/game_state.dart';
import '../../game/slipper.dart';
import '../../game/slipper_kind.dart';
import '../format.dart';
import '../slipper_sprite.dart';
import '../theme.dart';
import '../widgets/game_widgets.dart';

/// Открытие кейса: лента тапков прокручивается и тормозит на выигрыше.
/// Приз уже лежит в инвентаре — этот экран только показывает результат
/// и предлагает продать.
class CaseOpenScreen extends StatefulWidget {
  const CaseOpenScreen({super.key, required this.game, required this.prize});

  final GameState game;
  final SlipperKind prize;

  @override
  State<CaseOpenScreen> createState() => _CaseOpenScreenState();
}

class _CaseOpenScreenState extends State<CaseOpenScreen>
    with SingleTickerProviderStateMixin {
  static const _itemW = 132.0;
  static const _itemH = 106.0;
  static const _reelLength = 48;
  static const _winnerIndex = 42;

  late final List<SlipperKind> _reel;
  late final double _jitter;
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 4600),
  );
  late final Animation<double> _curve =
      CurvedAnimation(parent: _spin, curve: Curves.easeOutQuart);

  bool _done = false;
  bool _sold = false;

  @override
  void initState() {
    super.initState();
    final rng = Random();
    _reel = CaseBox.reel(rng, widget.prize, _reelLength, _winnerIndex);
    // Небольшой сдвиг от центра — лента останавливается не идеально ровно.
    _jitter = (rng.nextDouble() - 0.5) * _itemW * 0.5;
    _spin.forward().whenComplete(() {
      if (mounted) setState(() => _done = true);
    });
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  void _sell() {
    if (!widget.game.sell(widget.prize.id)) return;
    setState(() => _sold = true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: GameBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                child: Row(
                  children: [
                    GameButton(
                      onPressed: () => Navigator.of(context).pop(),
                      color: GameColors.panelLight,
                      height: 36,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: const Icon(Icons.arrow_back_rounded, color: GameColors.text),
                    ),
                    const Spacer(),
                    const StrokeText('Кейс', size: 24),
                    const Spacer(),
                    const SizedBox(width: 44),
                  ],
                ),
              ),
              const Spacer(),
              _Reel(
                reel: _reel,
                itemW: _itemW,
                itemH: _itemH,
                winnerIndex: _winnerIndex,
                jitter: _jitter,
                progress: _curve,
              ),
              const Spacer(),
              AnimatedOpacity(
                duration: const Duration(milliseconds: 300),
                opacity: _done ? 1 : 0,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: _done ? _result(theme) : const SizedBox(height: 210),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _result(ThemeData theme) {
    final kind = widget.prize;
    final count = widget.game.count(kind.id);
    final sellPrice = CaseBox.sellPrice(kind.rarity);
    // Последний экземпляр надетого тапка продавать нельзя.
    final canSell = !_sold && count > 0 && !(count == 1 && kind.id == widget.game.slipper.kindId);
    return GamePanel(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          StrokeText(kind.name, size: 24, color: kind.rarity.color),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            alignment: WrapAlignment.center,
            children: [
              GameBadge(text: kind.rarity.label, color: kind.rarity.color),
              for (final e in kind.bonuses.entries)
                GameBadge(text: e.key.format(e.value), color: GameColors.green),
              if (count > 1 && !_sold)
                GameBadge(text: 'в коллекции ×$count', color: GameColors.panelLight),
            ],
          ),
          const SizedBox(height: 14),
          if (_sold)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const ThreadIcon(size: 22),
                const SizedBox(width: 6),
                StrokeText('+${fmtNum(sellPrice)}', size: 22, color: GameColors.thread),
              ],
            )
          else
            Row(
              children: [
                Expanded(
                  child: GameButton(
                    color: canSell ? GameColors.panelLight : GameColors.panelDark,
                    onPressed: canSell ? _sell : null,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Продать ',
                          style: TextStyle(color: canSell ? GameColors.text : GameColors.textDim),
                        ),
                        const ThreadIcon(size: 16),
                        const SizedBox(width: 4),
                        Text(
                          fmtNum(sellPrice),
                          style: TextStyle(color: canSell ? GameColors.text : GameColors.textDim),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GameButton(
                    color: GameColors.green,
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Оставить'),
                  ),
                ),
              ],
            ),
          if (_sold) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: GameButton(
                color: GameColors.gold,
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('В магазин'),
              ),
            ),
          ] else if (!canSell) ...[
            const SizedBox(height: 6),
            Text(
              'Единственный надетый тапок продать нельзя',
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

/// Сама лента с маркером по центру.
class _Reel extends StatelessWidget {
  const _Reel({
    required this.reel,
    required this.itemW,
    required this.itemH,
    required this.winnerIndex,
    required this.jitter,
    required this.progress,
  });

  final List<SlipperKind> reel;
  final double itemW;
  final double itemH;
  final int winnerIndex;
  final double jitter;
  final Animation<double> progress;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: itemH + 28,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Рамка ленты.
          Container(
            decoration: BoxDecoration(
              color: GameColors.panelDark,
              border: const Border.symmetric(
                horizontal: BorderSide(color: GameColors.outline, width: 3),
              ),
            ),
            child: ClipRect(
              child: LayoutBuilder(
                builder: (context, c) {
                  final target = winnerIndex * itemW - (c.maxWidth - itemW) / 2 + jitter;
                  return AnimatedBuilder(
                    animation: progress,
                    builder: (context, _) {
                      final dx = -target * progress.value;
                      return Stack(
                        clipBehavior: Clip.none,
                        children: [
                          for (var i = 0; i < reel.length; i++)
                            Positioned(
                              left: dx + i * itemW,
                              top: 14,
                              child: _ReelItem(kind: reel[i], width: itemW, height: itemH),
                            ),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
          ),
          // Маркер: стрелки сверху и снизу + линия.
          IgnorePointer(
            child: SizedBox(
              height: itemH + 28,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const _Marker(down: true),
                  Container(width: 3, height: itemH, color: GameColors.gold.withValues(alpha: 0.35)),
                  const _Marker(down: false),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Marker extends StatelessWidget {
  const _Marker({required this.down});
  final bool down;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: down ? 0 : pi,
      child: CustomPaint(size: const Size(20, 14), painter: _TrianglePainter()),
    );
  }
}

class _TrianglePainter extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    final p = Path()
      ..moveTo(0, 0)
      ..lineTo(s.width, 0)
      ..lineTo(s.width / 2, s.height)
      ..close();
    c.drawPath(p, Paint()..color = GameColors.gold);
    c.drawPath(
      p,
      Paint()
        ..color = GameColors.outline
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_TrianglePainter old) => false;
}

/// Карточка в ленте: фон окрашен по редкости.
class _ReelItem extends StatelessWidget {
  const _ReelItem({required this.kind, required this.width, required this.height});

  final SlipperKind kind;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final c = kind.rarity.color;
    return Container(
      width: width - 8,
      height: height,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
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
      child: Stack(
        children: [
          // Полоса редкости снизу — как в кейсах шутеров.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              height: 6,
              decoration: BoxDecoration(
                color: c,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(9)),
              ),
            ),
          ),
          Center(
            child: SlipperSprite(
              slipper: Slipper(name: kind.id, kindId: kind.id),
              width: width - 20,
              animate: false,
              showSize: false,
            ),
          ),
        ],
      ),
    );
  }
}
