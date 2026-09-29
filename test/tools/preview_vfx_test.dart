// Инструмент: рендерит вспышки ударов и скиллов (lib/ui/skill_vfx.dart)
// поверх тапка — по строке на эффект, три фазы в строке.
// Запуск: flutter test test/tools/preview_vfx_test.dart --dart-define=OUT=<папка>
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_slipper/game/slipper.dart';
import 'package:idle_slipper/ui/skill_vfx.dart';
import 'package:idle_slipper/ui/slipper_sprite.dart';

const _out = String.fromEnvironment('OUT');

void main() {
  testWidgets('preview vfx', (tester) async {
    if (_out.isEmpty) return;
    const cell = 200.0;
    const phases = [0.15, 0.45, 0.8];
    const kinds = VfxKind.values;
    // По 2 эффекта в строке, по 3 фазы — 6 ячеек в строке.
    final rows = (kinds.length / 2).ceil();
    tester.view.physicalSize = Size(cell * 6 + 24, cell * 0.62 * rows + 24);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final slipper = Slipper(name: 'p', levels: {for (final s in Stat.values) s: 10});
    const box = Size(cell, cell * 0.56);
    final spriteW = cell * slipper.sizeFactor;
    final spriteH = cell / 2 * slipper.sizeFactor;
    final left = (box.width - spriteW) / 2;
    final top = box.height - spriteH;
    final body = Rect.fromLTRB(left + spriteW * 0.04, top + spriteH * 0.06,
        left + spriteW * 0.96, top + spriteH * 0.94);

    final key = GlobalKey();
    await tester.pumpWidget(MaterialApp(
      home: RepaintBoundary(
        key: key,
        child: Container(
          color: const Color(0xFF241538),
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var r = 0; r < rows; r++)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var k = r * 2; k < r * 2 + 2 && k < kinds.length; k++)
                      for (final t in phases)
                        SizedBox(
                          width: cell,
                          height: cell * 0.62,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Positioned(
                                left: 0,
                                bottom: 0,
                                child: SizedBox.fromSize(
                                  size: box,
                                  child: Stack(
                                    clipBehavior: Clip.none,
                                    alignment: Alignment.bottomCenter,
                                    children: [
                                      SlipperSprite(fighter: slipper, width: cell, animate: false),
                                      Positioned.fill(
                                        child: CustomPaint(
                                          painter: VfxPainter(kind: kinds[k], t: t, body: body),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              Positioned(
                                left: 4,
                                top: 0,
                                child: Text(kinds[k].name,
                                    style: const TextStyle(color: Colors.white, fontSize: 11)),
                              ),
                            ],
                          ),
                        ),
                  ],
                ),
            ],
          ),
        ),
      ),
    ));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 400)));
    await tester.pump();
    final boundary = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await tester.runAsync(() => boundary.toImage(pixelRatio: 1));
    final bytes = await tester.runAsync(() => image!.toByteData(format: ui.ImageByteFormat.png));
    File('$_out/vfx.png').writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}
