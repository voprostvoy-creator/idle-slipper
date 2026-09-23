// Инструмент: рендерит фазы удара каждого тапка в одну полоску PNG,
// чтобы увидеть анимацию атаки, не запуская бой. Запуск:
//   flutter test test/tools/preview_attacks_test.dart --dart-define=OUT=<папка>
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_slipper/game/slipper.dart';
import 'package:idle_slipper/game/slipper_kind.dart';
import 'package:idle_slipper/ui/attack_animation.dart';
import 'package:idle_slipper/ui/slipper_sprite.dart';

const _out = String.fromEnvironment('OUT');

void main() {
  testWidgets('preview attacks', (tester) async {
    if (_out.isEmpty) return;
    const phases = [0.0, 0.25, 0.5, 0.75, 1.0];
    const cell = 220.0;
    // Полоска из пяти кадров шире стандартного тестового экрана.
    tester.view.physicalSize = const Size(1200, 420);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    for (final kind in SlipperCatalog.all) {
      final key = GlobalKey();
      final slipper = Slipper(
        name: kind.id,
        kindId: kind.id,
        levels: {for (final s in Stat.values) s: 12},
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: RepaintBoundary(
              key: key,
              child: Container(
                color: const Color(0xFF241538),
                padding: const EdgeInsets.all(12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final t in phases)
                      SizedBox(
                        width: cell,
                        height: cell,
                        child: Center(
                          child: AttackAnimation.apply(
                            style: kind.attack,
                            progress: t,
                            flip: false,
                            reach: cell * 0.28,
                            child: SlipperSprite(
                              slipper: slipper,
                              mood: SlipperMood.attack,
                              width: cell * 0.8,
                              animate: false,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
      await tester.pump();
      final boundary = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await tester.runAsync(() => boundary.toImage(pixelRatio: 1));
      final bytes = await tester.runAsync(
        () => image!.toByteData(format: ui.ImageByteFormat.png),
      );
      File('$_out/atk_${kind.id}_${kind.attack.name}.png')
          .writeAsBytesSync(bytes!.buffer.asUint8List());
    }
  });
}
