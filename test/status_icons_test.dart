import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_slipper/game/battle/battle_sim.dart';
import 'package:idle_slipper/ui/status_icons.dart';
import 'package:idle_slipper/ui/theme.dart';

void main() {
  test('helpful effects go before harmful ones and carry their turns', () {
    const snap = SideSnapshot(
      ult: 0,
      skillReady: 1,
      burnTurns: 3,
      shieldTurns: 2,
      slowTurns: 1,
      hasteTurns: 3,
      barriered: true,
    );
    final statuses = statusesOf(snap);
    expect(statuses.map((s) => s.kind), [
      StatusKind.shield,
      StatusKind.barrier,
      StatusKind.haste,
      StatusKind.burn,
      StatusKind.slow,
    ]);
    expect(statuses.map((s) => s.turns), [2, null, 3, 3, 1]);

    final firstHarmful = statuses.indexWhere((s) => !s.kind.positive);
    expect(statuses.skip(firstHarmful).every((s) => !s.kind.positive), isTrue);
  });

  test('effects without a turn count show no number', () {
    const snap = SideSnapshot(
      ult: 0,
      skillReady: 1,
      stunned: true,
      evading: true,
      barriered: true,
    );
    expect(statusesOf(snap).every((s) => s.turns == null), isTrue);
  });

  test('no effects — no icons', () {
    expect(statusesOf(const SideSnapshot(ult: 0.5, skillReady: 0.5)), isEmpty);
  });

  testWidgets('icon shows the remaining turns and the dialog repeats them', (tester) async {
    var paused = 0;
    var resumed = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildGameTheme(),
        home: Scaffold(
          body: Center(
            child: StatusIcon(
              kind: StatusKind.slow,
              turns: 2,
              size: 40,
              onDialog: () => paused++,
              onDialogClosed: () => resumed++,
            ),
          ),
        ),
      ),
    );
    expect(find.text('2'), findsOneWidget);

    await tester.tap(find.byType(StatusIcon));
    await tester.pumpAndSettle();
    expect(find.text('Ходит реже обычного.'), findsOneWidget);
    expect(find.text('Осталось: 2 хода'), findsOneWidget);
    expect(paused, 1);

    await tester.tap(find.text('Понятно'));
    await tester.pumpAndSettle();
    expect(find.text('Ходит реже обычного.'), findsNothing);
    expect(resumed, 1);
  });
}
