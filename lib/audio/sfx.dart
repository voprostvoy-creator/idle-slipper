import 'dart:async';
import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Звуки в бою: шлепок тапка по сопернику, хлопок при убийстве жука.
/// У каждого звука свой пул плееров — одновременные удары не обрывают
/// друг друга. Громкость хранится на телефоне.
class Sfx extends ChangeNotifier {
  Sfx._();
  static final instance = Sfx._();

  static const _volumeKey = 'sfx_volume';
  static const _hits = ['sfx/hit1.ogg', 'sfx/hit2.ogg', 'sfx/hit3.ogg'];
  static const _kills = ['sfx/kill1.ogg', 'sfx/kill2.ogg'];

  final _pools = <String, AudioPool>{};
  final _rng = Random();
  final _last = <String, DateTime>{};
  bool _started = false;
  bool _starting = false;

  double _volume = 0.8;
  double get volume => _volume;

  Future<void> start() async {
    if (_started || _starting) return;
    _starting = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      _volume = prefs.getDouble(_volumeKey) ?? _volume;
      for (final a in [..._hits, ..._kills]) {
        _pools[a] = await AudioPool.create(
          source: AssetSource(a),
          minPlayers: 1,
          maxPlayers: 3,
          // Не забирать звук у музыки — звучат вместе.
          audioContext: AudioContextConfig(
            focus: AudioContextConfigFocus.mixWithOthers,
          ).build(),
          // Короткие звуки на Android — через быстрый SoundPool.
          playerMode: kIsWeb ? PlayerMode.mediaPlayer : PlayerMode.lowLatency,
        );
      }
      _started = true;
    } catch (e) {
      debugPrint('Sfx: $e');
    } finally {
      _starting = false;
    }
  }

  Future<void> setVolume(double v) async {
    _volume = v.clamp(0.0, 1.0);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_volumeKey, _volume);
  }

  /// Удар тапка; крит — чуть громче.
  void hit({bool crit = false}) =>
      _play('hit', _hits, crit ? 0.75 : 0.5, gap: 40);

  /// Жук убит. Если гибнут пачкой — не чаще раза в 70 мс.
  void kill() => _play('kill', _kills, 0.55, gap: 70);

  void _play(
    String group,
    List<String> assets,
    double level, {
    required int gap,
  }) {
    if (!_started || _volume == 0) return;
    final now = DateTime.now();
    final last = _last[group];
    if (last != null && now.difference(last).inMilliseconds < gap) return;
    _last[group] = now;
    final pool = _pools[assets[_rng.nextInt(assets.length)]];
    if (pool == null) return;
    pool
        .start(volume: level * _volume)
        .then((stop) {
          // В быстром режиме плеер сам не освобождается — вернём его в пул.
          if (!kIsWeb) Timer(const Duration(milliseconds: 700), stop);
        })
        .catchError((Object e) {
          debugPrint('Sfx: $e');
        });
  }
}
