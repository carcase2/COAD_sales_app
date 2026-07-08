class AppUsageSummary {
  const AppUsageSummary({
    required this.userId,
    required this.userName,
    required this.weekOpens,
    required this.activeDays,
    required this.topTabKey,
    this.lastUsed,
  });

  final String userId;
  final String userName;
  final int weekOpens;
  final int activeDays;
  final String topTabKey;
  final DateTime? lastUsed;
}

String appUsageTabLabel(String key) {
  switch (key) {
    case 'home':
      return '홈';
    case 'reception':
      return '접수';
    case 'issuance':
      return '발급';
    case 'general_schedule':
      return '본사일반';
    case 'menu':
      return '메뉴';
    case 'settings':
      return '설정';
    default:
      return key.isEmpty ? '—' : key;
  }
}

String topTabKeyFromCounts(Map<String, int> counts) {
  if (counts.isEmpty) return '';
  final sorted = counts.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return sorted.first.key;
}
