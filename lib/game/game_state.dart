import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'battle/battle_sim.dart';
import 'economy.dart';
import 'opponents.dart';
import 'case_box.dart';
import 'rating.dart';
import 'slipper.dart';
import 'slipper_kind.dart';

/// Единственный источник правды для UI. Сохраняется в SharedPreferences.
class GameState extends ChangeNotifier with WidgetsBindingObserver {
  GameState._(this._prefs);

  static const _key = 'save_v1';

  final SharedPreferences _prefs;
  Timer? _ticker;

  Slipper slipper = Slipper(name: 'Мой тапок');
  /// TODO: вернуть 50 перед релизом — сейчас для тестов.
  static const double startingThreads = 100000;

  /// Основная валюта: нитки. Тратятся на прокачку и кейсы.
  double threads = startingThreads;

  /// Вторая валюта: монеты. Пока не зарабатываются — задел на будущее.
  int coins = 0;

  /// Тапки в собственности: id вида → сколько штук. Дубликаты стакаются.
  Map<String, int> inventory = {SlipperCatalog.defaultId: 1};
  int rating = Rating.initial;
  int wins = 0;
  int losses = 0;

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
    slipper = slipper.copyWith(kindId: kindId);
    _refreshOpponents();
    _save();
    notifyListeners();
  }

  /// Проводит бой и сразу применяет результат. Возвращает результат
  /// для анимации — UI показывает его уже как «запись».
  BattleResult fight(Opponent opponent) {
    final result = BattleSim.run(slipper, opponent.slipper, seed: opponent.battleSeed);
    final won = result.playerWon;
    threads += Economy.battleReward(won: won, opponentPower: opponent.slipper.power);
    rating = max(100, rating + Rating.delta(mine: rating, theirs: opponent.rating, won: won));
    if (won) {
      wins++;
    } else {
      losses++;
    }
    _opponentSeed = Random().nextInt(1 << 31);
    _refreshOpponents();
    _save();
    notifyListeners();
    return result;
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
      final seen = DateTime.tryParse(json['lastSeen'] as String? ?? '');
      if (seen != null) {
        _collectOffline(DateTime.now().difference(seen));
      }
    } catch (e) {
      debugPrint('Save corrupted, starting fresh: $e');
    }
  }

  // --- Кейсы ------------------------------------------------------------

  bool canOpen(CaseType type) => threads >= type.price;

  /// Открывает кейс: списывает нитки, роллит вид и сразу кладёт его в
  /// инвентарь. Продать выпавшее можно потом — так дроп не теряется,
  /// если игрок закроет экран на середине анимации.
  SlipperKind? openCase(CaseType type) {
    if (!canOpen(type)) return null;
    threads -= type.price;
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
    inventory = {SlipperCatalog.defaultId: 1};
    rating = Rating.initial;
    wins = 0;
    losses = 0;
    _opponentSeed = 1;
    _refreshOpponents();
    notifyListeners();
  }
}
