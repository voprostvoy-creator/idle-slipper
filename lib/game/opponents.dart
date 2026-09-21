import 'dart:math';

import 'slipper.dart';
import 'slipper_kind.dart';

/// Заглушка «чужих тапков». Интерфейс такой же, каким будет серверный:
/// на вход — сила игрока и сид, на выход — список кандидатов.
class OpponentGenerator {
  OpponentGenerator._();

  static const _first = [
    'Шлёпа', 'Тапыч', 'Домашний', 'Резиновый', 'Бабушкин', 'Пляжный',
    'Банный', 'Гостевой', 'Левый', 'Правый', 'Меховой', 'Босс',
  ];
  static const _second = [
    'Гроза', 'Разрушитель', 'Мститель', 'Шлёпатель', 'Тихоня', 'Ураган',
    'Комнатный', 'Кара', 'Молот', 'Шершень', 'Пыльник', 'Уют',
  ];

  static List<Opponent> generate({
    required Slipper player,
    required int rating,
    required int seed,
    int count = 3,
  }) {
    final rng = Random(seed);
    final total = player.totalLevel;
    return List.generate(count, (i) {
      // Три ступени сложности: полегче, ровня, посильнее.
      final factor = switch (i) { 0 => 0.75, 1 => 1.0, _ => 1.3 };
      final targetTotal = max(4, (total * factor).round());

      // Случайные веса — у каждого соперника свой «билд».
      final weights = [for (final _ in Stat.values) 0.3 + rng.nextDouble()];
      final sum = weights.reduce((a, b) => a + b);
      final levels = <Stat, int>{};
      var assigned = 0;
      for (var k = 0; k < Stat.values.length; k++) {
        final lv = max(1, (targetTotal * weights[k] / sum).round());
        levels[Stat.values[k]] = lv;
        assigned += lv;
      }
      // Добираем/срезаем остаток на случайном стате, чтобы сумма сошлась.
      final fix = Stat.values[rng.nextInt(Stat.values.length)];
      levels[fix] = max(1, levels[fix]! + (targetTotal - assigned));

      final name = '${_first[rng.nextInt(_first.length)]} '
          '${_second[rng.nextInt(_second.length)]}';
      // Вид — случайный из каталога; позже здесь будет вес по редкости.
      final kind = SlipperCatalog.all[rng.nextInt(SlipperCatalog.all.length)];
      final slipper = Slipper(
        name: name,
        kindId: kind.id,
        levels: levels,
      );
      final ratingSpread = ((factor - 1) * 300).round();
      return Opponent(
        slipper: slipper,
        rating: max(100, rating + ratingSpread + rng.nextInt(80) - 40),
        battleSeed: rng.nextInt(1 << 31),
      );
    });
  }
}

class Opponent {
  const Opponent({
    required this.slipper,
    required this.rating,
    required this.battleSeed,
  });
  final Slipper slipper;
  final int rating;

  /// Сид боя фиксируется при подборе, поэтому переигрывать один и тот же
  /// бой бесполезно — исход уже предопределён.
  final int battleSeed;
}
