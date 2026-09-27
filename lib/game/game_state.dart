import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'battle/battle_sim.dart';
import 'economy.dart';
import 'opponents.dart';
import 'case_box.dart';
import 'daily.dart';
import 'rating.dart';
import 'slipper.dart';
import 'slipper_kind.dart';
import 'stars.dart';
import 'story/chapters.dart';

/// Единственный источник правды для UI. Сохраняется в SharedPreferences.
class GameState extends ChangeNotifier with WidgetsBindingObserver {
  GameState._(this._prefs);

  static const _key = 'save_v1';

  final SharedPreferences _prefs;
  Timer? _ticker;

  Slipper slipper = Slipper(name: 'Мой тапок');
  /// TODO: вернуть 50 перед релизом — сейчас для тестов пусто,
  /// нитки берутся кнопкой в отладочной панели.
  static const double startingThreads = 0;

  /// TODO: убрать перед релизом — для тестов вся коллекция открыта сразу.
  static Map<String, int> get startingInventory =>
      {for (final k in SlipperCatalog.all) k.id: 1};

  /// Основная валюта: нитки. Тратятся на прокачку и кейсы.
  double threads = startingThreads;

  /// Вторая валюта: монеты. Пока не зарабатываются — задел на будущее.
  int coins = 0;

  /// Тапки в собственности: id вида → сколько штук. Дубликаты стакаются.
  Map<String, int> inventory = startingInventory;
  int rating = Rating.initial;
  int wins = 0;
  int losses = 0;

  /// Часы игры. Подменяется в тестах, чтобы проверять смену дня.
  DateTime Function() clock = DateTime.now;

  /// Звёзды видов в коллекции: id вида → 0..5.
  Map<String, int> stars = {};

  /// Попытки арены, восстанавливаются со временем.
  ArenaTickets tickets = ArenaTickets.full(DateTime.now());

  /// День, когда забран ежедневный кейс.
  String dailyCaseDay = '';

  /// Задания: день, прогресс по видам, полученные награды.
  String questDay = '';
  Map<String, int> questProgress = {};
  Set<String> questClaimed = {};
  bool questBonusClaimed = false;

  /// Сюжет: id главы → сколько боёв подряд пройдено с начала.
  Map<String, int> storyCleared = {};

  /// Сид текущего набора соперников. Меняется после каждого боя.
  int _opponentSeed = 1;
  List<Opponent> opponents = const [];

  /// Нитки, накопленные пока приложение было закрыто. UI показывает и сбрасывает.
  double pendingOfflineThreads = 0;
  Duration pendingOfflineDuration = Duration.zero;

  DateTime _lastSeen = DateTime.now();

  double get incomePerSecond => Economy.incomePerSecond(slipper, rating);

  static Future<GameState> load() async {
    final prefs = await SharedPreferences.getInstance();
    final state = GameState._(prefs);
    state._restore();
    state._refreshOpponents();
    state._start();
    return state;
  }

  // --- Жизненный цикл --------------------------------------------------

  void _start() {
    WidgetsBinding.instance.addObserver(this);
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  @override
  void dispose() {
    _ticker?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        _lastSeen = DateTime.now();
        _save();
      case AppLifecycleState.resumed:
        _collectOffline(DateTime.now().difference(_lastSeen));
    }
  }

  void _tick() {
    threads += incomePerSecond;
    tickets = tickets.refill(clock());
    _rollDay();
    _lastSeen = DateTime.now();
    notifyListeners();
    // Сохраняемся раз в 10 секунд, чтобы не дёргать диск каждый тик.
    if (DateTime.now().second % 10 == 0) _save();
  }

  void _collectOffline(Duration away) {
    if (away < const Duration(seconds: 30)) return;
    final capped = away > Economy.maxOffline ? Economy.maxOffline : away;
    final earned = incomePerSecond * capped.inSeconds;
    threads += earned;
    pendingOfflineThreads = earned;
    pendingOfflineDuration = capped;
    notifyListeners();
  }

  void acknowledgeOffline() {
    pendingOfflineThreads = 0;
    pendingOfflineDuration = Duration.zero;
    notifyListeners();
  }

