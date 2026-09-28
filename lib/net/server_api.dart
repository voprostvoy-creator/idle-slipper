import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../game/slipper.dart';

/// Строка рейтинга с сервера: место, очки и снимок тапка.
class BoardEntry {
  BoardEntry({
    required this.place,
    required this.id,
    required this.rating,
    required this.slipper,
    this.bot = false,
  });

  final int place;
  final String id;
  final int rating;
  final Slipper slipper;
  final bool bot;

  factory BoardEntry.fromJson(Map<String, dynamic> j) => BoardEntry(
        place: (j['place'] as num?)?.toInt() ?? 0,
        id: j['id'] as String,
        rating: (j['rating'] as num).toInt(),
        slipper: Slipper.fromJson((j['slipper'] as Map).cast<String, dynamic>()),
        bot: j['bot'] as bool? ?? false,
      );
}

/// Рейтинг арены с сервера.
class ArenaBoard {
  ArenaBoard({required this.total, required this.me, required this.top});
  final int total;
  final BoardEntry me;
  final List<BoardEntry> top;
}

/// Итог боя от сервера: сид, соперник и новые очки.
class ServerFight {
  ServerFight({
    required this.seed,
    required this.won,
    required this.opponent,
    required this.ratingBefore,
    required this.rating,
    required this.threads,
  });

  final int seed;
  final bool won;
  final BoardEntry opponent;
  final int ratingBefore;
  final int rating;
  final int threads;
}

class ServerException implements Exception {
  ServerException(this.message, [this.status]);
  final String message;

  /// HTTP-код ответа, если сервер ответил.
  final int? status;

  @override
  String toString() => message;
}

/// Клиент сервера игры. Аккаунт создаётся только явно — [register] или
/// [login] со страницы входа; id и токен хранятся на телефоне.
class ServerApi {
  ServerApi(this._prefs, {http.Client? client, this.enabled = true})
      : _http = client ?? http.Client();

  /// Сервер отключён — например, в тестах: запросы не отправляются.
  ServerApi.disabled(SharedPreferences prefs) : this(prefs, enabled: false);

  static const baseUrl = 'https://bbau56a0vt2451biufi5.containers.yandexcloud.net';
  static const _authKey = 'server_auth';
  static const _timeout = Duration(seconds: 12);

  final SharedPreferences _prefs;
  final http.Client _http;
  final bool enabled;

  String? _auth;

  /// Логин и пароль этого телефона; null — ещё не зарегистрирован.
  ({String login, String password})? get credentials {
    final auth = _auth ?? _prefs.getString(_authKey);
    final parts = auth?.split(':');
    if (parts == null || parts.length != 2) return null;
    return (login: parts[0], password: parts[1]);
  }

  bool get hasAccount => credentials != null;

  String _requireAuth() {
    _auth ??= _prefs.getString(_authKey);
    if (_auth == null) throw ServerException('Нет аккаунта');
    return _auth!;
  }

  /// Создать новый аккаунт: сервер придумывает логин и пароль.
  Future<({String login, String password})> register() async {
    final j = await _send('POST', '/auth', auth: false);
    final auth = '${j['id']}:${j['token']}';
    await _prefs.setString(_authKey, auth);
    _auth = auth;
    return credentials!;
  }

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Map<String, dynamic>? body,
    bool auth = true,
  }) async {
    if (!enabled) throw ServerException('Сервер отключён');
    final headers = {
      'content-type': 'application/json',
      if (auth) 'x-slipper-auth': _requireAuth(),
    };
    final req = http.Request(method, Uri.parse('$baseUrl$path'))
      ..headers.addAll(headers)
      ..body = body == null ? '' : jsonEncode(body);
    final http.Response res;
    try {
      res = await http.Response.fromStream(await _http.send(req).timeout(_timeout));
    } on TimeoutException {
      throw ServerException('Сервер не отвечает');
    } catch (_) {
      throw ServerException('Нет связи с сервером');
    }
    if (res.statusCode != 200) {
      throw ServerException('Ошибка сервера (${res.statusCode})', res.statusCode);
    }
    return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
  }

  /// Вход в другой аккаунт по логину и паролю. Возвращает облачное
  /// сохранение этого аккаунта (null — он ещё ни разу не сохранялся).
  Future<Map<String, dynamic>?> login(String login, String password) async {
    final Map<String, dynamic> j;
    try {
      j = await _send('POST', '/login',
          body: {'login': login.trim(), 'password': password.trim()}, auth: false);
    } on ServerException catch (e) {
      if (e.status == 401) throw ServerException('Неверный логин или пароль', 401);
      if (e.status == 429) throw ServerException('Слишком много попыток — попробуй позже', 429);
      rethrow;
    }
    final auth = '${j['id']}:${j['token']}';
    await _prefs.setString(_authKey, auth);
    _auth = auth;
    return (j['save'] as Map?)?.cast<String, dynamic>();
  }

  /// Облачная копия сохранения и снимок тапка для соперников.
  /// Возвращает очки арены по версии сервера.
  Future<int> pushSave(Map<String, dynamic> save, Map<String, dynamic> snapshot) async {
    final j = await _send('PUT', '/save', body: {'save': save, 'snapshot': snapshot});
    return (j['rating'] as num).toInt();
  }

  Future<ArenaBoard> leaderboard({int limit = 50}) async {
    final j = await _send('GET', '/leaderboard?limit=$limit');
    return ArenaBoard(
      total: (j['total'] as num).toInt(),
      me: BoardEntry.fromJson((j['me'] as Map).cast<String, dynamic>()),
      top: [for (final e in j['top'] as List) BoardEntry.fromJson((e as Map).cast<String, dynamic>())],
    );
  }

  Future<ServerFight> fight() async {
    final j = await _send('POST', '/arena/fight');
    final o = (j['opponent'] as Map).cast<String, dynamic>();
    return ServerFight(
      seed: (j['seed'] as num).toInt(),
      won: j['won'] as bool,
      opponent: BoardEntry.fromJson(o),
      ratingBefore: (j['ratingBefore'] as num).toInt(),
      rating: (j['rating'] as num).toInt(),
      threads: (j['threads'] as num).toInt(),
    );
  }
}
