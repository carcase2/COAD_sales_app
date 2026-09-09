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

  int get totalTabTaps => tabCounts.values.fold<int>(0, (sum, v) => sum + v);

  int get distinctTabs => tabCounts.entries.where((e) => e.value > 0).length;

  /// 꾸준함·기능 다양성·탭 활동을 합친 활용도(0~100).
  int engagementScore(int periodDays) {
    if (periodDays <= 0) return 0;
    final consistency = (activeDays / periodDays).clamp(0.0, 1.0);
    final breadth = (distinctTabs / appUsageKnownTabKeys.length).clamp(
      0.0,
      1.0,
    );
    final activity = (totalTabTaps / (periodDays * 8)).clamp(0.0, 1.0);
    final opens = (weekOpens / (periodDays * 3)).clamp(0.0, 1.0);
    return ((consistency * 45) +
            (breadth * 25) +
            (activity * 20) +
            (opens * 10))
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

  double get avgOpensPerUser => users.isEmpty ? 0 : totalOpens / users.length;

  double get avgActiveDays => users.isEmpty
      ? 0
      : users.fold<int>(0, (s, u) => s + u.activeDays) / users.length;

  String get topFeatureKey =>
      featureRanking.isEmpty ? '' : featureRanking.first.key;

  AppUsageSummary? get topUsageUser => byUsage.isEmpty ? null : byUsage.first;

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

    final featureRanking =
        featureTotals.entries.map((e) => (key: e.key, count: e.value)).toList()
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
        final byScore = b
            .engagementScore(days)
            .compareTo(a.engagementScore(days));
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
  'quoter',
  'standard_unit_price',
  'quoter_log',
  'general_schedule',
  'daegu_schedule',
  'customer_support',
  'mail',
  'menu',
  'settings',
  'checksheet',
  'checksheet_search',
  'checksheet_view',
  'checksheet_download',
  'install_after_photos',
  'install_after',
  'install_after_search',
  'install_after_view',
  'install_after_download',
];

/// 체크시트 기능 사용 집계 키 (메뉴 진입 제외·포함 모두).
const List<String> checksheetUsageKeys = [
  'checksheet',
  'checksheet_search',
  'checksheet_view',
  'checksheet_download',
];

String appUsageTabLabel(String key) {
  switch (key) {
    case 'home':
      return '홈';
    case 'reception':
      return '접수';
    case 'issuance':
      return '발급';
    case 'quoter':
      return '견적';
    case 'standard_unit_price':
      return '표준단가';
    case 'quoter_log':
      return '견적 로그';
    case 'general_schedule':
      return '본사일반';
    case 'daegu_schedule':
      return '대구지사';
    case 'customer_support':
      return '고객지원팀';
    case 'mail':
      return '메일 발송';
    case 'menu':
      return '메뉴';
    case 'settings':
      return '설정';
    case 'checksheet':
      return '체크시트 열기';
    case 'checksheet_search':
      return '체크시트 검색';
    case 'checksheet_view':
      return '체크시트 열람';
    case 'checksheet_download':
      return '체크시트 저장';
    case 'install_after_photos':
    case 'install_after':
      return '시공 사진 열기';
    case 'install_after_search':
      return '시공 사진 검색';
    case 'install_after_view':
      return '시공 사진 열람';
    case 'install_after_download':
      return '시공 사진 저장';
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
