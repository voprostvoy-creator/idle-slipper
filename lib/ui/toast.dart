import 'dart:async';

import 'package:flutter/material.dart';

import 'theme.dart';
import 'widgets/game_widgets.dart';

/// Вид уведомления: цвет полоски и значок.
enum ToastKind {
  info(GameColors.blue, Icons.info_rounded),
  good(GameColors.green, Icons.check_circle_rounded),
  reward(GameColors.gold, Icons.auto_awesome_rounded),
  warn(GameColors.red, Icons.error_rounded);

  const ToastKind(this.color, this.icon);
  final Color color;
  final IconData icon;
}

/// Уведомление в стиле игры: выезжает сверху, стоит пару секунд и уезжает.
/// Несколько подряд выстраиваются очередью друг под другом.
void showToast(BuildContext context, String text, {ToastKind kind = ToastKind.info, Widget? icon}) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;
  _ToastHost.of(overlay).add(_ToastData(text: text, kind: kind, icon: icon));
}

class _ToastData {
  _ToastData({required this.text, required this.kind, this.icon});
  final String text;
  final ToastKind kind;
  final Widget? icon;
  final key = UniqueKey();
  bool leaving = false;
}

/// Один слой поверх экрана на весь оверлей; держит очередь уведомлений.
class _ToastHost {
  _ToastHost._(this.overlay);

  static final _hosts = Expando<_ToastHost>();

  static _ToastHost of(OverlayState overlay) => _hosts[overlay] ??= _ToastHost._(overlay);

  final OverlayState overlay;
  final _items = <_ToastData>[];
  OverlayEntry? _entry;

  /// На экране не больше стольких — старые уходят раньше.
  static const _max = 4;
  static const _life = Duration(milliseconds: 2400);
  static const _leave = Duration(milliseconds: 260);

  void add(_ToastData t) {
    _items.add(t);
    while (_items.where((e) => !e.leaving).length > _max) {
      _dismiss(_items.firstWhere((e) => !e.leaving));
    }
    _entry ??= OverlayEntry(builder: _build);
    if (!_entry!.mounted) overlay.insert(_entry!);
    _entry!.markNeedsBuild();
    Timer(_life, () => _dismiss(t));
  }

  void _dismiss(_ToastData t) {
    if (t.leaving || !_items.contains(t)) return;
    t.leaving = true;
    _entry?.markNeedsBuild();
    Timer(_leave, () {
      _items.remove(t);
      if (_items.isEmpty) {
        _entry?.remove();
        _entry = null;
      } else {
        _entry?.markNeedsBuild();
      }
    });
  }

  Widget _build(BuildContext context) {
    return Positioned(
      top: MediaQuery.paddingOf(context).top + 8,
      left: 16,
      right: 16,
      child: IgnorePointer(
        child: Material(
          type: MaterialType.transparency,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final t in _items)
                _ToastView(key: t.key, data: t),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToastView extends StatelessWidget {
  const _ToastView({super.key, required this.data});
  final _ToastData data;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.fromLTRB(10, 8, 12, 8),
      decoration: BoxDecoration(
        color: GameColors.panel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: GameColors.outline, width: 3),
        boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 8, offset: Offset(0, 3))],
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: data.kind.color,
              border: Border.all(color: GameColors.outline, width: 2),
            ),
            child: data.icon ?? Icon(data.kind.icon, size: 18, color: GameColors.outline),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              data.text,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(color: GameColors.text),
            ),
          ),
        ],
      ),
    );
    // Появление: выезжает сверху; уход — уезжает вверх и тает.
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: data.leaving ? 0 : 1),
      duration: data.leaving ? _ToastHost._leave : const Duration(milliseconds: 280),
      curve: data.leaving ? Curves.easeIn : Curves.easeOutBack,
      builder: (_, t, child) => Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.translate(offset: Offset(0, -24 * (1 - t)), child: child),
      ),
      child: card,
    );
  }
}

/// Значок нитки или монеты для уведомлений о наградах.
Widget toastThread() => const ThreadIcon(size: 18);
Widget toastCoin() => const CoinIcon(size: 18);
