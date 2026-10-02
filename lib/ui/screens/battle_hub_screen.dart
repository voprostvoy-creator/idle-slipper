import 'dart:math';

import 'package:flutter/material.dart';

import '../../game/game_state.dart';
import '../../game/slipper_kind.dart';
import '../../game/story/enemies.dart';
import '../theme.dart';
import '../widgets/game_widgets.dart';
import 'arena_screen.dart';
import 'defense_screen.dart';
import 'dig_screen.dart';
import 'story_screen.dart';

/// Режимы боя, доступные из кнопки «В бой».
enum BattleMode { story, arena, dig, defense }

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
      BattleMode.dig => DigScreen(game: game, onBack: () => onMode(null)),
      BattleMode.defense => DefenseScreen(game: game, onBack: () => onMode(null)),
      null => ListenableBuilder(
          listenable: game,
          builder: (_, _) => _ModePicker(onMode: onMode, digReady: game.digTasksReady),
        ),
    };
  }
}

class _ModePicker extends StatelessWidget {
  const _ModePicker({required this.onMode, this.digReady = false});
  final ValueChanged<BattleMode?> onMode;

  /// Выполнено задание «Под диваном» — точка на карточке режима.
  final bool digReady;

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
                  art: const _StoryArt(),
                  color: GameColors.orange,
                  onTap: () => onMode(BattleMode.story),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ModeCard(
                  title: 'Арена',
                  subtitle: 'Тапки других игроков. Награда — нитки и рейтинг.',
                  art: const _ArenaArt(),
                  color: GameColors.blue,
                  onTap: () => onMode(BattleMode.arena),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Режим без боёв «в лоб» — широкой карточкой под основными.
        GamePanel(
          padding: const EdgeInsets.all(12),
          onTap: () => onMode(BattleMode.dig),
          child: Row(
            children: [
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: GameColors.outline, width: 3),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFB59A7A), Color(0xFF6F5E4B)],
                  ),
                ),
                child: const DigArt(),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const StrokeText('Под диваном', size: 24),
                        if (digReady) ...[
                          const SizedBox(width: 8),
                          Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: GameColors.red,
                              border: Border.all(color: GameColors.outline, width: 2),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Раскопки в пыли: гемы, нитки и монеты. Новое поле каждый день.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        GamePanel(
          padding: const EdgeInsets.all(12),
          onTap: () => onMode(BattleMode.defense),
          child: Row(
            children: [
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: GameColors.outline, width: 3),
                ),
                // Миниатюрный снимок поля обороны.
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: Image.asset('assets/ui/defense_thumb.webp', fit: BoxFit.cover),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const StrokeText('Оборона сада', size: 24),
                    const SizedBox(height: 4),
                    Text(
                      'Расставь тапки и отбей 10 волн жуков. Попытка в день.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
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
    required this.art,
    required this.color,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final Widget art;
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
              child: ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: art,
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

/// Картинка «Сюжета»: тапок замахивается на таракана, рядом кружит муха.
class _StoryArt extends StatelessWidget {
  const _StoryArt();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final s = box.maxWidth;
        return Stack(
          children: [
            Positioned(
              right: -s * 0.12,
              bottom: s * 0.02,
              width: s * 1.0,
              child: Transform.flip(
                flipX: true,
                child: Image.asset(EnemyCatalog.cockroach.asset),
              ),
            ),
            Positioned(
              right: s * 0.02,
              top: s * 0.04,
              width: s * 0.42,
              child: Transform.rotate(
                angle: -0.2,
                child: Transform.flip(
                  flipX: true,
                  child: Image.asset(EnemyCatalog.fly.asset),
                ),
              ),
            ),
            Positioned(
              left: -s * 0.1,
              top: s * 0.1,
              width: s * 0.8,
              child: Transform.rotate(
                angle: -0.55,
                child: Image.asset(SlipperCatalog.byId('basic').asset),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Картинка «Арены»: два тапка скрещены почти под прямым углом, как мечи.
class _ArenaArt extends StatelessWidget {
  const _ArenaArt();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final s = box.maxWidth;
        Widget slipper(String id, double angle, {bool flip = false}) => Positioned(
              left: s * 0.06,
              // По центру плитки: картинка 2:1 высотой 0.44 от ширины.
              top: s * 0.3,
              width: s * 0.88,
              child: Transform.rotate(
                angle: angle,
                child: Transform.flip(
                  flipX: flip,
                  child: Image.asset(SlipperCatalog.byId(id).asset),
                ),
              ),
            );
        return Stack(
          children: [
            slipper('red_spike', -pi / 4),
            slipper('blue_slide', pi / 4, flip: true),
          ],
        );
      },
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
