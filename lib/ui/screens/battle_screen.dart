import 'dart:async';

import 'package:flutter/material.dart';

import '../../game/battle/battle_sim.dart';
import '../../game/battle/combatant.dart';
import '../attack_animation.dart';
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

  final Combatant player;
  final Combatant opponent;
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

  /// Заряд ульт, 0..1 — приходит вместе с каждым событием боя.
  double _ultPlayer = 0;
  double _ultOpponent = 0;

  /// Баннер с названием только что применённого скилла.
  _Banner? _banner;
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
    final playerName = widget.player.name;
    final opponentName = widget.opponent.name;
    String nameOf(Side s) => s == Side.player ? playerName : opponentName;

    setState(() {
      _ultPlayer = e.ultPlayer;
      _ultOpponent = e.ultOpponent;

      switch (e) {
        case SkillEvent(:final side, :final name, :final ultimate):
          // Объявление скилла: баннер над бойцом и запись в лог.
          _banner = _Banner(side: side, text: name, ultimate: ultimate);
          _mood = {side: SlipperMood.attack, side.other: _mood[side.other]!};
          _log.insert(0, '${nameOf(side)}: $name${ultimate ? '!' : ''}');

        case HitEvent(:final attacker, :final damage, :final crit, :final targetHpAfter):
          final target = attacker.other;
          _lunging = attacker;
          _mood = {attacker: SlipperMood.attack, target: SlipperMood.idle};
          if (target == Side.player) {
            _hpPlayer = targetHpAfter;
          } else {
            _hpOpponent = targetHpAfter;
          }
          _mood[target] = targetHpAfter <= 0 ? SlipperMood.dead : SlipperMood.hurt;
          _popups.add(_Popup(side: target, text: crit ? '$damage!' : '$damage', crit: crit));
          _log.insert(0, '${nameOf(attacker)} бьёт на $damage${crit ? ' (крит!)' : ''}');
          _startLunge(attacker);

        case DodgeEvent(:final attacker):
          final target = attacker.other;
          _lunging = attacker;
          _mood = {attacker: SlipperMood.attack, target: SlipperMood.idle};
          _popups.add(_Popup(side: target, text: 'мимо', crit: false));
          _log.insert(0, '${nameOf(attacker)} промахивается');
          _startLunge(attacker);

        case HealEvent(:final side, :final amount, :final hpAfter):
          if (side == Side.player) {
            _hpPlayer = hpAfter;
          } else {
            _hpOpponent = hpAfter;
          }
          _popups.add(_Popup(side: side, text: '+$amount', crit: false, heal: true));
          _log.insert(0, '${nameOf(side)} восстанавливает $amount');

        case BurnEvent(:final side, :final damage, :final hpAfter):
          if (side == Side.player) {
            _hpPlayer = hpAfter;
          } else {
            _hpOpponent = hpAfter;
          }
          _mood = {side: hpAfter <= 0 ? SlipperMood.dead : SlipperMood.hurt, side.other: SlipperMood.idle};
          _popups.add(_Popup(side: side, text: '$damage', crit: false, burn: true));
          _log.insert(0, '${nameOf(side)} горит: $damage');

        case StunEvent(:final side):
          _popups.add(_Popup(side: side, text: 'оглушён', crit: false));
          _log.insert(0, '${nameOf(side)} пропускает ход');
      }
      if (_log.length > 6) _log.removeLast();
    });

    // Убираем всплывашку и возвращаем спокойное состояние.
    Future.delayed(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      setState(() {
        if (_popups.isNotEmpty) _popups.removeAt(0);
        _banner = null;
        for (final side in Side.values) {
          if (_mood[side] != SlipperMood.dead) _mood[side] = SlipperMood.idle;
        }
      });
    });
  }

  /// Запускает анимацию удара в манере атакующего.
  void _startLunge(Side attacker) {
    final who = attacker == Side.player ? widget.player : widget.opponent;
    _lunge.duration = AttackAnimation.duration(who.attackStyle);
    _lunge.forward(from: 0).then((_) => _lunge.reverse());
  }

  void _skip() {
    _timer?.cancel();
    setState(() {
      // Прокручиваем запись до конца: берём последнее состояние HP каждой стороны.
      for (final e in widget.result.events) {
        switch (e) {
          case HitEvent(:final attacker, :final targetHpAfter):
            if (attacker == Side.player) {
              _hpOpponent = targetHpAfter;
            } else {
              _hpPlayer = targetHpAfter;
            }
          case HealEvent(:final side, :final hpAfter):
          case BurnEvent(:final side, :final hpAfter):
            if (side == Side.player) {
              _hpPlayer = hpAfter;
            } else {
              _hpOpponent = hpAfter;
            }
          case SkillEvent():
          case DodgeEvent():
          case StunEvent():
            break;
        }
      }
      _banner = null;
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
      body: ArtBackground(
        asset: 'assets/ui/room_bg.jpg',
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
                      ult: _ultPlayer,
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
                      ult: _ultOpponent,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, c) {
                  final w = (c.maxWidth * 0.5).clamp(130.0, 270.0);
                  return AnimatedBuilder(
                    animation: _lunge,
                    builder: (context, _) {
                      // Бойцы стоят в круге на полу арены — он ниже центра экрана.
                      final reach = w * 0.3;
                      return Align(
                        alignment: const Alignment(0, 0.5),
                        child: SizedBox(
                        height: w * 0.62,
                        child: Stack(
                        alignment: Alignment.center,
                        clipBehavior: Clip.none,
                        children: [
                          Positioned(
                            bottom: 0,
                            left: 6,
                            child: _Fighter(
                              fighter: widget.player,
                              mood: _mood[Side.player]!,
                              width: w,
                              reach: reach,
                              attack: _lunging == Side.player ? _lunge.value : 0,
                              popups: _popups.where((p) => p.side == Side.player),
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 6,
                            child: _Fighter(
                              fighter: widget.opponent,
                              mood: _mood[Side.opponent]!,
                              width: w,
                              flip: true,
                              reach: reach,
                              attack: _lunging == Side.opponent ? _lunge.value : 0,
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
            // Название сработавшего скилла — поверх сцены, под барами.
            SizedBox(
              height: 46,
              child: Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: _banner == null
                      ? const SizedBox.shrink()
                      : _SkillBanner(key: ValueKey(_banner), banner: _banner!),
                ),
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
  const _Popup({
    required this.side,
    required this.text,
    required this.crit,
    this.heal = false,
    this.burn = false,
  });

  final Side side;
  final String text;
  final bool crit;
  final bool heal;
  final bool burn;

  Color get color {
    if (heal) return GameColors.green;
    if (burn) return GameColors.orange;
    if (crit) return GameColors.gold;
    return text == 'мимо' || text == 'оглушён' ? GameColors.textDim : GameColors.text;
  }
}

/// Виджет плашки скилла: у ульты — золотая, у обычного — синяя.
class _SkillBanner extends StatelessWidget {
  const _SkillBanner({super.key, required this.banner});
  final _Banner banner;

  @override
  Widget build(BuildContext context) {
    final color = banner.ultimate ? GameColors.gold : GameColors.blue;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: GameColors.outline, width: 2.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            banner.ultimate ? Icons.auto_awesome : Icons.bolt,
            size: 18,
            color: GameColors.outline,
          ),
          const SizedBox(width: 6),
          Text(
            banner.text,
            style: const TextStyle(
              color: GameColors.outline,
              fontSize: 15,
              fontVariations: [FontVariation('wght', 900)],
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

/// Плашка с названием сработавшего скилла.
class _Banner {
  const _Banner({required this.side, required this.text, required this.ultimate});
  final Side side;
  final String text;
  final bool ultimate;
}

class _Fighter extends StatelessWidget {
  const _Fighter({
    required this.fighter,
    required this.mood,
    required this.width,
    required this.popups,
    required this.reach,
    required this.attack,
    this.flip = false,
  });

  final Combatant fighter;
  final SlipperMood mood;
  final double width;
  final bool flip;

  /// На сколько пикселей тапок подаётся к противнику в пике удара.
  final double reach;

  /// 0 — стоит, 1 — пик замаха.
  final double attack;

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
          AttackAnimation.apply(
            style: fighter.attackStyle,
            progress: attack,
            flip: flip,
            reach: reach,
            child: SlipperSprite(
              fighter: fighter,
              mood: mood,
              flip: flip,
              width: width,
            ),
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
                  color: p.color,
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
    required this.ult,
    this.alignEnd = false,
  });

  final String name;
  final double hp;
  final double max;
  final Color color;

  /// Заряд ульты, 0..1.
  final double ult;

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
        const SizedBox(height: 3),
        // Тонкая шкала ульты под здоровьем: залилась — сработает.
        GameBar(
          value: ult,
          color: ult >= 1 ? GameColors.gold : GameColors.blue,
          height: 8,
          alignEnd: alignEnd,
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