  // --- Действия игрока -------------------------------------------------

  void tap() {
    threads += Economy.tapReward(slipper);
    _progress(QuestKind.taps);
    notifyListeners();
  }

  int upgradeCost(Stat stat) => Economy.upgradeCost(stat, slipper.level(stat));

  bool canUpgrade(Stat stat) => threads >= upgradeCost(stat);

  void upgrade(Stat stat) {
    final cost = upgradeCost(stat);
    if (threads < cost) return;
    threads -= cost;
    final levels = Map.of(slipper.levels);
    levels[stat] = levels[stat]! + 1;
    slipper = slipper.copyWith(levels: levels);
    _progress(QuestKind.upgrades);
    _refreshOpponents();
    _save();
    notifyListeners();
  }

  void rename(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    slipper = slipper.copyWith(name: trimmed);
    _save();
    notifyListeners();
  }

  /// Сменить вид тапка — только на то, что есть в инвентаре.
  void equip(String kindId) {
    if ((inventory[kindId] ?? 0) == 0) return;
    slipper = slipper.copyWith(kindId: kindId, stars: starsOf(kindId));
    _refreshOpponents();
    _save();
    notifyListeners();
  }

  bool get canFightArena => tickets.count > 0;

  /// Проводит бой и сразу применяет результат. Возвращает результат
  /// для анимации — UI показывает его уже как «запись».
  /// Бой стоит одну попытку; без попыток — null.
  BattleResult? fight(Opponent opponent) {
    tickets = tickets.refill(clock());
    if (!canFightArena) return null;
    tickets = tickets.spend(clock());
    final result = BattleSim.run(slipper, opponent.slipper, seed: opponent.battleSeed);
    final won = result.playerWon;
    threads += Economy.battleReward(won: won, opponentPower: opponent.slipper.power);
    rating = max(100, rating + Rating.delta(mine: rating, theirs: opponent.rating, won: won));
    if (won) {
      wins++;
      _progress(QuestKind.arenaWins);
    } else {
      losses++;
    }
    _progress(QuestKind.arenaFights);
    _opponentSeed = Random().nextInt(1 << 31);
    _refreshOpponents();
    _save();
    notifyListeners();
    return result;
  }

  // --- Сюжет ------------------------------------------------------------

  int cleared(Chapter chapter) => storyCleared[chapter.id] ?? 0;

  /// Доступны пройденные бои и первый непройденный.
  bool stageOpen(Chapter chapter, int index) => index <= cleared(chapter);

  /// Бой главы. Сид каждый раз новый — проигранный бой можно переиграть.
  /// Награда за первую победу полная, за повторные — примерно треть.
  StoryOutcome fightStage(Chapter chapter, int index) {
    final stage = chapter.stages[index];
    final result = BattleSim.run(slipper, stage.enemy, seed: Random().nextInt(1 << 31));
    var coinsWon = 0;
    SlipperKind? kindWon;
    if (result.playerWon) {
      _progress(QuestKind.storyWins);
      final first = index == cleared(chapter);
      coinsWon = first ? stage.coins : stage.replayCoins;
      coins += coinsWon;
      if (first) {
        storyCleared[chapter.id] = index + 1;
        final rewardId = stage.rewardKindId;
        if (rewardId != null) {
          kindWon = SlipperCatalog.byId(rewardId);
          inventory[rewardId] = count(rewardId) + 1;
        }
      }
      _save();
      notifyListeners();
    }
    return (result: result, coins: coinsWon, kind: kindWon);
  }

  void _refreshOpponents() {
    opponents = OpponentGenerator.generate(
      player: slipper,
      rating: rating,
      seed: _opponentSeed,
    );
  }

  // --- Сохранение ------------------------------------------------------

  void _save() {
    _prefs.setString(
      _key,
      jsonEncode({
        'slipper': slipper.toJson(),
        'threads': threads,
        'coins': coins,
        'inventory': inventory,
        'rating': rating,
        'wins': wins,
        'losses': losses,
        'opponentSeed': _opponentSeed,
        'story': storyCleared,
        'stars': stars,
        'tickets': tickets.count,
        'ticketsAt': tickets.since.toIso8601String(),
        'dailyCaseDay': dailyCaseDay,
        'questDay': questDay,
        'questProgress': questProgress,
        'questClaimed': questClaimed.toList(),
        'questBonus': questBonusClaimed,
        'lastSeen': _lastSeen.toIso8601String(),
      }),
    );
  }

