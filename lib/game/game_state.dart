import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'battle/battle_sim.dart';
import 'economy.dart';
import '../net/server_api.dart';
import 'case_box.dart';
import 'daily.dart';
import 'dig.dart';
import 'gems.dart';
import 'rating.dart';
import 'slipper.dart';
import 'slipper_kind.dart';
import 'stars.dart';
import 'story/chapters.dart';
import 'story/enemies.dart';

/// Единственный источник правды для UI. Сохраняется в SharedPreferences.
class GameState extends ChangeNotifier with WidgetsBindingObserver {
  GameState._(this._prefs, this.server);

  /// Сервер: арена, рейтинг и облачная копия сохранения.
  final ServerApi server;

  static const _key = 'save_v1';

  final SharedPreferences _prefs;
  Timer? _ticker;

  Slipper slipper = Slipper(name: 'Мой тапок');

  /// TODO: вернуть 50 перед релизом — сейчас для тестов пусто,
  /// нитки берутся кнопкой в отладочной панели.
  static const double startingThreads = 0;

  /// На старте — только базовый тапок, остальные выбиваются из кейсов.
  /// TODO: убрать Инь-Ян перед релизом — выдан со старта для тестов.
  static Map<String, int> get startingInventory => {
    SlipperCatalog.defaultId: 1,
    _testKindId: 1,
  };

  static const _testKindId = 'yin_yang';

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

  /// Рейтинг арены с сервера — последний полученный.
  ArenaBoard? arenaBoard;
  bool arenaLoading = false;
  String? arenaError;

  /// Все гемы игрока и следующий свободный id.
  List<Gem> gems = [];
  int _nextGemId = 1;

  /// Слоты гемов по видам тапков: id вида → id гемов в слотах (null — пусто).
  Map<String, List<int?>> sockets = {};

  /// «Под диваном»: день поля, сколько пыли осталось на клетках,
  /// потраченные взмахи и клетки, с которых награда уже забрана.
  String digDay = '';
  List<int> digLayers = [];
  int digSwingsUsed = 0;
  Set<int> digTaken = {};

  /// Полученные сегодня награды за задания «Под диваном».
  Set<String> digTasksClaimed = {};

  /// Лавка за монеты: день и купленные в этот день виды.
  String shopDay = '';
  Set<String> shopBought = {};

  /// День, когда забран ежедневный кейс.
  String dailyCaseDay = '';

  /// Задания: день, прогресс по видам, полученные награды.
  String questDay = '';
  Map<String, int> questProgress = {};
  Set<String> questClaimed = {};
  bool questBonusClaimed = false;

  /// Сюжет: id главы → сколько боёв подряд пройдено с начала.
  Map<String, int> storyCleared = {};

  /// Сундук дежурства: наполняется с этого момента.
  DateTime chestSince = DateTime.now();

  /// Повторы боёв сюжета за сегодня — их не больше [storyReplaysPerDay].
  static const storyReplaysPerDay = 10;
  int storyReplaysUsed = 0;

