class AppUsageSummary {
  const AppUsageSummary({
    required this.userId,
    required this.userName,
    required this.weekOpens,
    required this.activeDays,
    required this.topTabKey,
    this.tabCounts = const {},
    this.lastUsed,
    this.isAdmin = false,
  });

  final String userId;
  final String userName;
  final int weekOpens;
  final int activeDays;
  final String topTabKey;
  final Map<String, int> tabCounts;
  final DateTime? lastUsed;
  final bool isAdmin;

  int get totalTabTaps =>
      tabCounts.values.fold<int>(0, (sum, v) => sum + v);

  int get distinctTabs =>
      tabCounts.entries.where((e) => e.value > 0).length;

  /// 꾸준함·기능 다양성·탭 활동을 합친 활용도(0~100).
  int engagementScore(int periodDays) {
    if (periodDays <= 0) return 0;
    final consistency = (activeDays / periodDays).clamp(0.0, 1.0);
    final breadth = (distinctTabs / appUsageKnownTabKeys.length).clamp(0.0, 1.0);
    final activity = (totalTabTaps / (periodDays * 8)).clamp(0.0, 1.0);
    final opens = (weekOpens / (periodDays * 3)).clamp(0.0, 1.0);
    return ((consistency * 45) + (breadth * 25) + (activity * 20) + (opens * 10))
        .round()
        .clamp(0, 100);
  }
}

/// 기간 합산 인사이트 — 화면 요약·순위용.
class AppUsageInsights {
  const AppUsageInsights({
    required this.users,
    required this.periodDays,
    required this.totalOpens,
    required this.totalTabTaps,
    required this.featureRanking,
    required this.byUsage,
    required this.byEngagement,
  });

  final List<AppUsageSummary> users;
  final int periodDays;
  final int totalOpens;
  final int totalTabTaps;
  final List<({String key, int count})> featureRanking;
  final List<AppUsageSummary> byUsage;
  final List<AppUsageSummary> byEngagement;

  int get activeUserCount => users.length;

  double get avgOpensPerUser =>
      users.isEmpty ? 0 : totalOpens / users.length;

  double get avgActiveDays =>
      users.isEmpty
          ? 0
          : users.fold<int>(0, (s, u) => s + u.activeDays) / users.length;

  String get topFeatureKey =>
      featureRanking.isEmpty ? '' : featureRanking.first.key;

  AppUsageSummary? get topUsageUser =>
      byUsage.isEmpty ? null : byUsage.first;

  AppUsageSummary? get topEngagementUser =>
      byEngagement.isEmpty ? null : byEngagement.first;

  static AppUsageInsights fromUsers(
    List<AppUsageSummary> users, {
    required int periodDays,
  }) {
    final days = periodDays < 1 ? 1 : periodDays;
    final featureTotals = <String, int>{};
    var totalOpens = 0;
    var totalTabs = 0;

    for (final u in users) {
      totalOpens += u.weekOpens;
      totalTabs += u.totalTabTaps;
      for (final e in u.tabCounts.entries) {
        if (e.value <= 0) continue;
        featureTotals[e.key] = (featureTotals[e.key] ?? 0) + e.value;
      }
    }

    final featureRanking = featureTotals.entries
        .map((e) => (key: e.key, count: e.value))
        .toList()
      ..sort((a, b) {
        final byCount = b.count.compareTo(a.count);
        if (byCount != 0) return byCount;
        return a.key.compareTo(b.key);
      });

    final byUsage = List<AppUsageSummary>.from(users)
      ..sort((a, b) {
        final byOpens = b.weekOpens.compareTo(a.weekOpens);
        if (byOpens != 0) return byOpens;
        final byTabs = b.totalTabTaps.compareTo(a.totalTabTaps);
        if (byTabs != 0) return byTabs;
        return a.userName.compareTo(b.userName);
      });

    final byEngagement = List<AppUsageSummary>.from(users)
      ..sort((a, b) {
        final byScore =
            b.engagementScore(days).compareTo(a.engagementScore(days));
        if (byScore != 0) return byScore;
        final byDays = b.activeDays.compareTo(a.activeDays);
        if (byDays != 0) return byDays;
        return a.userName.compareTo(b.userName);
      });

    return AppUsageInsights(
      users: users,
      periodDays: days,
      totalOpens: totalOpens,
      totalTabTaps: totalTabs,
      featureRanking: featureRanking,
      byUsage: byUsage,
      byEngagement: byEngagement,
    );
  }
}

const List<String> appUsageKnownTabKeys = [
  'home',
  'reception',
  'issuance',
  'general_schedule',
  'menu',
  'settings',
];

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
