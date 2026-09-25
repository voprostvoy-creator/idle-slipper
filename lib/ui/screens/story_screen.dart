import 'package:flutter/material.dart';

import '../../game/game_state.dart';
import '../theme.dart';
import '../widgets/game_widgets.dart';
import 'battle_hub_screen.dart';

/// Сюжет: главы с боссами. Пока заглушка — главы появятся следующим шагом.
class StoryScreen extends StatelessWidget {
  const StoryScreen({super.key, required this.game, required this.onBack});

  final GameState game;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      children: [
        BackToModes(title: 'Сюжет', onBack: onBack),
        const SizedBox(height: 16),
        GamePanel(
          color: GameColors.panelDark,
          padding: const EdgeInsets.all(18),
          child: Column(
            children: [
              const Icon(Icons.menu_book_rounded, size: 48, color: GameColors.orange),
              const SizedBox(height: 10),
              Text('Главы скоро появятся', style: theme.textTheme.titleMedium),
              const SizedBox(height: 6),
              Text(
                'Бои с насекомыми, босс в конце каждой главы, '
                'монеты и тапки в награду.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
