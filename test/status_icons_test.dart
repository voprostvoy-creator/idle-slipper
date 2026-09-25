import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_slipper/game/battle/battle_sim.dart';
import 'package:idle_slipper/ui/status_icons.dart';
import 'package:idle_slipper/ui/theme.dart';

void main() {
  test('helpful effects go before harmful ones', () {
    const snap = SideSnapshot(
      ult: 0,
      skillReady: 1,
      burning: true,
      shielded: true,
      slowed: true,
      hasted: true,
    );
    final kinds = statusesOf(snap);
    expect(kinds, [
      StatusKind.shield,
      StatusKind.haste,
      StatusKind.burn,
      StatusKind.slow,
    ]);
    final firstHarmful = kinds.indexWhere((k) => !k.positive);
    expect(kinds.skip(firstHarmful).every((k) => !k.positive), isTrue);
  });

  test('no effects — no icons', () {
    expect(statusesOf(const SideSnapshot(ult: 0.5, skillReady: 0.5)), isEmpty);
  });

  testWidgets('tap opens the description and pauses around the dialog', (tester) async {
    var paused = 0;
    var resumed = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildGameTheme(),
        home: Scaffold(
          body: Center(
            child: StatusIcon(
              kind: StatusKind.slow,
              onDialog: () => paused++,
              onDialogClosed: () => resumed++,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(StatusIcon));
    await tester.pumpAndSettle();
    expect(find.text('Ходит реже обычного.'), findsOneWidget);
    expect(paused, 1);
    expect(resumed, 0);

    await tester.tap(find.text('Понятно'));
    await tester.pumpAndSettle();
    expect(find.text('Ходит реже обычного.'), findsNothing);
    expect(resumed, 1);
  });
}