  /// [online] = false — без сервера (тесты).
  static Future<GameState> load({bool online = true}) async {
    final prefs = await SharedPreferences.getInstance();
    final state = GameState._(
      prefs,
      online ? ServerApi(prefs) : ServerApi.disabled(prefs),
    );
    state._restore();
    state._start();
    // Аккаунт уже есть — отправим свежий снимок тапка.
    if (online && state.server.hasAccount) state._pushNow();
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
    _pushTimer?.cancel();
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
        _save();
      case AppLifecycleState.resumed:
        notifyListeners();
    }
  }

  /// Раз в секунду: попытки, смена дня и таймеры на экране.
  void _tick() {
    _rollDay();
    notifyListeners();
  }

  // --- Действия игрока -------------------------------------------------

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
    slipper = slipper.copyWith(kindId: kindId);
    _syncSlipper();
    _save();
    notifyListeners();
  }

  /// Место в рейтинге арены — по последнему ответу сервера.
  int? get arenaPlace => arenaBoard?.me.place;

  /// Обновить рейтинг с сервера.
  Future<void> refreshArena() async {
    if (arenaLoading) return;
    arenaLoading = true;
    arenaError = null;
    notifyListeners();
    try {
      arenaBoard = await server.leaderboard();
      rating = arenaBoard!.me.rating;
    } on ServerException catch (e) {
      arenaError = e.message;
    } finally {
      arenaLoading = false;
      notifyListeners();
    }
  }

  /// Бой на арене через сервер: сначала отправляем свежий снимок тапка,
  /// сервер подбирает соперника, считает бой и меняет очки, а игра
  /// по его сиду проигрывает тот же бой. Нитки начисляет сервер.
  /// Нет связи — [ServerException].
  Future<ArenaOutcome> fightArena() async {
    await server.pushSave(_saveJson(), slipper.toJson());
    final f = await server.fight();
    final result = BattleSim.run(slipper, f.opponent.slipper, seed: f.seed);
    if (result.playerWon) {
      wins++;
      _progress(QuestKind.arenaWins);
    } else {
      losses++;
    }
    _progress(QuestKind.arenaFights);
    threads += f.threads;
    rating = f.rating;
    _save();
    notifyListeners();
    // Рейтинг изменился — обновим таблицу в фоне.
    unawaited(refreshArena());
    return (
      result: result,
      opponent: f.opponent,
      ratingBefore: f.ratingBefore,
      ratingDelta: f.rating - f.ratingBefore,
      threads: f.threads,
    );
  }

  // --- Сюжет ------------------------------------------------------------

  int cleared(Chapter chapter) => storyCleared[chapter.id] ?? 0;

  /// Глава открыта: первая — всегда, следующие — после всей предыдущей.
  bool chapterOpen(Chapter chapter) {
    final i = StoryCatalog.chapters.indexOf(chapter);
    if (i <= 0) return true;
    final prev = StoryCatalog.chapters[i - 1];
    return cleared(prev) >= prev.stages.length;
  }

  /// Последняя открытая глава — с неё начинается экран сюжета.
  Chapter get currentChapter =>
      StoryCatalog.chapters.lastWhere(chapterOpen, orElse: () => StoryCatalog.chapter1);

  /// Доступны пройденные бои и первый непройденный.
  bool stageOpen(Chapter chapter, int index) => index <= cleared(chapter);

  int get storyReplaysLeft => max(0, storyReplaysPerDay - storyReplaysUsed);

  /// Бой главы. Сид каждый раз новый — проигранный бой можно переиграть.
  /// Первый непройденный бой бесплатный: нитки, монеты и, у босса, тапок.
  /// Повтор пройденного тратит дневной лимит и даёт треть ниток.
  /// Без повторов в запасе — null.
  StoryOutcome? fightStage(Chapter chapter, int index) {
    if (!chapterOpen(chapter) || index > cleared(chapter)) return null;
    final stage = chapter.stages[index];
    final first = index == cleared(chapter);
    _rollDay();
    if (!first) {
      if (storyReplaysLeft == 0) return null;
      storyReplaysUsed++;
    }
    final result = BattleSim.run(
      slipper,
      stage.enemy,
      seed: Random().nextInt(1 << 31),
    );
    var threadsWon = 0;
    var coinsWon = 0;
    SlipperKind? kindWon;
    if (result.playerWon) {
      _progress(QuestKind.storyWins);
      threadsWon = Economy.withBonus(
        first ? stage.threads : stage.replayThreads,
        slipper,
      );
      threads += threadsWon;
      if (first) {
        coinsWon = stage.coins;
        coins += coinsWon;
        storyCleared[chapter.id] = index + 1;
        final rewardId = stage.rewardKindId;
        if (rewardId != null) {
          kindWon = SlipperCatalog.byId(rewardId);
          inventory[rewardId] = count(rewardId) + 1;
        }
      }
    }
    _save();
    notifyListeners();
    return (
      result: result,
      threads: threadsWon,
      coins: coinsWon,
      kind: kindWon,
    );
  }

  // --- Сохранение ------------------------------------------------------

  void _save() {
    _prefs.setString(_key, jsonEncode(_saveJson()));
    _schedulePush();
  }

  Timer? _pushTimer;

  /// Сохранение уходит на сервер не чаще раза в несколько секунд:
  /// прокачка подряд — один запрос.
  void _schedulePush() {
    if (!server.enabled || !server.hasAccount) return;
    _pushTimer?.cancel();
    _pushTimer = Timer(const Duration(seconds: 4), _pushNow);
  }

  Future<void> _pushNow() async {
    try {
      final serverRating = await server.pushSave(_saveJson(), slipper.toJson());
      if (serverRating != rating) {
        rating = serverRating;
        notifyListeners();
      }
    } on ServerException {
      // Нет сети — отправится со следующим сохранением.
    }
  }

  Map<String, dynamic> _saveJson() => {
    'slipper': slipper.toJson(),
    'threads': threads,
    'coins': coins,
    'inventory': inventory,
    'rating': rating,
    'wins': wins,
    'losses': losses,
    'story': storyCleared,
    'stars': stars,
    'dailyCaseDay': dailyCaseDay,
    'questDay': questDay,
    'questProgress': questProgress,
    'questClaimed': questClaimed.toList(),
    'questBonus': questBonusClaimed,
    'gems': [for (final g in gems) g.toJson()],
    'gemNext': _nextGemId,
    'sockets': sockets,
    'digDay': digDay,
    'digLayers': digLayers,
    'digSwings': digSwingsUsed,
    'digTaken': digTaken.toList(),
    'digTasks': digTasksClaimed.toList(),
    'shopDay': shopDay,
    'shopBought': shopBought.toList(),
    'chestSince': chestSince.toIso8601String(),
    'storyReplays': storyReplaysUsed,
  };

  void _restore() {
    final raw = _prefs.getString(_key);
    if (raw == null) return;
    try {
      _applySave(jsonDecode(raw) as Map<String, dynamic>);
    } catch (e) {
      debugPrint('Save corrupted, starting fresh: $e');
    }
  }

  /// Разложить сохранение по полям — из памяти телефона или из облака.
  void _applySave(Map<String, dynamic> json) {
    {
      slipper = Slipper.fromJson(json['slipper'] as Map<String, dynamic>);
      // Миграция: до введения ниток основной валютой были монеты.
      threads =
          (json['threads'] as num?)?.toDouble() ??
          (json['coins'] as num?)?.toDouble() ??
          threads;
      coins = json['threads'] == null
          ? 0
          : (json['coins'] as num?)?.toInt() ?? 0;
      final inv = json['inventory'] as Map?;
      if (inv != null && inv.isNotEmpty) {
        inventory = {
          for (final e in inv.entries)
            e.key as String: (e.value as num).toInt(),
        };
      }
      // TODO: убрать перед релизом — тестовый тапок и в старых сохранениях.
      inventory[_testKindId] = max(1, inventory[_testKindId] ?? 0);
      // Надетый тапок всегда присутствует в инвентаре.
      inventory[slipper.kindId] = max(1, inventory[slipper.kindId] ?? 0);
      rating = json['rating'] as int? ?? rating;
      wins = json['wins'] as int? ?? 0;
      losses = json['losses'] as int? ?? 0;
      final starsJson = json['stars'] as Map?;
      if (starsJson != null) {
        stars = {
          for (final e in starsJson.entries)
            e.key as String: (e.value as num).toInt(),
        };
      }
      final gemsJson = json['gems'] as List?;
      if (gemsJson != null) {
        gems = [
          for (final g in gemsJson)
            ?Gem.fromJson((g as Map).cast<String, dynamic>()),
        ];
      }
      _nextGemId =
          (json['gemNext'] as num?)?.toInt() ??
          (gems.isEmpty ? 1 : gems.map((g) => g.id).reduce(max) + 1);
      final socketsJson = json['sockets'] as Map?;
      if (socketsJson != null) {
        sockets = {
          for (final e in socketsJson.entries)
            e.key as String: [
              for (final id in e.value as List) (id as num?)?.toInt(),
            ],
        };
      }
      _syncSlipper();
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
      digDay = json['digDay'] as String? ?? '';
      digLayers = [
        for (final v in (json['digLayers'] as List? ?? const []))
          (v as num).toInt(),
      ];
      digSwingsUsed = (json['digSwings'] as num?)?.toInt() ?? 0;
      digTaken = {
        for (final v in (json['digTaken'] as List? ?? const []))
          (v as num).toInt(),
      };
      digTasksClaimed = {...?(json['digTasks'] as List?)?.cast<String>()};
      shopDay = json['shopDay'] as String? ?? '';
      shopBought = {...?(json['shopBought'] as List?)?.cast<String>()};
      _rollDay();
      final story = json['story'] as Map?;
      if (story != null) {
        storyCleared = {
          for (final e in story.entries)
            e.key as String: (e.value as num).toInt(),
        };
      }
      // Старые сохранения без сундука: считаем с последнего визита.
      final chestAt =
          DateTime.tryParse(json['chestSince'] as String? ?? '') ??
          DateTime.tryParse(json['lastSeen'] as String? ?? '');
      if (chestAt != null) chestSince = chestAt;
      storyReplaysUsed = (json['storyReplays'] as num?)?.toInt() ?? 0;
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
    storyReplaysUsed = 0;
    _rollDig();
  }

  // --- Гемы ----------------------------------------------------------------

  /// Тапок получает гемы из слотов своего вида.
  void _syncSlipper() {
    final kind = slipper.kindId;
    slipper = slipper.copyWith(
      stars: starsOf(kind),
      gems: [for (final g in socketsOf(kind)) ?g],
    );
  }

  Gem? gemById(int id) => gems.where((g) => g.id == id).firstOrNull;

  /// Слоты вида с учётом звёзд: открытых — столько, сколько позволяют звёзды.
  List<Gem?> socketsOf(String kindId) {
    final ids = sockets[kindId] ?? const [];
    return [
      for (var i = 0; i < Gems.slotsFor(starsOf(kindId)); i++)
        i < ids.length && ids[i] != null ? gemById(ids[i]!) : null,
    ];
  }

  /// В какой вид вставлен гем; null — лежит свободно.
  String? socketedIn(int gemId) {
    for (final e in sockets.entries) {
      if (e.value.contains(gemId)) return e.key;
    }
    return null;
  }

  List<Gem> get freeGems => [
    for (final g in gems)
      if (socketedIn(g.id) == null) g,
  ];

  /// Вставить гем в слот вида. Если гем стоял в другом слоте — переезжает,
  /// а гем, занимавший слот, освобождается.
  void insertGem(String kindId, int slot, int gemId) {
    if (slot >= Gems.slotsFor(starsOf(kindId)) || gemById(gemId) == null) {
      return;
    }
    for (final list in sockets.values) {
      for (var i = 0; i < list.length; i++) {
        if (list[i] == gemId) list[i] = null;
      }
    }
    final list = sockets.putIfAbsent(
      kindId,
      () => List.filled(Gems.maxSlots, null, growable: true),
    );
    while (list.length < Gems.maxSlots) {
      list.add(null);
    }
    list[slot] = gemId;
    _gemsChanged();
  }

  void removeGem(String kindId, int slot) {
    final list = sockets[kindId];
    if (list == null || slot >= list.length) return;
    list[slot] = null;
    _gemsChanged();
  }

  /// Свободные гемы, с которыми можно слить [gem]: такие же, но не он сам.
  List<Gem> _mergeMates(Gem gem) => [
    for (final g in freeGems)
      if (g.id != gem.id && g.sameAs(gem)) g,
  ];

  /// Сколько подходящих свободных гемов есть для слияния (нужно 2).
  int mergeMates(Gem gem) => _mergeMates(gem).length;

  bool canMerge(Gem gem) =>
      gem.level < Gem.maxLevel && _mergeMates(gem).length >= 2;

  /// Слияние 3 → 1: [gem] получает уровень выше, два таких же исчезают.
  /// Если [gem] был вставлен, он остаётся в слоте.
  void mergeGem(Gem gem) {
    if (!canMerge(gem)) return;
    final used = _mergeMates(gem).take(2).map((g) => g.id).toSet();
    gems = [
      for (final g in gems)
        if (g.id == gem.id)
          g.copyWith(level: g.level + 1)
        else if (!used.contains(g.id))
          g,
    ];
    _gemsChanged();
  }

  Gem _giveGem(Rarity rarity) {
    final gem = Gem.random(Random(), id: _nextGemId++, rarity: rarity);
    gems.add(gem);
    return gem;
  }

  void _gemsChanged() {
    _syncSlipper();
    _save();
    notifyListeners();
  }

  // --- Под диваном -----------------------------------------------------------

  DigBoard get digBoard => DigBoard.forDay(clock());

  /// Взмахи за задания мини-игры (свои, не задания дня).
  int get digSwingsEarned => [
        for (final t in DigTasks.all)
          if (digTasksClaimed.contains(t.kind.name)) t.swings,
      ].fold(0, (a, b) => a + b);

  int digTaskValue(DigTask t) => min(t.target, questProgress[t.kind.name] ?? 0);

  bool digTaskClaimed(DigTask t) => digTasksClaimed.contains(t.kind.name);

  bool canClaimDigTask(DigTask t) => !digTaskClaimed(t) && digTaskValue(t) >= t.target;

  /// Есть выполненное задание «Под диваном» — красная точка.
  bool get digTasksReady => DigTasks.all.any(canClaimDigTask);

  void claimDigTask(DigTask t) {
    if (!canClaimDigTask(t)) return;
    digTasksClaimed.add(t.kind.name);
    _save();
    notifyListeners();
  }

  int get digSwingsLeft =>
      max(0, DigBoard.swingsPerDay + digSwingsEarned - digSwingsUsed);

  /// Новый день — новое поле.
  void _rollDig() {
    final today = dayKey(clock());
    if (digDay == today && digLayers.length == DigBoard.size) return;
    digDay = today;
    digLayers = [for (final c in digBoard.cells) c.layers];
    digSwingsUsed = 0;
    digTaken = {};
    digTasksClaimed = {};
  }

  bool digRevealed(int i) => digLayers.length > i && digLayers[i] <= 0;

  /// Взмах по клетке: снимает пыль, а расчищенная клетка сразу отдаёт
  /// находку. Страж не отдаёт награду сам — с ним надо сразиться.
  DigOutcome? dig(int i) {
    _rollDay();
    if (digRevealed(i) || digSwingsLeft == 0) return null;
    digSwingsUsed++;
    digLayers[i] = 0;
    DigOutcome outcome = const (
      threads: 0,
      coins: 0,
      gem: null,
      revealed: false,
    );
    if (digLayers[i] == 0) {
      outcome = _takeDigLoot(i);
    }
    _save();
    notifyListeners();
    return outcome;
  }

  DigOutcome _takeDigLoot(int i) {
    final cell = digBoard.cells[i];
    var t = 0;
    var c = 0;
    Gem? gem;
    switch (cell.loot) {
      case DigLoot.threads:
        t = Economy.withBonus(15 + slipper.power * 0.08, slipper);
        threads += t;
      case DigLoot.coins:
        c = 8 + i % 5;
        coins += c;
      case DigLoot.gem:
      case DigLoot.treasure:
        gem = _giveGem(cell.gemRarity!);
      case DigLoot.guard:
        return const (threads: 0, coins: 0, gem: null, revealed: true);
      case DigLoot.empty:
        break;
    }
    digTaken.add(i);
    return (threads: t, coins: c, gem: gem, revealed: true);
  }

  bool digGuardWaiting(int i) =>
      digRevealed(i) &&
      digBoard.cells[i].loot == DigLoot.guard &&
      !digTaken.contains(i);

  /// Страж под диваном: элитное насекомое примерно твоей силы.
  Enemy digGuard(int i) {
    const kinds = [
      EnemyCatalog.cockroach,
      EnemyCatalog.fly,
      EnemyCatalog.mosquito,
      EnemyCatalog.rhinoBeetle,
    ];
    final avg = max(1, (slipper.totalLevel / 4 * 0.85).round());
    return Enemy(
      kind: kinds[i % kinds.length],
      levels: {for (final s in Stat.values) s: avg},
      name: 'Страж: ${kinds[i % kinds.length].name.toLowerCase()}',
      elite: true,
    );
  }

  /// Бой со стражем стоит взмах. Победа — гем, проигрыш — можно ещё раз.
  ({BattleResult result, Enemy enemy, Gem? gem})? fightDigGuard(int i) {
    _rollDay();
    if (!digGuardWaiting(i) || digSwingsLeft == 0) return null;
    digSwingsUsed++;
    final enemy = digGuard(i);
    final result = BattleSim.run(
      slipper,
      enemy,
      seed: Random().nextInt(1 << 31),
    );
    Gem? gem;
    if (result.playerWon) {
      gem = _giveGem(digBoard.cells[i].gemRarity!);
      digTaken.add(i);
    }
    _save();
    notifyListeners();
    return (result: result, enemy: enemy, gem: gem);
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

  // --- Сундук дежурства ---------------------------------------------------

  int get chestCapacity => Economy.chestCapacity(slipper);

  /// Заполненность 0..1.
  double get chestFill =>
      (clock().difference(chestSince).inSeconds /
              Economy.chestFillTime.inSeconds)
          .clamp(0.0, 1.0);

  int get chestThreads => (chestCapacity * chestFill).floor();

  bool get chestFull => chestFill >= 1;

  /// Через сколько сундук заполнится; null — уже полный.
  Duration? get chestFullIn => chestFull
      ? null
      : chestSince.add(Economy.chestFillTime).difference(clock());

  void collectChest() {
    final amount = chestThreads;
    if (amount <= 0) return;
    threads += amount;
    chestSince = clock();
    _progress(QuestKind.chest);
    _save();
    notifyListeners();
  }

  // --- Лавка за монеты ------------------------------------------------------

  List<SlipperKind> get shopOffers => CoinShop.forDay(dayNumber(clock()));

  bool shopSold(SlipperKind k) => shopDay == dayKey(clock()) && shopBought.contains(k.id);

  bool canBuy(SlipperKind k) => !shopSold(k) && coins >= CoinShop.priceOf(k.rarity);

  void buyFromShop(SlipperKind k) {
    if (!canBuy(k) || !shopOffers.contains(k)) return;
    final today = dayKey(clock());
    if (shopDay != today) {
      shopDay = today;
      shopBought = {};
    }
    coins -= CoinShop.priceOf(k.rarity);
    inventory[k.id] = count(k.id) + 1;
    shopBought.add(k.id);
    _save();
    notifyListeners();
  }

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
    return cost != null &&
        copiesOf(kindId) >= cost.copies &&
        coins >= cost.coins;
  }

  void starUp(String kindId) {
    if (!canStarUp(kindId)) return;
    final cost = nextStarCost(kindId)!;
    inventory[kindId] = count(kindId) - cost.copies;
    coins -= cost.coins;
    stars[kindId] = starsOf(kindId) + 1;
    // Звезда могла открыть новый слот — тапок пересобирается с гемами.
    if (kindId == slipper.kindId) _syncSlipper();
    _save();
    notifyListeners();
  }

  /// Для отладки: по одному экземпляру каждого тапка из каталога.
  void cheatOneOfEach() {
    for (final k in SlipperCatalog.all) {
      inventory[k.id] = count(k.id) + 1;
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

  /// Для отладки: три одинаковых гема (проверить слияние) и по гему
  /// каждой редкости.
  void cheatGems() {
    final type = GemType.values[Random().nextInt(GemType.values.length)];
    for (var i = 0; i < 3; i++) {
      gems.add(Gem(id: _nextGemId++, type: type, rarity: Rarity.common));
    }
    for (final r in Rarity.values) {
      _giveGem(r);
    }
    _gemsChanged();
  }

  /// Для отладки: как будто наступил новый день.
  void cheatNewDay() {
    digDay = '';
    chestSince = clock().subtract(Economy.chestFillTime);
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
    _resetFields();
    notifyListeners();
  }

  void _resetFields() {
    slipper = Slipper(name: 'Мой тапок');
    threads = startingThreads;
    coins = 0;
    inventory = startingInventory;
    rating = Rating.initial;
    wins = 0;
    losses = 0;
    storyCleared = {};
    stars = {};
    arenaBoard = null;
    gems = [];
    _nextGemId = 1;
    sockets = {};
    digDay = '';
    chestSince = clock();
    dailyCaseDay = '';
    questDay = '';
    _rollDay();
  }

  // --- Аккаунт -------------------------------------------------------------

  /// Создать аккаунт и отправить на сервер текущий прогресс.
  Future<({String login, String password})> createAccount() async {
    final creds = await server.register();
    await _pushNow();
    notifyListeners();
    return creds;
  }

  /// Войти в другой аккаунт: прогресс на этом телефоне заменяется
  /// облачным. Ошибка входа — [ServerException].
  Future<void> switchAccount(String login, String password) async {
    final save = await server.login(login, password);
    _resetFields();
    if (save != null) _applySave(save);
    _prefs.setString(_key, jsonEncode(_saveJson()));
    notifyListeners();
    unawaited(refreshArena());
  }
}

/// Итог боя главы: запись для экрана боя и что выдано.
typedef StoryOutcome = ({
  BattleResult result,
  int threads,
  int coins,
  SlipperKind? kind,
});

/// Итог боя на арене: запись, соперник и что изменилось.
typedef ArenaOutcome = ({
  BattleResult result,
  BoardEntry opponent,
  int ratingBefore,
  int ratingDelta,
  int threads,
});

/// Итог взмаха под диваном: что выдано и расчищена ли клетка.
typedef DigOutcome = ({int threads, int coins, Gem? gem, bool revealed});
