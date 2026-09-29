import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../game/battle/battle_sim.dart';
import '../../game/battle/combatant.dart';
import '../../game/battle/skills.dart';
import '../../game/gems.dart';
import '../../game/slipper.dart';
import '../../game/slipper_kind.dart';
import '../attack_animation.dart';
import '../format.dart';
import '../gem_icon.dart';
import '../battle_effects.dart';
import '../status_icons.dart';
import '../skill_vfx.dart';
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
    this.ratingDelta,
    this.threadsDelta = 0,
    this.coinsDelta = 0,
    this.rewardKind,
    this.rewardGem,
    this.exitLabel = 'На арену',
    this.intro,
  });

  final Combatant player;
  final Combatant opponent;
  final BattleResult result;

  /// Изменение рейтинга; null — бой без рейтинга (сюжет).
  final int? ratingDelta;
  final int threadsDelta;
  final int coinsDelta;

  /// Тапок, выпавший за победу.
  final SlipperKind? rewardKind;

  /// Гем, выпавший за победу.
  final Gem? rewardGem;

  /// Подпись кнопки выхода после боя.
  final String exitLabel;

  /// Представление бойцов перед боем; null — бой начинается сразу.
  final BattleIntro? intro;

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

  /// Метка последнего запланированного сброса позы.
  int _moodCounter = 0;
  int _moodStamp = 0;

  /// Сколько раз по бойцу попали: по смене числа спрайт заново проигрывает
  /// вспышку урона, даже если поза осталась прежней.
  final _hits = {Side.player: 0, Side.opponent: 0};

  /// Последний урон пришёл от шипов — тогда боец только краснеет, без тряски.
  final _soft = {Side.player: false, Side.opponent: false};


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
  /// Вспышки поверх бойцов: блики ударов и эффекты скиллов.
  final _vfx = <_Vfx>[];
  int _vfxCounter = 0;

  /// Скилл, который сейчас применяется: его удары получают эффекты.
  _Cast? _cast;

  /// Вспышка всего экрана в момент удара ультой.
  int _screenFlash = 0;

  void _spawn(Side side, VfxKind kind) {
    final v = _Vfx(side: side, kind: kind, id: ++_vfxCounter);
    _vfx.add(v);
    Future.delayed(kind.duration, () {
      if (mounted) setState(() => _vfx.remove(v));
    });
  }

  /// Выполнить [apply] в момент касания удара [attacker] — не раньше и не
  /// позже: тогда урон, реакция цели и вспышки совпадают с анимацией.
  void _atImpact(Side attacker, VoidCallback apply) {
    final style = (attacker == Side.player ? widget.player : widget.opponent).attackStyle;
    Future.delayed(AttackAnimation.impactDelay(style), () {
      if (!mounted || _finished) return;
      setState(apply);
    });
  }

  /// Удар дошёл до цели: блик, крит, эффекты скилла.
  void _impactVfx(Side attacker, {required bool crit}) {
    final target = attacker.other;
    _spawn(target, crit ? VfxKind.crit : VfxKind.hit);
    final cast = _cast;
    if (cast == null || cast.side != attacker) return;
    if (cast.ultimate) {
      _spawn(target, VfxKind.ultBurst);
      _screenFlash++;
    } else {
      _spawn(target, VfxKind.skillRing);
    }
    // Эффекты скилла — на первом ударе серии, чтобы не рябило.
    if (!cast.effectsShown) {
      cast.effectsShown = true;
      for (final k in hitVfxOf(cast.skill)) {
        _spawn(target, k);
      }
    }
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

  /// Спрайт при атаке оборачивается в анимацию, в покое — нет. С постоянным
  /// ключом он переносится между обёртками, а не создаётся заново — иначе
  /// аура и дыхание каждый раз начинались бы сначала.
  final _spriteKeys = {Side.player: GlobalKey(), Side.opponent: GlobalKey()};

  @override
  void initState() {
    super.initState();
    if (widget.intro != null) {
      _introShown = true;
      _introTimer = Timer(_introDuration, _endIntro);
      return;
    }
    // Небольшая пауза перед первым ударом — игрок успевает увидеть соперника.
    _timer = Timer(const Duration(milliseconds: 900), _tick);
  }

  static const _introDuration = Duration(milliseconds: 2200);

  /// Заставка «я VS соперник» на экране; гаснет, потом начинается бой.
  bool _introShown = false;
  bool _introFading = false;
  Timer? _introTimer;

  void _endIntro() {
    if (!_introShown || _introFading || !mounted) return;
    _introTimer?.cancel();
    setState(() => _introFading = true);
    _introTimer = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() => _introShown = false);
      _timer = Timer(const Duration(milliseconds: 500), _tick);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _introTimer?.cancel();
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
          _cast = _Cast(side: side, skill: skill, ultimate: ultimate);
          // Что скилл делает с самим бойцом — видно сразу, при применении.
          for (final k in castVfxOf(skill)) {
            _spawn(side, k);
          }
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
          void land() {
            if (target == Side.player) {
              _hpPlayer = targetHpAfter;
            } else {
              _hpOpponent = targetHpAfter;
            }
            _mood[target] = targetHpAfter <= 0 ? SlipperMood.dead : SlipperMood.hurt;
            _hits[target] = _hits[target]! + 1;
            _soft[target] = thorns;
          }

          if (thorns) {
            // Ответ брони — без замаха, поэтому сразу.
            land();
            // Шипы — ответ брони, а не удар: замаха нет и поза не меняется.
            _popups.add(_Popup(side: target, text: '$damage', crit: false));
            _log.insert(0, '${nameOf(attacker)}: шипы на $damage');
          } else {
            // Удар другой стороны — прежний скилл закончился.
            if (_cast?.side != attacker) _cast = null;
            _lunging = attacker;
            if (_mood[attacker] != SlipperMood.dead) {
              _mood[attacker] = SlipperMood.attack;
            }
            _log.insert(0, '${nameOf(attacker)} бьёт на $damage${crit ? ' (крит!)' : ''}');
            _startLunge(attacker);
            // Урон, цифра и вспышки — в момент касания.
            _atImpact(attacker, () {
              land();
              _popups.add(_Popup(side: target, text: crit ? '$damage!' : '$damage', crit: crit));
              _impactVfx(attacker, crit: crit);
            });
          }

        case DodgeEvent(:final attacker):
          final target = attacker.other;
          if (_cast?.side != attacker) _cast = null;
          _lunging = attacker;
          _mood = {attacker: SlipperMood.attack, target: SlipperMood.idle};
          _log.insert(0, '${nameOf(attacker)} промахивается');
          _startLunge(attacker);
          _atImpact(attacker, () => _popups.add(_Popup(side: target, text: 'мимо', crit: false)));

        case HealEvent(:final side, :final amount, :final hpAfter):
          if (side == Side.player) {
            _hpPlayer = hpAfter;
          } else {
            _hpOpponent = hpAfter;
          }
          _popups.add(_Popup(side: side, text: '+$amount', crit: false, heal: true));
          _flashEffect(side, BattleEffect.heal);
          _log.insert(0, '${nameOf(side)} восстанавливает $amount');

        case BurnEvent(:final side, :final damage, :final hpAfter, :final poison):
          if (side == Side.player) {
            _hpPlayer = hpAfter;
          } else {
            _hpOpponent = hpAfter;
          }
          _mood = {side: hpAfter <= 0 ? SlipperMood.dead : SlipperMood.hurt, side.other: SlipperMood.idle};
          _hits[side] = _hits[side]! + 1;
          _soft[side] = false;
          _popups.add(_Popup(side: side, text: '$damage', crit: false, burn: true));
          _log.insert(0, '${nameOf(side)} ${poison ? 'отравлен' : 'горит'}: $damage');
          _cast = null;

        case StunEvent(:final side):
          _cast = null;
          _popups.add(_Popup(side: side, text: 'оглушён', crit: false));
          _log.insert(0, '${nameOf(side)} пропускает ход');
      }
      if (_log.length > 4) _log.removeLast();
    });

    // Возвращаем спокойное состояние — но только если сверху не легло
    // новое событие: иначе старый таймер гасил свежую реакцию на удар.
    final stamp = ++_moodCounter;
    _moodStamp = stamp;
    final attacker = switch (e) {
      HitEvent(:final attacker, :final thorns) when !thorns => attacker,
      DodgeEvent(:final attacker) => attacker,
      _ => null,
    };
    final impact = attacker == null
        ? 0
        : AttackAnimation.impactDelay(
            (attacker == Side.player ? widget.player : widget.opponent).attackStyle,
          ).inMilliseconds;
    Future.delayed(Duration(milliseconds: max(600, impact + 380)), () {
      if (!mounted || _moodStamp != stamp) return;
      setState(() {
        if (_popups.isNotEmpty) _popups.removeAt(0);
        _banner = null;
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
  ///
  /// Весь цикл обязан уложиться в шаг боя: иначе следующий удар начинался,
  /// пока боец ещё возвращался, анимация сбрасывалась в ноль и он рывком
  /// прыгал на место.
  void _startLunge(Side attacker) {
    final style = (attacker == Side.player ? widget.player : widget.opponent).attackStyle;
    final forward = AttackAnimation.duration(style);
    _lunge.duration = forward;
    if (AttackAnimation.returnsOnItsOwn(style)) {
      // Стиль сам приводит бойца на место — после прохода просто обнуляем.
      _lunge.forward(from: 0).then((_) => _lunge.value = 0);
      return;
    }
    // Возврат укорачивается, если вместе с замахом не влезает в шаг.
    final room = _stepDuration - forward - const Duration(milliseconds: 40);
    _lunge.reverseDuration = room < forward
        ? (room < const Duration(milliseconds: 120) ? const Duration(milliseconds: 120) : room)
        : forward;
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
      body: Stack(
        children: [
          ArtBackground(
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
                      ultUnlocked: widget.player.skills.hasUltimate,
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
                      ultUnlocked: widget.opponent.skills.hasUltimate,
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
                              spriteKey: _spriteKeys[Side.player]!,
                              fighter: widget.player,
                              mood: _mood[Side.player]!,
                              width: w,
                              reach: reach,
                              attack: _lunging == Side.player ? _lunge.value : 0,
                              dark: !_finished && _snapPlayer.transformed,
                              effects: _effects[Side.player]!,
                              hits: _hits[Side.player]!,
                              softHit: _soft[Side.player]!,
                              popups: _popups.where((p) => p.side == Side.player),
                              vfx: _vfx.where((v) => v.side == Side.player),
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 6,
                            child: _Fighter(
                              spriteKey: _spriteKeys[Side.opponent]!,
                              fighter: widget.opponent,
                              mood: _mood[Side.opponent]!,
                              width: w,
                              flip: true,
                              reach: reach,
                              attack: _lunging == Side.opponent ? _lunge.value : 0,
                              dark: !_finished && _snapOpponent.transformed,
                              effects: _effects[Side.opponent]!,
                              hits: _hits[Side.opponent]!,
                              softHit: _soft[Side.opponent]!,
                              popups: _popups.where((p) => p.side == Side.opponent),
                              vfx: _vfx.where((v) => v.side == Side.opponent),
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
            // Скиллы — под своими тапками: игрока слева, соперника справа.
            // В конце боя прячем, чтобы итог помещался на узком экране.
            if (!_finished)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                child: Row(
                  children: [
                    _SkillRow(
                      skills: widget.player.skills,
                      snapshot: _snapPlayer,
                      onDialog: _pause,
                      onDialogClosed: _resume,
                    ),
                    const Spacer(),
                    _SkillRow(
                      skills: widget.opponent.skills,
                      snapshot: _snapOpponent,
                      onDialog: _pause,
                      onDialogClosed: _resume,
                    ),
                  ],
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
                coinsDelta: widget.coinsDelta,
                rewardKind: widget.rewardKind,
                rewardGem: widget.rewardGem,
                exitLabel: widget.exitLabel,
              )
            else
              Container(
                height: 84,
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
          // Удар ультой — короткая белая вспышка на весь экран.
          if (_screenFlash > 0)
            Positioned.fill(
              child: IgnorePointer(
                child: TweenAnimationBuilder<double>(
                  key: ValueKey(_screenFlash),
                  tween: Tween(begin: 1, end: 0),
                  duration: const Duration(milliseconds: 260),
                  builder: (_, t, _) =>
                      ColoredBox(color: Colors.white.withValues(alpha: 0.35 * t)),
                ),
              ),
            ),
          if (_introShown)
            Positioned.fill(
              child: AnimatedOpacity(
                opacity: _introFading ? 0 : 1,
                duration: const Duration(milliseconds: 300),
                child: GestureDetector(
                  // Тап по заставке — сразу к бою.
                  onTap: _endIntro,
                  child: _IntroOverlay(
                    player: widget.player,
                    opponent: widget.opponent,
                    intro: widget.intro!,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Очки бойцов для заставки перед боем.
class BattleIntro {
  const BattleIntro({required this.playerRating, required this.opponentRating});
  final int playerRating;
  final int opponentRating;
}

/// Заставка перед боем: бойцы выезжают с краёв, между ними — «VS».
class _IntroOverlay extends StatelessWidget {
  const _IntroOverlay({
    required this.player,
    required this.opponent,
    required this.intro,
  });

  final Combatant player;
  final Combatant opponent;
  final BattleIntro intro;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xF214091F),
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, c) {
            final cardW = (c.maxWidth - 40) / 2;
            Widget card(Combatant f, int rating, {required bool right}) =>
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 550),
                  curve: Curves.easeOutBack,
                  builder: (_, t, child) => Transform.translate(
                    offset: Offset((right ? 1 : -1) * c.maxWidth * 0.6 * (1 - t), 0),
                    child: child,
                  ),
                  child: SizedBox(
                    width: cardW,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          height: cardW * 0.62,
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: SlipperSprite(
                              fighter: f,
                              width: cardW,
                              flip: right,
                              showSize: false,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        StrokeText(
                          f.name,
                          size: 18,
                          color: right ? GameColors.red : GameColors.green,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.emoji_events, color: GameColors.blue, size: 18),
                            const SizedBox(width: 3),
                            StrokeText('$rating', size: 18),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    card(player, intro.playerRating, right: false),
                    const SizedBox(width: 40),
                    card(opponent, intro.opponentRating, right: true),
                  ],
                ),
                const SizedBox(height: 28),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 700),
                  curve: const Interval(0.45, 1, curve: Curves.elasticOut),
                  builder: (_, t, child) => Opacity(
                    opacity: t.clamp(0.0, 1.0),
                    child: Transform.scale(scale: 0.4 + 0.6 * t, child: child),
                  ),
                  child: const StrokeText('VS', size: 72, color: GameColors.gold),
                ),
                const SizedBox(height: 18),
                Text(
                  'Нажми, чтобы начать',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            );
          },
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
    this.locked = false,
  });

  /// Скилл ещё не открыт звёздами — замок вместо номера.
  final bool locked;

  int get _unlockStar => switch (index) {
        1 => SkillSet.activeStar,
        2 => SkillSet.passiveStar,
        _ => SkillSet.ultimateStar,
      };

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

  static const _size = 38.0;

  String get _name => locked ? 'Закрыт' : (skill?.name ?? passive!.name);
  String get _description => locked
      ? 'Откроется, когда у тапка будет ★$_unlockStar.'
      : (skill?.description ?? passive!.description);

  String get _kindLabel => switch (index) {
        1 => 'Скилл',
        2 => 'Пассивный',
        _ => 'Ульта',
      };

  /// Чем скилл ограничен: откат в ходах, шкала или ничего (у пассивки).
  String? get _recharge => switch (index) {
        1 => 'Перезарядка: ${fmtTurns(cooldown)}',
        2 => null,
        _ => 'Заряжается от урона: нанесённого и полученного',
      };



  @override
  Widget build(BuildContext context) {
    if (locked) {
      return GestureDetector(
        onTap: () => _show(context),
        child: Container(
          width: _size,
          height: _size,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(7),
            border: Border.all(color: GameColors.outline, width: 2.5),
            color: GameColors.panelDark,
          ),
          child: const Icon(Icons.lock_rounded, size: 18, color: GameColors.textDim),
        ),
      );
    }
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
            if (_recharge != null && !locked) ...[
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
    required this.spriteKey,
    required this.fighter,
    required this.mood,
    required this.width,
    required this.popups,
    required this.reach,
    required this.attack,
    required this.effects,
    required this.hits,
    required this.softHit,
    this.vfx = const [],
    this.flip = false,
    this.dark = false,
  });

  final GlobalKey spriteKey;
  final Combatant fighter;
  final SlipperMood mood;
  final double width;
  final bool flip;

  /// На сколько пикселей тапок подаётся к противнику в пике удара.
  final double reach;

  /// 0 — стоит, 1 — пик замаха.
  final double attack;

  /// Тёмная форма — спрайт рисуется негативом.
  final bool dark;

  /// Что показать поверх бойца: оглушение, горение, щит, лечение.
  final Set<BattleEffect> effects;

  /// Счётчик попаданий — спрайт по нему перезапускает вспышку урона.
  final int hits;

  /// Последний урон был от шипов: краснеем, но не трясёмся.
  final bool softHit;

  final Iterable<_Popup> popups;

  /// Вспышки ударов и скиллов над этим бойцом.
  final Iterable<_Vfx> vfx;

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
              key: spriteKey,
              fighter: fighter,
              mood: mood,
              flip: flip,
              width: width,
              impulse: hits,
              shake: !softHit,
              negative: dark,
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
          for (final v in vfx)
            Positioned.fill(
              child: IgnorePointer(
                child: TweenAnimationBuilder<double>(
                  key: ValueKey(v.id),
                  tween: Tween(begin: 0, end: 1),
                  duration: v.kind.duration,
                  builder: (_, t, _) => CustomPaint(
                    painter: VfxPainter(
                      kind: v.kind,
                      t: t,
                      body: _bodyRect(box),
                      // Удар по бойцу летит от соперника.
                      dir: flip ? -1 : 1,
                    ),
                  ),
                ),
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
    required this.onDialog,
    required this.onDialogClosed,
    this.alignEnd = false,
    this.ultUnlocked = true,
  });

  /// Ульта открыта — иначе её шкалы нет (место остаётся, чтобы вёрстка
  /// у бойцов совпадала).
  final bool ultUnlocked;

  final String name;
  final double hp;
  final double max;
  final Color color;

  /// Заряд ульты и эффекты, висящие на бойце.
  final SideSnapshot snapshot;

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
        if (ultUnlocked)
          GameBar(
            value: snapshot.ult,
            color: snapshot.ult >= 1 ? GameColors.gold : GameColors.blue,
            height: 8,
            alignEnd: alignEnd,
          )
        else
          const SizedBox(height: 8),
        const SizedBox(height: 5),
        // Что висит на бойце. Высота фиксирована, чтобы при появлении
        // и снятии эффектов вёрстка не прыгала.
        SizedBox(
          height: 24,
          child: Wrap(
            spacing: 9,
            alignment: alignEnd ? WrapAlignment.end : WrapAlignment.start,
            children: [
              for (final status in statusesOf(snapshot))
                StatusIcon(
                  kind: status.kind,
                  turns: status.turns,
                  size: 24,
                  onDialog: onDialog,
                  onDialogClosed: onDialogClosed,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Три слота скиллов бойца: активный, пассивный, ульта.
class _SkillRow extends StatelessWidget {
  const _SkillRow({
    required this.skills,
    required this.snapshot,
    required this.onDialog,
    required this.onDialogClosed,
  });

  final SkillSet skills;
  final SideSnapshot snapshot;
  final VoidCallback onDialog;
  final VoidCallback onDialogClosed;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _SkillSlot(
          index: 1,
          skill: skills.active,
          locked: !skills.hasActive,
          ready: snapshot.skillReady,
          color: GameColors.blue,
          cooldown: skills.activeCooldown,
          onDialog: onDialog,
          onDialogClosed: onDialogClosed,
        ),
        const SizedBox(width: 6),
        _SkillSlot(
          index: 2,
          passive: skills.passive,
          locked: !skills.hasPassive,
          ready: 1,
          color: GameColors.green,
          onDialog: onDialog,
          onDialogClosed: onDialogClosed,
        ),
        const SizedBox(width: 6),
        _SkillSlot(
          index: 3,
          skill: skills.ultimate,
          locked: !skills.hasUltimate,
          ready: snapshot.ult,
          color: GameColors.gold,
          onDialog: onDialog,
          onDialogClosed: onDialogClosed,
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
    required this.coinsDelta,
    required this.rewardKind,
    required this.rewardGem,
    required this.exitLabel,
  });

  final Gem? rewardGem;
  final bool won;
  final int? ratingDelta;
  final int threadsDelta;
  final int coinsDelta;
  final SlipperKind? rewardKind;
  final String exitLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = won ? GameColors.green : GameColors.red;
    final rating = ratingDelta;
    final kind = rewardKind;
    final items = <Widget>[
      if (threadsDelta != 0)
        _RewardItem(icon: const ThreadIcon(size: 22), text: '+$threadsDelta'),
      if (coinsDelta != 0)
        _RewardItem(icon: const CoinIcon(size: 22), text: '+$coinsDelta'),
      if (rating != null && rating != 0)
        _RewardItem(
          icon: const Icon(Icons.emoji_events, color: GameColors.blue, size: 22),
          text: '${rating >= 0 ? '+' : ''}$rating',
          color: color,
        ),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: GamePanel(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            StrokeText(won ? 'ПОБЕДА!' : 'ПОРАЖЕНИЕ', size: 32, color: color),
            const SizedBox(height: 10),
            if (rewardGem != null) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GemIcon(gem: rewardGem!, size: 48),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(gemTitle(rewardGem!), style: theme.textTheme.titleSmall),
                        Text(rewardGem!.bonusText, style: theme.textTheme.bodySmall),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            if (items.isNotEmpty)
              Wrap(spacing: 22, alignment: WrapAlignment.center, children: items)
            else if (!won)
              Text(
                'Прокачай тапок и попробуй снова',
                style: theme.textTheme.bodySmall,
              ),
            if (kind != null) ...[
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SlipperSprite(
                    fighter: Slipper(name: kind.name, kindId: kind.id),
                    width: 84,
                    animate: false,
                    showSize: false,
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Новый тапок!', style: theme.textTheme.bodySmall),
                        Text(kind.name, style: theme.textTheme.titleMedium),
                        GameBadge(text: kind.rarity.label, color: kind.rarity.color),
                      ],
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: GameButton(
                color: GameColors.gold,
                onPressed: () => Navigator.of(context).pop(),
                child: Text(exitLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RewardItem extends StatelessWidget {
  const _RewardItem({required this.icon, required this.text, this.color});

  final Widget icon;
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        icon,
        const SizedBox(width: 5),
        Text(
          text,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(color: color),
        ),
      ],
    );
  }
}

/// Вспышка над бойцом.
class _Vfx {
  _Vfx({required this.side, required this.kind, required this.id});
  final Side side;
  final VfxKind kind;
  final int id;
}

/// Применяемый скилл: чей, какой и показаны ли уже его эффекты.
class _Cast {
  _Cast({required this.side, required this.skill, required this.ultimate});
  final Side side;
  final ActiveSkill skill;
  final bool ultimate;
  bool effectsShown = false;
}
