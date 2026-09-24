// Инструмент: рендерит боевые эффекты поверх тапка в одну полоску PNG.
// Запуск: flutter test test/tools/preview_effects_test.dart --dart-define=OUT=<папка>
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_slipper/game/slipper.dart';
import 'package:idle_slipper/ui/battle_effects.dart';
import 'package:idle_slipper/ui/slipper_sprite.dart';

const _out = String.fromEnvironment('OUT');

void main() {
  testWidgets('preview effects', (tester) async {
    if (_out.isEmpty) return;
    const cell = 230.0;
    tester.view.physicalSize = const Size(1200, 340);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final slipper = Slipper(
      name: 'preview',
      levels: {for (final s in Stat.values) s: 10},
    );
    // Те же расчёты, что и на экране боя: спрайт прижат к низу и уменьшен.
    const box = Size(cell, cell * 0.56);
    final spriteW = cell * slipper.sizeFactor;
    final spriteH = cell / 2 * slipper.sizeFactor;
    final left = (box.width - spriteW) / 2;
    final top = box.height - spriteH;
    final bodyRect = Rect.fromLTRB(
      left + spriteW * 0.04,
      top + spriteH * 0.06,
      left + spriteW * 0.96,
      top + spriteH * 0.94,
    );
    // Каждый эффект отдельно и все разом — проверяем, что они не спорят.
    const sets = <Set<BattleEffect>>[
      {BattleEffect.stun},
      {BattleEffect.burn},
      {BattleEffect.shield},
      {BattleEffect.heal},
      {BattleEffect.burn, BattleEffect.shield, BattleEffect.stun},
    ];

    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: RepaintBoundary(
            key: key,
            child: Container(
              color: const Color(0xFF241538),
              padding: const EdgeInsets.all(10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final set in sets)
                    SizedBox(
                      width: cell,
                      height: cell * 0.56,
                      child: Stack(
                        alignment: Alignment.bottomCenter,
                        children: [
                          SlipperSprite(fighter: slipper, width: cell, animate: false),
                          Positioned.fill(
                            child: BattleEffectsLayer(
                              effects: set,
                              size: box,
                              body: bodyRect,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    // Даём анимации уйти от нулевой фазы, иначе всё замрёт в старте.
    await tester.pump(const Duration(milliseconds: 420));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pump(const Duration(milliseconds: 120));

    final boundary = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await tester.runAsync(() => boundary.toImage(pixelRatio: 1));
    final bytes = await tester.runAsync(
      () => image!.toByteData(format: ui.ImageByteFormat.png),
    );
    File('$_out/effects.png').writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}
