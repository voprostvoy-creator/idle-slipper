// Инструмент: рендерит росчерки скиллов поверх тапка в одну полоску PNG.
// Запуск: flutter test test/tools/preview_skill_vfx_test.dart --dart-define=OUT=<папка>
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_slipper/game/battle/skills.dart';
import 'package:idle_slipper/game/slipper.dart';
import 'package:idle_slipper/ui/skill_vfx.dart';
import 'package:idle_slipper/ui/slipper_sprite.dart';

const _out = String.fromEnvironment('OUT');

void main() {
  testWidgets('preview skill vfx', (tester) async {
    if (_out.isEmpty) return;
    const cell = 210.0;
    final kinds = SkillVfx.values.where((v) => v != SkillVfx.none).toList();
    tester.view.physicalSize = Size(cell * kinds.length + 40, 260);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final slipper = Slipper(
      name: 'preview',
      levels: {for (final s in Stat.values) s: 10},
    );
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
                  for (final vfx in kinds)
                    SizedBox(
                      width: cell,
                      height: cell * 0.56,
                      child: Stack(
                        alignment: Alignment.bottomCenter,
                        children: [
                          SlipperSprite(fighter: slipper, width: cell, animate: false),
                          Positioned.fill(
                            child: SkillVfxLayer(
                              vfx: vfx,
                              color: switch (vfx) {
                                SkillVfx.shockwave => const Color(0xFFFF6161),
                                SkillVfx.slash => const Color(0xFF4FD8FF),
                                SkillVfx.burst => const Color(0xFFFFC93C),
                                SkillVfx.frost => const Color(0xFF5BC8FF),
                                SkillVfx.drain => const Color(0xFFC77DFF),
                                SkillVfx.blades => const Color(0xFF6BE07A),
                                _ => const Color(0xFFB9B0C4),
                              },
                              body: bodyRect,
                              flip: false,
                              token: 1,
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
    // Ловим середину анимации — там эффект виден лучше всего.
    await tester.pump(const Duration(milliseconds: 260));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 260)));
    await tester.pump(const Duration(milliseconds: 40));

    final boundary = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await tester.runAsync(() => boundary.toImage(pixelRatio: 1));
    final bytes = await tester.runAsync(
      () => image!.toByteData(format: ui.ImageByteFormat.png),
    );
    File('$_out/skill_vfx.png').writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}
