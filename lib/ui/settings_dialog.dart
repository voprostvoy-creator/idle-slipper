import 'package:flutter/material.dart';

import '../audio/music.dart';
import '../audio/sfx.dart';
import 'theme.dart';
import 'widgets/game_widgets.dart';

/// Настройки звука: громкость музыки и эффектов в бою.
Future<void> showSettingsDialog(BuildContext context) => showDialog<void>(
  context: context,
  builder: (context) => AlertDialog(
    title: const Center(child: StrokeText('Настройки', size: 24)),
    insetPadding: const EdgeInsets.symmetric(horizontal: 24),
    content: SizedBox(
      width: 320,
      child: ListenableBuilder(
        listenable: Listenable.merge([Music.instance, Sfx.instance]),
        builder: (context, _) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _VolumeRow(
              label: 'Музыка',
              icon: Icons.music_note_rounded,
              offIcon: Icons.music_off_rounded,
              value: Music.instance.volume,
              onChanged: Music.instance.setVolume,
            ),
            const SizedBox(height: 8),
            _VolumeRow(
              label: 'Эффекты',
              icon: Icons.volume_up_rounded,
              offIcon: Icons.volume_off_rounded,
              value: Sfx.instance.volume,
              onChanged: Sfx.instance.setVolume,
              // Отпустил ползунок — слышно, как теперь звучит удар.
              onChangeEnd: (_) => Sfx.instance.hit(),
            ),
          ],
        ),
      ),
    ),
    actions: [
      GameButton(
        color: GameColors.gold,
        onPressed: () => Navigator.pop(context),
        child: const Text('Готово'),
      ),
    ],
  ),
);

class _VolumeRow extends StatelessWidget {
  const _VolumeRow({
    required this.label,
    required this.icon,
    required this.offIcon,
    required this.value,
    required this.onChanged,
    this.onChangeEnd,
  });

  final String label;
  final IconData icon;
  final IconData offIcon;
  final double value;
  final ValueChanged<double> onChanged;
  final ValueChanged<double>? onChangeEnd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GamePanel(
      color: GameColors.panelDark,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 2),
      child: Column(
        children: [
          Row(
            children: [
              Icon(value == 0 ? offIcon : icon, color: GameColors.gold),
              const SizedBox(width: 8),
              Text(label, style: theme.textTheme.titleSmall),
              const Spacer(),
              Text(
                '${(value * 100).round()}%',
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
          Slider(
            value: value,
            onChanged: onChanged,
            onChangeEnd: onChangeEnd,
            activeColor: GameColors.gold,
          ),
        ],
      ),
    );
  }
}
