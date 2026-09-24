import 'dart:async';

import 'package:flutter/material.dart';

import '../../game/battle/battle_sim.dart';
import '../../game/battle/combatant.dart';
import '../../game/battle/skills.dart';
import '../attack_animation.dart';
import '../battle_effects.dart';
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

  /// Состояние скиллов сторон — приходит вместе с каждым событием боя.
  var _snapPlayer = const SideSnapshot(ult: 0, skillReady: 1);
  var _snapOpponent = const SideSnapshot(ult: 0, skillReady: 1);

  /// Баннер с названием только что применённого скилла.
  _Banner? _banner;

  /// Что сейчас показывается поверх каждого бойца.
  final _effects = {
    Side.player: <BattleEffect>{},
    Side.opponent: <BattleEffect>{},
  };

  /// Метки постановки мгновенного эффекта: снимаем его, только если сверху
  /// не легло новое такое же.
  final _effectStamp = <(Side, BattleEffect), int>{};
  int _stampCounter = 0;

  /// Разовый эффект — виден положенное ему время и гаснет.
  void _flashEffect(Side side, BattleEffect effect) {
    final stamp = ++_stampCounter;
    _effectStamp[(side, effect)] = stamp;
    _effects[side]!.add(effect);
    Future.delayed(effectDurations[effect]!, () {
      if (!mounted || _effectStamp[(side, effect)] != stamp) return;
      setState(() => _effects[side]!.remove(effect));
    });
  }

  /// Длящиеся эффекты держатся ровно столько, сколько действуют в бою:
  /// их состояние приходит в каждом событии, поэтому они не мигают между
  /// ходами противника.
  void _syncEffects(Side side, SideSnapshot snap) {
    final set = _effects[side]!;
    void toggle(BattleEffect effect, bool on) =>
        on ? set.add(effect) : set.remove(effect);
    toggle(BattleEffect.burn, snap.burning);
    toggle(BattleEffect.shield, snap.shielded);
    toggle(BattleEffect.stun, snap.stunned);
  }
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
      _snapPlayer = e.player;
      _snapOpponent = e.opponent;
      _syncEffects(Side.player, e.player);
      _syncEffects(Side.opponent, e.opponent);

      switch (e) {
        case SkillEvent(:final side, :final skill, :final ultimate):
          // Объявление скилла: баннер над бойцом и запись в лог.
          _banner = _Banner(side: side, text: skill.name, ultimate: ultimate);
          _mood = {side: SlipperMood.attack, side.other: _mood[side.other]!};
          _log.insert(0, '${nameOf(side)}: ${skill.name}${ultimate ? '!' : ''}');

        case HitEvent(
            :final attacker,
            :final damage,
            :final crit,
            :final targetHpAfter,
            :final thorns
          ):
          final target = attacker.other;
          if (target == Side.player) {
            _hpPlayer = targetHpAfter;
          } else {
            _hpOpponent = targetHpAfter;
          }
          _mood[target] = targetHpAfter <= 0 ? SlipperMood.dead : SlipperMood.hurt;
          if (thorns) {
            // Шипы — ответ брони, а не удар: замаха нет и поза не меняется.
            _popups.add(_Popup(side: target, text: '$damage', crit: false));
            _log.insert(0, '${nameOf(attacker)}: шипы на $damage');
          } else {
            _lunging = attacker;
            if (_mood[attacker] != SlipperMood.dead) {
              _mood[attacker] = SlipperMood.attack;
            }
            _popups.add(_Popup(side: target, text: crit ? '$damage!' : '$damage', crit: crit));
            _log.insert(0, '${nameOf(attacker)} бьёт на $damage${crit ? ' (крит!)' : ''}');
            _startLunge(attacker);
          }

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
          _flashEffect(side, BattleEffect.heal);
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
      for (final set in _effects.values) {
        set.clear();
      }
        for (final side in Side.values) {
          if (_mood[side] != SlipperMood.dead) _mood[side] = SlipperMood.idle;
        }
      });
    });
  }

  /// Пока открыто описание скилла, бой стоит — иначе дочитать не успеешь.
  void _pause() => _timer?.cancel();

  void _resume() {
    if (_finished || !mounted) return;
    _timer?.cancel();
    _timer = Timer(_stepDuration, _tick);
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
      for (final set in _effects.values) {
        set.clear();
      }
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
                      snapshot: _snapPlayer,
                      skills: widget.player.skills,
                      onDialog: _pause,
                      onDialogClosed: _resume,
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
                      snapshot: _snapOpponent,
                      skills: widget.opponent.skills,
                      onDialog: _pause,
                      onDialogClosed: _resume,
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
                              effects: _effects[Side.player]!,
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
                              effects: _effects[Side.opponent]!,
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

/// Квадратик скилла под шкалами: номер, затемнение по откату и описание по тапу.
class _SkillSlot extends StatelessWidget {
  const _SkillSlot({
    required this.index,
    required this.ready,
    required this.color,
    required this.onDialog,
    required this.onDialogClosed,
    this.cooldown = 0,
    this.skill,
    this.passive,
  });

  /// Порядковый номер: 1 — активный, 2 — пассивный, 3 — ульта.
  final int index;

  /// Готовность 0..1: 0 — только применён, 1 — готов.
  final double ready;

  final Color color;

  /// Откат активного скилла в ходах — показывается в описании.
  final int cooldown;

  final VoidCallback onDialog;
  final VoidCallback onDialogClosed;
  final ActiveSkill? skill;
  final PassiveSkill? passive;

  static const _size = 30.0;

  String get _name => skill?.name ?? passive!.name;
  String get _description => skill?.description ?? passive!.description;

  String get _kindLabel => switch (index) {
        1 => 'Скилл',
        2 => 'Пассивный',
        _ => 'Ульта',
      };

  /// Чем скилл ограничен: откат в ходах, шкала или ничего (у пассивки).
  String? get _recharge => switch (index) {
        1 => 'Перезарядка: ${_turns(cooldown)}',
        2 => null,
        _ => 'Заряжается от урона: нанесённого и полученного',
      };

  static String _turns(int n) {
    final tail = n % 100 >= 11 && n % 100 <= 14 ? 0 : n % 10;
    final word = switch (tail) { 1 => 'ход', 2 || 3 || 4 => 'хода', _ => 'ходов' };
    return '$n $word';
  }

  @override
  Widget build(BuildContext context) {
    final done = ready >= 1;
    return GestureDetector(
      onTap: () => _show(context),
      child: Container(
        width: _size,
        height: _size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: GameColors.outline, width: 2.5),
          // Готовый скилл светится своим цветом — так видно границу отката.
          color: Color.lerp(color, GameColors.panelDark, 0.35),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Пока картинок нет — просто номер скилла.
            Center(
              child: Text(
                '$index',
                style: const TextStyle(
                  color: GameColors.outline,
                  fontSize: 16,
                  fontVariations: [FontVariation('wght', 900)],
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            // Затемнение откатом: тёмная часть прижата к низу и уходит вниз
            // по мере готовности.
            if (!done)
              Align(
                alignment: Alignment.bottomCenter,
                child: FractionallySizedBox(
                  heightFactor: (1 - ready).clamp(0.0, 1.0),
                  widthFactor: 1,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: GameColors.panelDark.withValues(alpha: 0.88),
                      // Светлая кромка по краю затемнения — видно, куда оно ушло.
                      border: ready > 0
                          ? Border(
                              top: BorderSide(
                                color: Colors.white.withValues(alpha: 0.5),
                                width: 1.5,
                              ),
                            )
                          : null,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _show(BuildContext context) {
    final theme = Theme.of(context);
    onDialog();
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GameBadge(text: _kindLabel, color: color),
            const SizedBox(height: 8),
            StrokeText(_name, size: 20, color: color, align: TextAlign.start),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_description, style: theme.textTheme.bodyMedium),
            if (_recharge != null) ...[
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.timer_outlined, size: 16, color: GameColors.textDim),
                  const SizedBox(width: 6),
                  Expanded(child: Text(_recharge!, style: theme.textTheme.bodySmall)),
                ],
              ),
            ],
          ],
        ),
        actions: [
          GameButton(
            color: GameColors.panelLight,
            onPressed: () => Navigator.pop(context),
            child: const Text('Понятно', style: TextStyle(color: GameColors.text)),
          ),
        ],
      ),
    ).whenComplete(onDialogClosed);
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
    required this.effects,
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

  /// Что показать поверх бойца: оглушение, горение, щит, лечение.
  final Set<BattleEffect> effects;

  final Iterable<_Popup> popups;

  /// Где внутри бокса реально стоит тапок: спрайт 2:1 прижат к низу и
  /// уменьшен на sizeFactor, а в самом PNG остаются поля по краям.
  Rect _bodyRect(Size box) {
    final scale = fighter.sizeFactor;
    final spriteW = width * scale;
    final spriteH = width / SlipperSprite.aspect * scale;
    final left = (box.width - spriteW) / 2;
    final top = box.height - spriteH;
    // Поля нормализованного PNG: по 4% с боков и 8% снизу.
    return Rect.fromLTRB(
      left + spriteW * 0.04,
      top + spriteH * 0.06,
      left + spriteW * 0.96,
      top + spriteH * 0.94,
    );
  }

  @override
  Widget build(BuildContext context) {
    final box = Size(width, width * 0.56);
    return SizedBox.fromSize(
      size: box,
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
          // Эффекты живут поверх спрайта, но под цифрами урона.
          Positioned.fill(
            child: BattleEffectsLayer(
              effects: effects,
              size: box,
              body: _bodyRect(box),
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
    required this.snapshot,
    required this.skills,
    required this.onDialog,
    required this.onDialogClosed,
    this.alignEnd = false,
  });

  final String name;
  final double hp;
  final double max;
  final Color color;

  /// Заряды ульты и откат активного скилла.
  final SideSnapshot snapshot;

  final SkillSet skills;

  /// Бой ставится на паузу, пока открыто описание скилла.
  final VoidCallback onDialog;
  final VoidCallback onDialogClosed;

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
          value: snapshot.ult,
          color: snapshot.ult >= 1 ? GameColors.gold : GameColors.blue,
          height: 8,
          alignEnd: alignEnd,
        ),
        if (!skills.isEmpty) ...[
          const SizedBox(height: 5),
          Row(
            mainAxisAlignment:
                alignEnd ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              _SkillSlot(
                index: 1,
                skill: skills.active,
                ready: snapshot.skillReady,
                color: GameColors.blue,
                cooldown: skills.activeCooldown,
                onDialog: onDialog,
                onDialogClosed: onDialogClosed,
              ),
              const SizedBox(width: 5),
              _SkillSlot(
                index: 2,
                passive: skills.passive,
                ready: 1,
                color: GameColors.green,
                onDialog: onDialog,
                onDialogClosed: onDialogClosed,
              ),
              const SizedBox(width: 5),
              _SkillSlot(
                index: 3,
                skill: skills.ultimate,
                ready: snapshot.ult,
                color: GameColors.gold,
                onDialog: onDialog,
                onDialogClosed: onDialogClosed,
              ),
            ],
          ),
        ],
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
