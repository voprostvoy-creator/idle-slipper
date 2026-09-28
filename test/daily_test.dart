import 'package:flutter_test/flutter_test.dart';
import 'package:idle_slipper/game/case_box.dart';
import 'package:idle_slipper/game/daily.dart';
import 'package:idle_slipper/game/game_state.dart';
import 'package:idle_slipper/game/slipper.dart';
import 'package:idle_slipper/game/slipper_kind.dart';
import 'package:idle_slipper/game/stars.dart';
import 'package:idle_slipper/game/story/chapters.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final t0 = DateTime(2026, 9, 27, 10);

  group('задания', () {
    test('три разных задания, весь день одни и те же', () {
      final morning = DailyQuests.forDay(DateTime(2026, 9, 27, 8));
      final evening = DailyQuests.forDay(DateTime(2026, 9, 27, 23, 59));
      expect(morning, hasLength(DailyQuests.perDay));
      expect(morning.map((q) => q.kind).toSet(), hasLength(DailyQuests.perDay));
      expect(evening.map((q) => q.kind), morning.map((q) => q.kind));
    });

    test('таймер до полуночи', () {
      expect(untilMidnight(DateTime(2026, 9, 27, 22, 30)), const Duration(minutes: 90));
    });
  });

  group('звёзды', () {
    test('цена растёт со звездой и редкостью', () {
      expect(Stars.copiesFor(1), 1);
      expect(Stars.copiesFor(5), 16);
      expect(Stars.coinsFor(2, Rarity.epic), greaterThan(Stars.coinsFor(2, Rarity.common)));
    });

    test('звёзды усиливают тапок', () {
      final plain = Slipper(name: 'a');
      final starred = Slipper(name: 'a', stars: 3);
      expect(starred.attack, closeTo(plain.attack * 1.24, 0.001));
      expect(starred.maxHp, closeTo(plain.maxHp * 1.24, 0.001));
      expect(starred.power, greaterThan(plain.power));
    });
  });

  group('GameState', () {
    late GameState game;
    late DateTime now;

    setUp(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues({});
      game = await GameState.load(online: false);
      now = t0;
      game.clock = () => now;
      game.cheatNewDay();
    });

    tearDown(() => game.dispose());

    test('ежедневный кейс — раз в день', () {
      const daily = CaseCatalog.dailyCase;
      expect(game.canOpen(daily), isTrue);
      expect(game.openCase(daily), isNotNull);
      expect(game.canOpen(daily), isFalse);
      expect(game.openCase(daily), isNull);
      now = DateTime(2026, 9, 28, 0, 1);
      expect(game.canOpen(daily), isTrue);
    });

    test('задание выполняется, награда забирается один раз, с новым днём сброс', () {
      final quest = game.quests.first;
      // Счётчики растут внутри действий игры; здесь выставляем напрямую.
      game.questProgress[quest.kind.name] = quest.target;
      final before = game.coins;
      expect(game.canClaimQuest(quest), isTrue);
      game.claimQuest(quest);
      expect(game.coins, before + quest.coins);
      expect(game.canClaimQuest(quest), isFalse);

      now = now.add(const Duration(days: 1));
      game.collectChest();
      expect(game.questClaimedToday(quest), isFalse);
    });

    test('сундук наполняется за 8 часов и идёт в задания', () {
      game.chestSince = now;
      expect(game.chestThreads, 0);
      now = now.add(const Duration(hours: 4));
      expect(game.chestFill, closeTo(0.5, 0.001));
      now = now.add(const Duration(hours: 10));
      expect(game.chestFull, isTrue);
      final threads = game.threads;
      game.collectChest();
      expect(game.threads, threads + game.chestCapacity);
      expect(game.chestThreads, 0);
      expect(game.questProgress[QuestKind.chest.name], 1);
    });

    test('первая победа в сюжете бесплатна, повторы — не больше лимита в день', () {
      const chapter = StoryCatalog.chapter1;
      game.slipper = Slipper(name: 'я', levels: {for (final s in Stat.values) s: 20});
      final coins = game.coins;
      final first = game.fightStage(chapter, 0)!;
      expect(first.result.playerWon, isTrue);
      expect(first.coins, chapter.stages[0].coins);
      expect(game.coins, coins + first.coins);
      expect(game.storyReplaysLeft, GameState.storyReplaysPerDay);
      for (var i = 0; i < GameState.storyReplaysPerDay; i++) {
        final replay = game.fightStage(chapter, 0)!;
        expect(replay.coins, 0);
        expect(replay.threads, chapter.stages[0].replayThreads);
      }
      expect(game.fightStage(chapter, 0), isNull);
      // Следующий непройденный бой повторы не тратит.
      expect(game.fightStage(chapter, 1), isNotNull);
      now = now.add(const Duration(days: 1));
      expect(game.fightStage(chapter, 0), isNotNull);
    });

    test('прокачка идёт в задания', () {
      game.cheatThreads(1000);
      game.upgrade(Stat.attack);
      expect(game.questProgress[QuestKind.upgrades.name], 1);
    });

    test('звезда тратит копии и монеты и усиливает надетый тапок', () {
      final id = game.slipper.kindId;
      game.inventory[id] = 3;
      expect(game.canStarUp(id), isFalse, reason: 'нет монет');
      game.cheatCoins(10000);
      final power = game.slipper.power;
      game.starUp(id);
      expect(game.starsOf(id), 1);
      expect(game.count(id), 2);
      expect(game.slipper.stars, 1);
      expect(game.slipper.power, greaterThan(power));
      // Вторая звезда стоит 2 копии, а свободна только одна.
      expect(game.canStarUp(id), isFalse);
    });
  });
}
