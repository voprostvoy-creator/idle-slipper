import 'package:flutter/material.dart';

import '../../game/game_state.dart';
import '../theme.dart';
import '../widgets/game_widgets.dart';
import 'arena_screen.dart';
import 'story_screen.dart';

/// Режимы боя, доступные из кнопки «В бой».
enum BattleMode { story, arena }

/// Вкладка «В бой»: сначала выбор режима, затем сам режим внутри той же
/// вкладки — шапка с валютами и меню остаются на месте.
class BattleHubScreen extends StatelessWidget {
  const BattleHubScreen({
    super.key,
    required this.game,
    required this.mode,
    required this.onMode,
  });

  final GameState game;

  /// Открытый режим; null — экран выбора.
  final BattleMode? mode;
  final ValueChanged<BattleMode?> onMode;

  @override
  Widget build(BuildContext context) {
    return switch (mode) {
      BattleMode.arena => ArenaScreen(game: game, onBack: () => onMode(null)),
      BattleMode.story => StoryScreen(game: game, onBack: () => onMode(null)),
      null => _ModePicker(onMode: onMode),
    };
  }
}

class _ModePicker extends StatelessWidget {
  const _ModePicker({required this.onMode});
  final ValueChanged<BattleMode?> onMode;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      children: [
        const Center(child: StrokeText('В бой', size: 30)),
        const SizedBox(height: 4),
        Center(
          child: Text(
            'Выбери, с кем драться',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        const SizedBox(height: 16),
        // Режимы бок о бок; IntrinsicHeight выравнивает карточки по высоте,
        // даже если описание в одной длиннее.
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _ModeCard(
                  title: 'Сюжет',
                  subtitle: 'Главы с боссами. Награда — монеты и тапки.',
                  icon: Icons.menu_book_rounded,
                  color: GameColors.orange,
                  onTap: () => onMode(BattleMode.story),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ModeCard(
                  title: 'Арена',
                  subtitle: 'Тапки других игроков. Награда — нитки и рейтинг.',
                  icon: Icons.emoji_events_rounded,
                  color: GameColors.blue,
                  onTap: () => onMode(BattleMode.arena),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Большая карточка режима: цветная плитка с иконкой, название и что даёт.
class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GamePanel(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
      onTap: onTap,
      child: Column(
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: GameColors.outline, width: 3),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color.lerp(color, Colors.white, 0.3)!, color],
                ),
              ),
              child: FittedBox(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Icon(icon, size: 56, color: GameColors.outline),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          StrokeText(title, size: 24),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

/// Строка «← Назад к режимам» для экранов внутри вкладки «В бой».
class BackToModes extends StatelessWidget {
  const BackToModes({super.key, required this.title, required this.onBack});

  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        GameButton(
          onPressed: onBack,
          color: GameColors.panelLight,
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: const Icon(Icons.arrow_back_rounded, color: GameColors.text),
        ),
        Expanded(child: Center(child: StrokeText(title, size: 30))),
        // Уравновешиваем кнопку, чтобы заголовок стоял по центру.
        const SizedBox(width: 44),
      ],
    );
  }
}
