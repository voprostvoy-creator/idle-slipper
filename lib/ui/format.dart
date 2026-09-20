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
