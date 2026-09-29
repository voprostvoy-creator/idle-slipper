import 'package:flutter/material.dart';

import '../../game/game_state.dart';
import '../../net/server_api.dart';
import '../account_dialog.dart';
import '../slipper_sprite.dart';
import '../theme.dart';
import '../widgets/game_widgets.dart';

/// Первая страница, пока на телефоне нет аккаунта: создать новый
/// или войти в уже созданный.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key, required this.game, required this.onDone});

  final GameState game;

  /// Аккаунт готов (или игрок решил играть без сети) — открыть игру.
  final VoidCallback onDone;

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  bool _busy = false;
  String? _error;

  Future<void> _create() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.game.createAccount();
      if (!mounted) return;
      await showNicknameDialog(context, widget.game);
      if (!mounted) return;
      await showAccountDialog(context, widget.game, firstTime: true);
      widget.onDone();
    } on ServerException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _login() async {
    final ok = await showLoginDialog(context, widget.game, replacing: false);
    if (ok) widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: GameBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
            child: Column(
              children: [
                const Spacer(),
                const StrokeText('Бои Тапков', size: 42, color: GameColors.gold),
                const SizedBox(height: 16),
                SlipperSprite(fighter: widget.game.slipper, width: 240, showSize: false),
                const SizedBox(height: 16),
                Text(
                  'Качай тапок, гоняй насекомых\nи поднимайся в рейтинге',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium,
                ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  child: GameButton(
                    color: GameColors.gold,
                    height: 56,
                    onPressed: _busy ? null : _create,
                    child: Text(
                      _busy ? 'Создаём…' : 'Создать аккаунт',
                      style: const TextStyle(fontSize: 20),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: GameButton(
                    color: GameColors.panelLight,
                    height: 56,
                    onPressed: _busy ? null : _login,
                    child: const Text(
                      'У меня уже есть аккаунт',
                      style: TextStyle(fontSize: 18, color: GameColors.text),
                    ),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    '$_error. Проверь интернет и попробуй ещё раз.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(color: GameColors.red),
                  ),
                  TextButton(
                    onPressed: widget.onDone,
                    child: Text('Играть без сети', style: theme.textTheme.bodySmall),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
