class TodayStats {
  TodayStats({
    this.todayCount,
    this.incompleteCount,
    this.completedToday,
    this.raw = const {},
  });

  final int? todayCount;
  final int? incompleteCount;
  final int? completedToday;
  final Map<String, dynamic> raw;

  factory TodayStats.fromJson(Map<String, dynamic> json) {
    int? pickInt(List<String> keys) {
      for (final k in keys) {
        final v = json[k];
        if (v is int) return v;
        if (v is num) return v.toInt();
      }
      return null;
    }

    return TodayStats(
      todayCount: pickInt(const [
        'today_count',
        'todayCount',
        'today',
        'calls_today',
      ]),
      incompleteCount: pickInt(const [
        'incomplete_count',
        'incompleteCount',
        'pending',
        'missed',
        'incomplete',
      ]),
      completedToday: pickInt(const [
        'completed_today',
        'completedToday',
      ]),
      raw: Map<String, dynamic>.from(json),
    );
  }
}
