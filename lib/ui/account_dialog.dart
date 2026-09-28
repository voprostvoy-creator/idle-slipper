import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';

import '../game/game_state.dart';
import '../net/server_api.dart';
import 'theme.dart';
import 'widgets/game_widgets.dart';

/// Окно «Твой аккаунт»: логин и пароль, сохранить картинкой в галерею
/// или скопировать. [firstTime] — показано сразу после создания аккаунта.
Future<void> showAccountDialog(BuildContext context, GameState game, {bool firstTime = false}) {
  final creds = game.server.credentials;
  if (creds == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Аккаунт ещё не создан — нужна связь с сервером')),
    );
    return Future.value();
  }
  return showDialog<void>(
    context: context,
    barrierDismissible: !firstTime,
    builder: (_) => _AccountDialog(login: creds.login, password: creds.password, firstTime: firstTime),
  ).whenComplete(() {
    if (firstTime) game.acknowledgeAccount();
  });
}

class _AccountDialog extends StatefulWidget {
  const _AccountDialog({required this.login, required this.password, required this.firstTime});

  final String login;
  final String password;
  final bool firstTime;

  @override
  State<_AccountDialog> createState() => _AccountDialogState();
}

class _AccountDialogState extends State<_AccountDialog> {
  final _cardKey = GlobalKey();
  String? _status;

  Future<void> _saveImage() async {
    if (kIsWeb) {
      setState(() => _status = 'Сохранение картинки работает на телефоне — скопируй данные');
      return;
    }
    try {
      final boundary = _cardKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      if (!await Gal.hasAccess() && !await Gal.requestAccess()) {
        setState(() => _status = 'Нет доступа к галерее');
        return;
      }
      await Gal.putImageBytes(png!.buffer.asUint8List(), name: 'boi-tapkov-${widget.login}');
      setState(() => _status = 'Картинка сохранена в галерею');
    } catch (_) {
      setState(() => _status = 'Не удалось сохранить — скопируй данные');
    }
  }

  Future<void> _copy() async {
    await Clipboard.setData(
      ClipboardData(text: 'Бои Тапков\nЛогин: ${widget.login}\nПароль: ${widget.password}'),
    );
    setState(() => _status = 'Скопировано');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      contentPadding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Эта карточка и уходит картинкой в галерею.
          RepaintBoundary(
            key: _cardKey,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [GameColors.bgTop, GameColors.bgBottom],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: GameColors.gold, width: 3),
              ),
              child: Column(
                children: [
                  const StrokeText('Бои Тапков', size: 24, color: GameColors.gold),
                  const SizedBox(height: 2),
                  Text('Данные для входа', style: theme.textTheme.bodySmall),
                  const SizedBox(height: 12),
                  _Field(label: 'Логин', value: widget.login),
                  const SizedBox(height: 8),
                  _Field(label: 'Пароль', value: widget.password),
                  const SizedBox(height: 10),
                  Text(
                    'По ним можно войти на другом телефоне.\nВосстановить их нельзя — сохрани!',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: GameButton(
                  color: GameColors.gold,
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  onPressed: _saveImage,
                  child: const Text('В галерею', style: TextStyle(fontSize: 14)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GameButton(
                  color: GameColors.blue,
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  onPressed: _copy,
                  child: const Text('Скопировать', style: TextStyle(fontSize: 14)),
                ),
              ),
            ],
          ),
          if (_status != null) ...[
            const SizedBox(height: 8),
            Text(_status!, textAlign: TextAlign.center, style: theme.textTheme.bodySmall),
          ],
        ],
      ),
      actions: [
        GameButton(
          color: GameColors.green,
          onPressed: () => Navigator.pop(context),
          child: const Text('Готово'),
        ),
      ],
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: GameColors.panelDark,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: GameColors.outline, width: 2),
      ),
      child: Column(
        children: [
          Text(label, style: Theme.of(context).textTheme.labelSmall),
          SelectableText(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
              color: GameColors.text,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}

/// Вход в другой аккаунт: логин, пароль и предупреждение, что прогресс
/// на этом телефоне заменится облачным.
Future<void> showLoginDialog(BuildContext context, GameState game) async {
  final login = TextEditingController();
  final password = TextEditingController();
  String? error;
  var busy = false;
  await showDialog<void>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const StrokeText('Войти в аккаунт', size: 22),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: login,
              decoration: const InputDecoration(labelText: 'Логин', hintText: 'tapok-12345'),
              autocorrect: false,
            ),
            TextField(
              controller: password,
              decoration: const InputDecoration(labelText: 'Пароль'),
              autocorrect: false,
            ),
            const SizedBox(height: 10),
            const Text(
              'Прогресс на этом телефоне заменится прогрессом этого аккаунта. '
              'Сначала сохрани данные входа текущего аккаунта, если он нужен.',
              style: TextStyle(fontSize: 12, color: GameColors.textDim),
            ),
            if (error != null) ...[
              const SizedBox(height: 8),
              Text(error!, style: const TextStyle(color: GameColors.red)),
            ],
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
          GameButton(
            color: GameColors.gold,
            onPressed: busy
                ? null
                : () async {
                    setState(() {
                      busy = true;
                      error = null;
                    });
                    try {
                      await game.switchAccount(login.text, password.text);
                      if (context.mounted) Navigator.pop(context);
                    } on ServerException catch (e) {
                      setState(() {
                        busy = false;
                        error = e.message;
                      });
                    }
                  },
            child: Text(busy ? 'Вход…' : 'Войти'),
          ),
        ],
      ),
    ),
  );
}
