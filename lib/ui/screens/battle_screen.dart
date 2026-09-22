import 'dart:async';

import 'package:flutter/material.dart';

import '../../game/battle/battle_sim.dart';
import '../../game/slipper.dart';
import '../slipper_sprite.dart';
import '../theme.dart';
import '../widgets/game_widgets.dart';

/// Проигрывает готовую запись боя: выпады, урон, HP-бары, итог.
class BattleScreen extends StatefulWidget {
  const BattleScreen({
    super.key,
    required this.player,
    required this.opponent,
    required this.result,
    required this.ratingDelta,
    required this.threadsDelta,
  });

  final Slipper player;
  final Slipper opponent;
  final BattleResult result;
  final int ratingDelta;
  final int threadsDelta;

  @override
  State<BattleScreen> createState() => _BattleScreenState();
}

class _BattleScreenState extends State<BattleScreen>
    with SingleTickerProviderStateMixin {
  static const _stepDuration = Duration(milliseconds: 650);

  late double _hpPlayer = widget.result.playerMaxHp;
  late double _hpOpponent = widget.result.opponentMaxHp;
  var _mood = {Side.player: SlipperMood.idle, Side.opponent: SlipperMood.idle};
  final _log = <String>[];
  final _popups = <_Popup>[];
  int _index = 0;
  bool _finished = false;
  Timer? _timer;

  /// Выпад атакующего: 0 — на месте, 1 — максимально вперёд.
  late final AnimationController _lunge = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
  );
  Side? _lunging;

  @override
  void initState() {
    super.initState();
    // Небольшая пауза перед первым ударом — игрок успевает увидеть соперника.
    _timer = Timer(const Duration(milliseconds: 900), _tick);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _lunge.dispose();
    super.dispose();
  }

  void _tick() {
    if (_index >= widget.result.events.length) {
      _finish();
      return;
    }
    final e = widget.result.events[_index++];
    _play(e);
    _timer = Timer(_stepDuration, _tick);
  }

  void _play(BattleEvent e) {
    final attacker = switch (e) {
      HitEvent(:final attacker) => attacker,
      DodgeEvent(:final attacker) => attacker,
    };
    final target = attacker.other;
    final attackerName = attacker == Side.player ? widget.player.name : widget.opponent.name;

    setState(() {
      _lunging = attacker;
      _mood = {attacker: SlipperMood.attack, target: SlipperMood.idle};
      switch (e) {
        case HitEvent(:final damage, :final crit, :final targetHpAfter):
          if (target == Side.player) {
            _hpPlayer = targetHpAfter;
          } else {
            _hpOpponent = targetHpAfter;
          }
          _mood[target] = targetHpAfter <= 0 ? SlipperMood.dead : SlipperMood.hurt;
          _popups.add(_Popup(side: target, text: crit ? '$damage!' : '$damage', crit: crit));
          _log.insert(0, '$attackerName бьёт на $damage${crit ? ' (крит!)' : ''}');
        case DodgeEvent():
          _popups.add(_Popup(side: target, text: 'мимо', crit: false));
          _log.insert(0, '$attackerName промахивается');
      }
      if (_log.length > 6) _log.removeLast();
    });
    _lunge.forward(from: 0).then((_) => _lunge.reverse());

    // Убираем всплывашку и возвращаем спокойное лицо.
    Future.delayed(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      setState(() {
        if (_popups.isNotEmpty) _popups.removeAt(0);
        if (_mood[target] != SlipperMood.dead) _mood[target] = SlipperMood.idle;
        _mood[attacker] = _mood[attacker] == SlipperMood.dead ? SlipperMood.dead : SlipperMood.idle;
      });
    });
  }

  void _skip() {
    _timer?.cancel();
    final last = widget.result.events.whereType<HitEvent>();
    setState(() {
      for (final h in last) {
        if (h.attacker == Side.player) {
          _hpOpponent = h.targetHpAfter;
        } else {
          _hpPlayer = h.targetHpAfter;
        }
      }
      _index = widget.result.events.length;
      _popups.clear();
    });
    _finish();
  }

  void _finish() {
    if (_finished) return;
    final won = widget.result.playerWon;
    setState(() {
      _finished = true;
      _mood = {
        Side.player: won ? SlipperMood.happy : SlipperMood.dead,
        Side.opponent: won ? SlipperMood.dead : SlipperMood.happy,
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final won = widget.result.playerWon;
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
                  const StrokeText('Бой', size: 24),
                  const Spacer(),
                  if (!_finished)
                    GameButton(
                      onPressed: _skip,
                      color: GameColors.panelLight,
                      height: 36,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: const Text('Пропустить', style: TextStyle(color: GameColors.text, fontSize: 13)),
                    )
                  else
                    const SizedBox(width: 36),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  Expanded(
                    child: _HpBar(
                      name: widget.player.name,
                      hp: _hpPlayer,
                      max: widget.result.playerMaxHp,
                      color: GameColors.green,
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: StrokeText('VS', size: 22, color: GameColors.gold),
                  ),
                  Expanded(
                    child: _HpBar(
                      name: widget.opponent.name,
                      hp: _hpOpponent,
                      max: widget.result.opponentMaxHp,
                      color: GameColors.red,
                      alignEnd: true,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, c) {
                  final w = (c.maxWidth * 0.46).clamp(130.0, 250.0);
                  final rugW = c.maxWidth - 16;
                  return AnimatedBuilder(
                    animation: _lunge,
                    builder: (context, _) {
                      final t = Curves.easeOutBack.transform(_lunge.value);
                      final shift = 36 * t;
                      return Center(
                        child: SizedBox(
                        height: rugW * 0.26 + 90,
                        child: Stack(
                        alignment: Alignment.center,
                        clipBehavior: Clip.none,
                        children: [
                          Positioned(
                            bottom: 8,
                            child: Rug(width: rugW, aspect: 0.26),
                          ),
                          Positioned(
                            bottom: 22,
                            left: 10 + (_lunging == Side.player ? shift : 0),
                            child: _Fighter(
                              slipper: widget.player,
                              mood: _mood[Side.player]!,
                              width: w,
                              popups: _popups.where((p) => p.side == Side.player),
                            ),
                          ),
                          Positioned(
                            bottom: 22,
                            right: 10 + (_lunging == Side.opponent ? shift : 0),
                            child: _Fighter(
                              slipper: widget.opponent,
                              mood: _mood[Side.opponent]!,
                              width: w,
                              flip: true,
                              popups: _popups.where((p) => p.side == Side.opponent),
                            ),
                          ),
                        ],
                        ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            if (_finished)
              _ResultPanel(
                won: won,
                ratingDelta: widget.ratingDelta,
                threadsDelta: widget.threadsDelta,
              )
            else
              Container(
                height: 120,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                alignment: Alignment.topCenter,
                child: Column(
                  children: [
                    for (final line in _log)
                      Text(
                        line,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
        ),
      ),
    );
  }
}

class _Popup {
  const _Popup({required this.side, required this.text, required this.crit});
  final Side side;
  final String text;
  final bool crit;
}

class _Fighter extends StatelessWidget {
  const _Fighter({
    required this.slipper,
    required this.mood,
    required this.width,
    required this.popups,
    this.flip = false,
  });

  final Slipper slipper;
  final SlipperMood mood;
  final double width;
  final bool flip;
  final Iterable<_Popup> popups;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: width * 0.56,
      child: Stack(
        alignment: Alignment.bottomCenter,
        clipBehavior: Clip.none,
        children: [
          SlipperSprite(
            slipper: slipper,
            mood: mood,
            flip: flip,
            width: width,
          ),
          for (final p in popups)
            Positioned(
              top: -10,
              child: TweenAnimationBuilder<double>(
                key: ValueKey(p),
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeOut,
                builder: (_, t, child) => Opacity(
                  opacity: 1 - t * 0.8,
                  child: Transform.translate(
                    offset: Offset(0, -30 * t),
                    child: Transform.scale(scale: p.crit ? 1 + 0.4 * (1 - t) : 1, child: child),
                  ),
                ),
                child: StrokeText(
                  p.text,
                  size: p.crit ? 34 : 26,
                  color: p.crit ? GameColors.orange : (p.text == 'мимо' ? GameColors.textDim : GameColors.text),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _HpBar extends StatelessWidget {
  const _HpBar({
    required this.name,
    required this.hp,
    required this.max,
    required this.color,
    this.alignEnd = false,
  });

  final String name;
  final double hp;
  final double max;
  final Color color;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(name, style: theme.textTheme.titleSmall, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 4),
        GameBar(
          value: hp / max,
          color: color,
          height: 20,
          alignEnd: alignEnd,
          label: '${hp.ceil()} / ${max.round()}',
        ),
      ],
    );
  }
}

class _ResultPanel extends StatelessWidget {
  const _ResultPanel({
    required this.won,
    required this.ratingDelta,
    required this.threadsDelta,
  });

  final bool won;
  final int ratingDelta;
  final int threadsDelta;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = won ? GameColors.green : GameColors.red;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: GamePanel(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            StrokeText(won ? 'ПОБЕДА!' : 'ПОРАЖЕНИЕ', size: 32, color: color),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const ThreadIcon(size: 22),
                const SizedBox(width: 5),
                Text('+$threadsDelta', style: theme.textTheme.titleMedium),
                const SizedBox(width: 22),
                const Icon(Icons.emoji_events, color: GameColors.blue, size: 22),
                const SizedBox(width: 5),
                Text(
                  '${ratingDelta >= 0 ? '+' : ''}$ratingDelta',
                  style: theme.textTheme.titleMedium?.copyWith(color: color),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: GameButton(
                color: GameColors.gold,
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('На арену'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
