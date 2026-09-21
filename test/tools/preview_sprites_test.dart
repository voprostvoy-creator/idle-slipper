// Инструмент: рендерит каждый тапок из каталога с накладками прокачки в PNG,
// чтобы проверить якоря. Запуск:
//   flutter test test/tools/preview_sprites_test.dart --dart-define=OUT=<папка>
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_slipper/game/slipper.dart';
import 'package:idle_slipper/game/slipper_kind.dart';
import 'package:idle_slipper/ui/slipper_sprite.dart';

const _out = String.fromEnvironment('OUT');

void main() {
  testWidgets('preview sprites', (tester) async {
    if (_out.isEmpty) return;
    const variants = {
      'lv1': {Stat.attack: 1, Stat.defense: 1, Stat.health: 1, Stat.speed: 1},
      'lv15': {Stat.attack: 15, Stat.defense: 12, Stat.health: 10, Stat.speed: 12},
      'lv30': {Stat.attack: 30, Stat.defense: 30, Stat.health: 15, Stat.speed: 15},
    };
    for (final kind in SlipperCatalog.all) {
      for (final v in variants.entries) {
        final key = GlobalKey();
        final slipper = Slipper(name: kind.id, kindId: kind.id, levels: v.value);
        await tester.pumpWidget(
          MaterialApp(
            home: Container(
              color: const Color(0xFF2B2B2B),
              alignment: Alignment.center,
              child: RepaintBoundary(
                key: key,
                // Поля — чтобы увидеть аксессуары, выходящие за картинку.
                child: Padding(
                  padding: const EdgeInsets.all(60),
                  child: SlipperSprite(slipper: slipper, width: 480, animate: false),
                ),
              ),
            ),
          ),
        );
        // Ждём загрузки PNG и повторной раскладки якорей.
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
        await tester.pump();
        final boundary = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
        final image = await tester.runAsync(() => boundary.toImage(pixelRatio: 1));
        final bytes = await tester.runAsync(() => image!.toByteData(format: ui.ImageByteFormat.png));
        File('$_out/${kind.id}_${v.key}.png').writeAsBytesSync(bytes!.buffer.asUint8List());
      }
    }
  });
}
