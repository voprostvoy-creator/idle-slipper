import 'dart:math';

/// Простой ELO. K=32 — быстрый рост в начале.
class Rating {
  Rating._();

  static const int initial = 1000;
  static const double _k = 32;

  static int delta({required int mine, required int theirs, required bool won}) {
    final expected = 1 / (1 + pow(10, (theirs - mine) / 400));
    final actual = won ? 1.0 : 0.0;
    return (_k * (actual - expected)).round();
  }
}