  void _restore() {
    final raw = _prefs.getString(_key);
    if (raw == null) return;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      slipper = Slipper.fromJson(json['slipper'] as Map<String, dynamic>);
      // Миграция: до введения ниток основной валютой были монеты.
      threads = (json['threads'] as num?)?.toDouble() ??
          (json['coins'] as num?)?.toDouble() ??
          threads;
      coins = json['threads'] == null ? 0 : (json['coins'] as num?)?.toInt() ?? 0;
      final inv = json['inventory'] as Map?;
      if (inv != null && inv.isNotEmpty) {
        inventory = {
          for (final e in inv.entries) e.key as String: (e.value as num).toInt(),
        };
      }
      // Надетый тапок всегда присутствует в инвентаре.
      inventory[slipper.kindId] = max(1, inventory[slipper.kindId] ?? 0);
      rating = json['rating'] as int? ?? rating;
      wins = json['wins'] as int? ?? 0;
      losses = json['losses'] as int? ?? 0;
      _opponentSeed = json['opponentSeed'] as int? ?? 1;
      final starsJson = json['stars'] as Map?;
      if (starsJson != null) {
        stars = {
          for (final e in starsJson.entries) e.key as String: (e.value as num).toInt(),
        };
      }
      slipper = slipper.copyWith(stars: starsOf(slipper.kindId));
      final ticketsAt = DateTime.tryParse(json['ticketsAt'] as String? ?? '');
      if (ticketsAt != null) {
        tickets = ArenaTickets(
          count: (json['tickets'] as num?)?.toInt() ?? ArenaTickets.max,
          since: ticketsAt,
        ).refill(clock());
      }
      dailyCaseDay = json['dailyCaseDay'] as String? ?? '';
      questDay = json['questDay'] as String? ?? '';
      final qp = json['questProgress'] as Map?;
      if (qp != null) {
        questProgress = {
          for (final e in qp.entries) e.key as String: (e.value as num).toInt(),
        };
      }
      questClaimed = {...?(json['questClaimed'] as List?)?.cast<String>()};
      questBonusClaimed = json['questBonus'] as bool? ?? false;
      _rollDay();
      final story = json['story'] as Map?;
      if (story != null) {
        storyCleared = {
          for (final e in story.entries) e.key as String: (e.value as num).toInt(),
        };
      }
      final seen = DateTime.tryParse(json['lastSeen'] as String? ?? '');
      if (seen != null) {
        _collectOffline(DateTime.now().difference(seen));
      }
    } catch (e) {
      debugPrint('Save corrupted, starting fresh: $e');
    }
  }

  // --- Кейсы ------------------------------------------------------------

  bool canOpen(CaseType type) =>
      type.daily ? dailyCaseAvailable : threads >= type.price;

  /// Открывает кейс: списывает нитки, роллит вид и сразу кладёт его в
  /// инвентарь. Продать выпавшее можно потом — так дроп не теряется,
  /// если игрок закроет экран на середине анимации.
  SlipperKind? openCase(CaseType type) {
    if (!canOpen(type)) return null;
    threads -= type.price;
    if (type.daily) dailyCaseDay = dayKey(clock());
    _progress(QuestKind.openCases);
    final kind = type.roll(Random());
    inventory[kind.id] = (inventory[kind.id] ?? 0) + 1;
    _save();
    notifyListeners();
    return kind;
  }

  int count(String kindId) => inventory[kindId] ?? 0;

  /// Продать одну штуку. Последний экземпляр надетого тапка продать нельзя.
  bool sell(String kindId) {
    final have = count(kindId);
    if (have == 0) return false;
    if (have == 1 && kindId == slipper.kindId) return false;
    if (have == 1) {
      inventory.remove(kindId);
    } else {
      inventory[kindId] = have - 1;
    }
    threads += SlipperCatalog.byId(kindId).rarity.sellPrice;
    _save();
    notifyListeners();
    return true;
  }

  // --- Ежедневное --------------------------------------------------------

  bool get dailyCaseAvailable => dailyCaseDay != dayKey(clock());

  /// С полуночи задания начинаются заново.
  void _rollDay() {
    final today = dayKey(clock());
    if (questDay == today) return;
    questDay = today;
    questProgress = {};
    questClaimed = {};
    questBonusClaimed = false;
  }

  void _progress(QuestKind kind) {
    _rollDay();
    questProgress[kind.name] = (questProgress[kind.name] ?? 0) + 1;
  }

  List<QuestSpec> get quests => DailyQuests.forDay(clock());

  int questValue(QuestSpec q) => min(q.target, questProgress[q.kind.name] ?? 0);

  bool questClaimedToday(QuestSpec q) => questClaimed.contains(q.kind.name);

  bool canClaimQuest(QuestSpec q) =>
      !questClaimedToday(q) && questValue(q) >= q.target;

  void claimQuest(QuestSpec q) {
    if (!canClaimQuest(q)) return;
    questClaimed.add(q.kind.name);
    coins += q.coins;
    _save();
    notifyListeners();
  }

  bool get canClaimQuestBonus =>
      !questBonusClaimed && quests.every(questClaimedToday);

  void claimQuestBonus() {
    if (!canClaimQuestBonus) return;
    questBonusClaimed = true;
    coins += DailyQuests.bonusCoins;
    _save();
    notifyListeners();
  }

  /// Есть что забрать — для красной точки на вкладке.
  bool get questsReady => quests.any(canClaimQuest) || canClaimQuestBonus;

  // --- Звёзды -------------------------------------------------------------

  int starsOf(String kindId) => stars[kindId] ?? 0;

  /// Копии сверх одной — они идут на звёзды.
  int copiesOf(String kindId) => max(0, count(kindId) - 1);

  /// Цена следующей звезды; null — звёзд уже максимум.
  ({int copies, int coins})? nextStarCost(String kindId) {
    final next = starsOf(kindId) + 1;
    if (next > Stars.max) return null;
    return (
      copies: Stars.copiesFor(next),
      coins: Stars.coinsFor(next, SlipperCatalog.byId(kindId).rarity),
    );
  }

  bool canStarUp(String kindId) {
    final cost = nextStarCost(kindId);
    return cost != null && copiesOf(kindId) >= cost.copies && coins >= cost.coins;
  }

  void starUp(String kindId) {
    if (!canStarUp(kindId)) return;
    final cost = nextStarCost(kindId)!;
    inventory[kindId] = count(kindId) - cost.copies;
    coins -= cost.coins;
    stars[kindId] = starsOf(kindId) + 1;
    if (kindId == slipper.kindId) {
      slipper = slipper.copyWith(stars: starsOf(kindId));
      _refreshOpponents();
    }
    _save();
    notifyListeners();
  }

  /// Для отладки: монеты.
  void cheatCoins(int amount) {
    coins += amount;
    _save();
    notifyListeners();
  }

  /// Для отладки: как будто наступил новый день и попытки восстановились.
  void cheatNewDay() {
    tickets = ArenaTickets.full(clock());
    dailyCaseDay = '';
    questDay = '';
    _rollDay();
    _save();
    notifyListeners();
  }

  /// Для отладки: выдать ниток.
  void cheatThreads(double amount) {
    threads += amount;
    _save();
    notifyListeners();
  }

  /// Для отладки: полный сброс.
  Future<void> reset() async {
    await _prefs.remove(_key);
    slipper = Slipper(name: 'Мой тапок');
    threads = startingThreads;
    coins = 0;
    inventory = startingInventory;
    rating = Rating.initial;
    wins = 0;
    losses = 0;
    _opponentSeed = 1;
    storyCleared = {};
    stars = {};
    tickets = ArenaTickets.full(clock());
    dailyCaseDay = '';
    questDay = '';
    _rollDay();
    _refreshOpponents();
    notifyListeners();
  }
}

/// Итог боя главы: запись для экрана боя и что выдано.
typedef StoryOutcome = ({BattleResult result, int coins, SlipperKind? kind});
