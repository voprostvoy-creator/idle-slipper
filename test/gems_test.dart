import 'package:flutter_test/flutter_test.dart';
import 'package:idle_slipper/game/dig.dart';
import 'package:idle_slipper/game/game_state.dart';
import 'package:idle_slipper/game/gems.dart';
import 'package:idle_slipper/game/slipper.dart';
import 'package:idle_slipper/game/slipper_kind.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('гемы', () {
    test('обычные дают плоскую прибавку, эпические — проценты', () {
      const common = Gem(id: 1, type: GemType.attack, rarity: Rarity.common);
      const epic = Gem(id: 2, type: GemType.attack, rarity: Rarity.epic, level: 2);
      final plain = Slipper(name: 'a');
      expect(Slipper(name: 'a', gems: const [common]).attack, closeTo(plain.attack + 3, 1e-9));
      expect(Slipper(name: 'a', gems: const [epic]).attack, closeTo(plain.attack * 1.06, 1e-9));
      expect(epic.bonusText, '+6% удара');
    });

    test('крит и уворот — прибавка к шансу', () {
      const crit = Gem(id: 1, type: GemType.crit, rarity: Rarity.rare, level: 3);
      final plain = Slipper(name: 'a');
      expect(Slipper(name: 'a', gems: const [crit]).critChance, closeTo(plain.critChance + 0.03, 1e-9));
    });

    test('слоты открываются чётными звёздами', () {
      expect([for (var s = 0; s <= 5; s++) Gems.slotsFor(s)], [1, 1, 2, 2, 3, 3]);
    });
  });

  group('под диваном', () {
    test('поле 6×6 одно на весь день, под каждой клеткой есть находка', () {
      final a = DigBoard.forDay(DateTime(2026, 9, 28, 9));
      final b = DigBoard.forDay(DateTime(2026, 9, 28, 22));
      expect(a.cells.map((c) => c.loot), b.cells.map((c) => c.loot));
      expect(a.cells, hasLength(36));
      expect(a.cells.every((c) => c.loot != DigLoot.empty && c.layers == 1), isTrue);
      // За месяц встречаются все виды находок.
      final seen = {
        for (var d = 1; d <= 30; d++) ...DigBoard.forDay(DateTime(2026, 9, d)).cells.map((c) => c.loot),
      };
      expect(seen, containsAll([DigLoot.threads, DigLoot.coins, DigLoot.gem, DigLoot.guard, DigLoot.treasure]));
    });

    test('подсказка считает блестящих соседей', () {
      final board = DigBoard.seeded(1);
      for (var i = 0; i < DigBoard.size; i++) {
        final h = board.hintAt(i);
        expect(h, inInclusiveRange(0, 8));
      }
    });
  });

  group('GameState', () {
    late GameState game;
    var now = DateTime(2026, 9, 28, 10);

    setUp(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues({});
      game = await GameState.load(online: false);
      now = DateTime(2026, 9, 28, 10);
      game.clock = () => now;
      game.cheatNewDay();
    });

    tearDown(() => game.dispose());

    test('вставленный гем усиливает надетый тапок, снятый — нет', () {
      game.cheatGems();
      final gem = game.gems.first;
      final before = game.slipper.power;
      game.insertGem(game.slipper.kindId, 0, gem.id);
      expect(game.slipper.gems, [isA<Gem>()]);
      expect(game.slipper.power, greaterThanOrEqualTo(before));
      expect(game.freeGems.any((g) => g.id == gem.id), isFalse);
      game.removeGem(game.slipper.kindId, 0);
      expect(game.slipper.gems, isEmpty);
    });

    test('второй слот закрыт до ★2', () {
      game.cheatGems();
      game.insertGem(game.slipper.kindId, 1, game.gems.first.id);
      expect(game.socketsOf(game.slipper.kindId), hasLength(1));
      expect(game.slipper.gems, isEmpty);
    });

    test('слияние 3 → 1 поднимает уровень', () {
      game.cheatGems();
      final first = game.gems.first;
      expect(game.canMerge(first), isTrue);
      final count = game.gems.length;
      game.mergeGem(first);
      expect(game.gems, hasLength(count - 2));
      expect(game.gemById(first.id)!.level, 2);
    });

    test('взмахи ограничены, расчищенная клетка отдаёт находку', () {
      final board = game.digBoard;
      final threadsCell = board.cells.indexWhere((c) => c.loot == DigLoot.threads);
      final before = game.threads;
      while (!game.digRevealed(threadsCell)) {
        game.dig(threadsCell);
      }
      expect(game.threads, greaterThan(before));
      var swings = 0;
      for (var i = 0; i < DigBoard.size; i++) {
        while (game.dig(i) != null) {
          swings++;
        }
      }
      expect(game.digSwingsLeft, 0);
      expect(swings, lessThanOrEqualTo(DigBoard.swingsPerDay));
      // Задание дня добавляет взмахи.
      final quest = game.quests.first;
      game.questProgress[quest.kind.name] = quest.target;
      game.claimQuest(quest);
      expect(game.digSwingsLeft, GameState.swingsPerQuest);
      now = now.add(const Duration(days: 1));
      expect(game.dig(0), isNotNull);
    });
  });
}
