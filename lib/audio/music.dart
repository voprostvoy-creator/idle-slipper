import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Фоновая музыка: весёлая в меню, в бою — тишина, только звуки ударов. Треки сменяются плавно,
/// когда игра свёрнута — музыка на паузе. Громкость хранится на телефоне.
class Music extends ChangeNotifier with WidgetsBindingObserver {
  Music._();
  static final instance = Music._();

  static const _volumeKey = 'music_volume';
  static const _fade = Duration(milliseconds: 700);
  static const _fadeStep = Duration(milliseconds: 50);

  late final _menu = _Track('music/menu.mp3');

  bool _started = false;
  bool _starting = false;
  bool _background = false;

  /// Сколько боёв открыто сейчас: бой поверх боя не сбивает трек.
  int _battles = 0;

  double _volume = 0.6;
  double get volume => _volume;

  bool get _inBattle => _battles > 0;

  /// Вызывается при запуске и при каждом касании: в браузере звук
  /// разрешён только после первого касания.
  Future<void> start() async {
    if (_started) {
      if (!_menu.playing) _sync();
      return;
    }
    if (_starting) return;
    _starting = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      _volume = prefs.getDouble(_volumeKey) ?? _volume;
      // Два плеера (меню и бой) не должны выключать друг друга
      // и музыку других приложений: звучат вместе.
      await AudioPlayer.global.setAudioContext(
        AudioContextConfig(
          focus: AudioContextConfigFocus.mixWithOthers,
        ).build(),
      );
      await _menu.init();
      WidgetsBinding.instance.addObserver(this);
      _started = true;
      _sync();
    } catch (e) {
      // Без звука игра всё равно работает.
      debugPrint('Music: $e');
    } finally {
      _starting = false;
    }
  }

  void enterBattle() {
    _battles++;
    _sync();
  }

  void leaveBattle() {
    if (_battles > 0) _battles--;
    _sync();
  }

  Future<void> setVolume(double v) async {
    _volume = v.clamp(0.0, 1.0);
    if (_started) {
      if (_volume == 0) {
        _menu.fadeTo(0, stop: true);
      } else if (_menu.playing) {
        _menu.setNow(_volume);
      } else {
        _sync();
      }
    }
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_volumeKey, _volume);
  }

  /// В меню музыка плавно вверх, в бою — плавно вниз и пауза.
  void _sync() {
    if (!_started || _background) return;
    if (_inBattle || _volume == 0) {
      _menu.fadeTo(0, stop: true);
    } else {
      _menu.fadeTo(_volume);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final bg = state != AppLifecycleState.resumed;
    if (bg == _background) return;
    _background = bg;
    if (bg) {
      _menu.pauseNow();
    } else {
      _sync();
    }
  }
}

/// Один зацикленный трек со своим плеером и плавной громкостью.
class _Track {
  _Track(this.asset);

  final String asset;

  final _player = AudioPlayer();
  double _vol = 0;
  Timer? _timer;
  bool playing = false;

  Future<void> init() async {
    await _player.setReleaseMode(ReleaseMode.loop);
    await _player.setVolume(0);
    await _player.setSource(AssetSource(asset));
  }

  void setNow(double v) {
    _timer?.cancel();
    _vol = v;
    _player.setVolume(_vol);
  }

  void pauseNow() {
    _timer?.cancel();
    if (playing) _player.pause();
    playing = false;
  }

  /// Плавно к громкости [to]; со [stop] — в конце пауза (или стоп).
  void fadeTo(double level, {bool stop = false}) {
    _timer?.cancel();
    final to = level;
    if (to > 0 && !playing) {
      playing = true;
      _player.resume().catchError((Object e) {
        // В браузере до первого касания — повторим при касании.
        playing = false;
      });
    }
    if (!playing) return;
    final steps = Music._fade.inMilliseconds ~/ Music._fadeStep.inMilliseconds;
    final from = _vol;
    var i = 0;
    _timer = Timer.periodic(Music._fadeStep, (t) {
      i++;
      _vol = from + (to - from) * i / steps;
      _player.setVolume(_vol.clamp(0.0, 1.0));
      if (i >= steps) {
        t.cancel();
        if (stop && to == 0) {
          playing = false;
          // Пауза, а не стоп: после боя мелодия продолжится с того же места.
          _player.pause();
        }
      }
    });
  }
}
