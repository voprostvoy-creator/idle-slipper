/// Короткий формат чисел для монет: 1.2K, 3.4M.
String fmtNum(num v) {
  if (v < 1000) return v.toStringAsFixed(v is int || v >= 100 ? 0 : 1);
  if (v < 1e6) return '${(v / 1e3).toStringAsFixed(1)}K';
  if (v < 1e9) return '${(v / 1e6).toStringAsFixed(1)}M';
  return '${(v / 1e9).toStringAsFixed(1)}B';
}

String fmtDuration(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes % 60;
  if (h > 0) return '$h ч $m мин';
  if (m > 0) return '$m мин';
  return '${d.inSeconds} с';
}

/// «1 ход», «3 хода», «5 ходов».
String fmtTurns(int n) {
  final tail = n % 100 >= 11 && n % 100 <= 14 ? 0 : n % 10;
  final word = switch (tail) {
    1 => 'ход',
    2 || 3 || 4 => 'хода',
    _ => 'ходов',
  };
  return '$n $word';
}

/// Таймер «1:05:09» или «4:09» — для обратных отсчётов.
String fmtClock(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return h > 0 ? '$h:$m:$s' : '${d.inMinutes}:$s';
}
