// Служебный тест: рендерит тапки в PNG для визуальной проверки.
// Запуск: flutter test test/tools/render_slipper_test.dart --dart-define=OUT=<dir>
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_slipper/game/slipper.dart';
import 'package:idle_slipper/ui/slipper_painter.dart';

const _out = String.fromEnvironment('OUT');

void main() {
  test('render slippers', () async {
    if (_out.isEmpty) return;
    final samples = <String, (Slipper, SlipperMood, bool)>{
      'lv1_idle': (Slipper(name: 'a', colorSeed: 30), SlipperMood.idle, false),
      'lv10_attack': (
        Slipper(name: 'b', colorSeed: 200, levels: {
          Stat.attack: 12, Stat.defense: 8, Stat.health: 6, Stat.speed: 10,
        }),
        SlipperMood.attack,
        false
      ),
      'lv30_flip_hurt': (
        Slipper(name: 'c', colorSeed: 120, levels: {
          Stat.attack: 30, Stat.defense: 30, Stat.health: 15, Stat.speed: 15,
        }),
        SlipperMood.hurt,
        true
      ),
      'happy': (Slipper(name: 'd', colorSeed: 330), SlipperMood.happy, false),
      'dead': (Slipper(name: 'e', colorSeed: 60), SlipperMood.dead, true),
    };
    for (final e in samples.entries) {
      final (s, mood, flip) = e.value;
      final rec = ui.PictureRecorder();
      final canvas = Canvas(rec);
      canvas.drawRect(const Rect.fromLTWH(0, 0, 400, 240), Paint()..color = const Color(0xFF2B2B2B));
      SlipperPainter(slipper: s, mood: mood, flip: flip).paint(canvas, const Size(400, 240));
      final img = await rec.endRecording().toImage(400, 240);
      final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
      File('$_out/${e.key}.png').writeAsBytesSync(bytes!.buffer.asUint8List());
    }
  });
}
