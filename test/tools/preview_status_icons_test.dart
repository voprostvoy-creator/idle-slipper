// Инструмент: рендерит все значки эффектов в двух размерах — боевом и крупном.
// Запуск: flutter test test/tools/preview_status_icons_test.dart --dart-define=OUT=<папка>
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_slipper/ui/status_icons.dart';

const _out = String.fromEnvironment('OUT');

/// Цифры как в бою: у барьера, уклонения и оглушения их нет.
int? _turnsFor(StatusKind k) => switch (k) {
      StatusKind.barrier || StatusKind.evade || StatusKind.stun => null,
      StatusKind.burn => 3,
      _ => 2,
    };

void main() {
  testWidgets('preview status icons', (tester) async {
    if (_out.isEmpty) return;
    tester.view.physicalSize = const Size(900, 260);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: RepaintBoundary(
            key: key,
            child: Container(
              color: const Color(0xFF241538),
              padding: const EdgeInsets.all(14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Крупно — чтобы разглядеть рисунок.
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final k in StatusKind.values)
                        Padding(
                          padding: const EdgeInsets.all(6),
                          child: StatusIcon(
                            kind: k,
                            turns: _turnsFor(k),
                            size: 88,
                            onDialog: () {},
                            onDialogClosed: () {},
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // В боевом размере — как их видно на телефоне.
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final k in StatusKind.values)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: StatusIcon(
                            kind: k,
                            turns: _turnsFor(k),
                            size: 24,
                            onDialog: () {},
                            onDialogClosed: () {},
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final boundary = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await tester.runAsync(() => boundary.toImage(pixelRatio: 1));
    final bytes = await tester.runAsync(
      () => image!.toByteData(format: ui.ImageByteFormat.png),
    );
    File('$_out/status_icons.png').writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}
