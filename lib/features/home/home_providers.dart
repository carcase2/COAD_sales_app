import 'dart:async';

import 'package:coad_customer_calls/core/utils/date_seoul.dart';
import 'package:coad_customer_calls/data/sales_calls_repository.dart';
import 'package:coad_customer_calls/data/temp_manager_logic.dart';
import 'package:coad_customer_calls/features/sales_calls/master_data_provider.dart';
import 'package:coad_customer_calls/models/sales_call.dart';
import 'package:coad_customer_calls/models/temp_manager_override.dart';
import 'package:coad_customer_calls/models/today_stats.dart';
import 'package:coad_customer_calls/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';

/// 흐름 탭 · 미통화 0건 안내(설정) — `SettingsScreen`·`HomeHubScreen` 공유.
const String homeFlowUncalledPopupPrefKey = 'home_flow_no_uncalled_popup_v2';

/// 처리할 미통화 조회 기간 — 접수일 무관, 최근 N일.
const int pendingUncalledLookbackDays = 60;

String pendingUncalledFromYmd(String anchorYmd) =>
    addDaysToYmd(anchorYmd, -pendingUncalledLookbackDays);

/// 접수일 — `call_date`/`call_time`·`created_at`을 서울 기준으로 정규화.
String salesCallReceptionYmd(SalesCall call) {
  return salesCallReceptionYmdForCall(
    callDate: call.callDate,
    callTime: call.callTime,
    createdAt: call.createdAt,
  );
}

typedef PendingUncalledSummary = ({
  int total,
  int todayCount,
  int carriedOverCount,
  int userCount,
});

PendingUncalledSummary summarizePendingUncalled({
  required List<SalesCall> calls,
  required String todayYmd,
  required List<TempManagerOverride> overrides,
  String? loginName,
}) {
  final me = loginName?.trim() ?? '';
  var todayCount = 0;
  var carried = 0;
  var userCount = 0;
  final now = DateTime.now();
  for (final call in calls) {
    final ymd = salesCallReceptionYmd(call);
    if (ymd == todayYmd) {
      todayCount++;
    } else {
      carried++;
    }
    if (me.isNotEmpty &&
        displayAssigneeForCall(call, overrides, now) == me) {
      userCount++;
    }
  }
  return (
    total: calls.length,
    todayCount: todayCount,
    carriedOverCount: carried,
    userCount: userCount,
  );
}

/// 홈 통합 화면의 [흐름 | 미통화 | 달력] 구역 — `HomeHubScreen`이 소비.
enum HomeHubSection { flow, incomplete, calendar }

/// 흐름 탭 상단 일/주/월 — 미통화·달력과 공유.
enum HubNavStep { day, week, month }

final homeHubNavStepProvider =
    StateProvider<HubNavStep>((ref) => HubNavStep.day);

final homeHubFlowAnchorYmdProvider =
    StateProvider<String>((ref) => todayYmdSeoul());

typedef ConsultationLaunchTarget = ({
  HomeHubSection section,
  CalendarFormat calendarFormat,
});

final pendingConsultationLaunchProvider =
    StateProvider<ConsultationLaunchTarget?>((ref) => null);

/// [MainTabScreen]이 홈(탭 0)으로 이동할 때마다 증가. [HomeHubScreen]이 업무 흐름을 **일·금일**로 맞춤.
final homeHubFlowResetTickProvider = StateProvider<int>((ref) => 0);

/// 홈으로 이동한 뒤 지정 구역(흐름·미통화·달력)을 연다.
void requestHomeHubSection(
  WidgetRef ref,
  HomeHubSection section, {
  CalendarFormat calendarFormat = CalendarFormat.week,
}) {
  if (section == HomeHubSection.calendar ||
      section == HomeHubSection.incomplete) {
    unawaited(
      ref.read(
        incompleteBreakdownCallsProvider((
          period: IncompleteSummaryPeriod.pending,
          anchorYmd: todayYmdSeoul(),
        )).future,
      ),
    );
  }
  ref.read(pendingConsultationLaunchProvider.notifier).state = (
    section: section,
    calendarFormat: calendarFormat,
  );
}

/// 열기 메뉴 등: 홈 **달력** 구역, **주간 달력** 형식.
void requestConsultationCalendarWeekNavigation(WidgetRef ref) {
  requestHomeHubSection(
    ref,
    HomeHubSection.calendar,
    calendarFormat: CalendarFormat.week,
  );
}

final todayCallsContentProvider = FutureProvider<List<SalesCall>>((ref) async {
  final repo = ref.watch(salesCallsRepositoryProvider);
  return repo.fetchCalls(date: todayYmdSeoul(), limit: 100, includeCallHistory: false);
});

/// 담당자별 건수 한 줄 (팔로우·미통화 등 공통)
typedef AssigneeCountRow = ({String assignee, int count});

class AssigneeOverview {
  const AssigneeOverview({required this.total, required this.byAssignee});

  final int total;
  final List<AssigneeCountRow> byAssignee;
}

class AssigneeQualityMetric {
  const AssigneeQualityMetric({
    required this.assignee,
    required this.total,
    required this.uncalled,
    required this.uncalledRate,
    required this.avgFirstResponseMinutes,
  });

  final String assignee;
  final int total;
  final int uncalled;
  final double uncalledRate;
  final double? avgFirstResponseMinutes;
}

class CallQualityOverview {
  const CallQualityOverview({
    required this.total,
    required this.uncalled,
    required this.uncalledRate,
    required this.avgFirstResponseMinutes,
    required this.byAssignee,
  });

  final int total;
  final int uncalled;
  final double uncalledRate;
  final double? avgFirstResponseMinutes;
  final List<AssigneeQualityMetric> byAssignee;
}

List<AssigneeCountRow> _groupByAssignee(List<SalesCall> rows) {
  final Map<String, int> counts = {};
  for (final c in rows) {
    final a = (c.assignedTo == null || c.assignedTo!.isEmpty) ? '미지정' : c.assignedTo!;
    counts[a] = (counts[a] ?? 0) + 1;
  }
  final list = counts.entries.map((e) => (assignee: e.key, count: e.value)).toList();
  list.sort((a, b) {
    if (a.assignee == '미지정') return 1;
    if (b.assignee == '미지정') return -1;
    final c = b.count.compareTo(a.count);
    if (c != 0) return c;
    return a.assignee.compareTo(b.assignee);
  });
  return list;
}

DateTime? _toLocalDateTime(String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;
  final dt = DateTime.tryParse(raw.trim());
  return dt?.toLocal();
}

double? _firstResponseMinutes(SalesCall c) {
  final created = _toLocalDateTime(c.createdAt);
  if (created == null || c.callHistory.isEmpty) return null;
  DateTime? firstHistoryAt;
  for (final h in c.callHistory) {
    final at = _toLocalDateTime(h['created_at']?.toString());
    if (at == null) continue;
    if (firstHistoryAt == null || at.isBefore(firstHistoryAt)) {
      firstHistoryAt = at;
    }
  }
  if (firstHistoryAt == null) return null;
  final diff = firstHistoryAt.difference(created).inMinutes.toDouble();
  if (diff.isNegative) return null;
  return diff;
}

CallQualityOverview _buildCallQualityOverview(List<SalesCall> rows) {
  final Map<String, List<SalesCall>> byAssignee = {};
  for (final c in rows) {
    final a = (c.assignedTo == null || c.assignedTo!.isEmpty) ? '미지정' : c.assignedTo!;
    byAssignee.putIfAbsent(a, () => []).add(c);
  }

  AssigneeQualityMetric metricFor(String assignee, List<SalesCall> calls) {
    final total = calls.length;
    final uncalled = calls.where((c) => c.isMissed).length;
    final respondedMinutes = <double>[];
    for (final c in calls) {
      final minutes = _firstResponseMinutes(c);
      if (minutes != null) respondedMinutes.add(minutes);
    }
    final avg = respondedMinutes.isEmpty
        ? null
        : respondedMinutes.reduce((a, b) => a + b) / respondedMinutes.length;
    return AssigneeQualityMetric(
      assignee: assignee,
      total: total,
      uncalled: uncalled,
      uncalledRate: total == 0 ? 0 : uncalled / total,
      avgFirstResponseMinutes: avg,
    );
  }

  final totalMetric = metricFor('전체', rows);
  final assigneeRows = byAssignee.entries
      .map((e) => metricFor(e.key, e.value))
      .toList()
    ..sort((a, b) {
      final c = b.total.compareTo(a.total);
      if (c != 0) return c;
      return a.assignee.compareTo(b.assignee);
    });

  return CallQualityOverview(
    total: totalMetric.total,
    uncalled: totalMetric.uncalled,
    uncalledRate: totalMetric.uncalledRate,
    avgFirstResponseMinutes: totalMetric.avgFirstResponseMinutes,
    byAssignee: assigneeRows,
  );
}

/// 홈 허브 흐름 카드 구간 — 하루 / 금주 / 금월.
enum HubPeriod { day, week, month }

typedef HubPeriodKey = ({HubPeriod period, String anchorYmd});

HubPeriodKey hubPeriodKeyFromNav(HubNavStep step, String anchorYmd) => (
      period: switch (step) {
        HubNavStep.day => HubPeriod.day,
        HubNavStep.week => HubPeriod.week,
        HubNavStep.month => HubPeriod.month,
      },
      anchorYmd: anchorYmd,
    );

/// 담당자 칩·달력 범례용 — Material 톤에 맞춘 팔레트.
List<Color> hubAssigneeChartColors(ColorScheme scheme) => [
      scheme.primary,
      scheme.secondary,
      scheme.tertiary,
      scheme.error,
      Color.lerp(scheme.primary, scheme.tertiary, 0.5)!,
      Color.lerp(scheme.secondary, scheme.error, 0.35)!,
    ];

Color hubAssigneeColor(
  ColorScheme scheme,
  String assignee, {
  required Map<String, Color> cache,
  required List<String> orderedAssignees,
}) {
  if (assignee == '전체') return scheme.onSurfaceVariant;
  if (assignee == '미지정') return scheme.outline;
  final cached = cache[assignee];
  if (cached != null) return cached;
  final palette = hubAssigneeChartColors(scheme);
  final idx = orderedAssignees.indexOf(assignee);
  final color = palette[idx < 0 ? assignee.hashCode.abs() % palette.length : idx % palette.length];
  cache[assignee] = color;
  return color;
}

/// 접수 목록에서 미통화만 추출 — 별도 API 호출 없이 `isMissed`로 필터.
List<SalesCall> uncalledCallsFrom(List<SalesCall> calls) =>
    calls.where((c) => c.isMissed).toList();

Future<List<SalesCall>> _fetchHubPeriodReceptionCalls(
  SalesCallsRepository repo,
  HubPeriodKey key,
) async {
  switch (key.period) {
    case HubPeriod.day:
      return repo.fetchCallsAllPages(
        date: key.anchorYmd,
        includeCallHistory: true,
        callHistoryQualityOnly: true,
      );
    case HubPeriod.week:
      final range = seoulWeekRangeContaining(key.anchorYmd);
      return repo.fetchCallsAllPages(
        dateRangeStart: range.$1,
        dateRangeEndInclusive: range.$2,
        includeCallHistory: true,
        callHistoryQualityOnly: true,
      );
    case HubPeriod.month:
      final range = seoulMonthRangeContaining(key.anchorYmd);
      return repo.fetchCallsAllPages(
        dateRangeStart: range.$1,
        dateRangeEndInclusive: range.$2,
        includeCallHistory: true,
        callHistoryQualityOnly: true,
      );
  }
}

/// 금일(단일 일자) 접수 목록 1회 — 흐름 bundle·미통화 breakdown이 공유.
final hubDayReceptionCallsProvider = FutureProvider.autoDispose
    .family<List<SalesCall>, String>((ref, anchorYmd) async {
  final repo = ref.watch(salesCallsRepositoryProvider);
  return repo.fetchCallsAllPages(
    date: anchorYmd,
    includeCallHistory: true,
    callHistoryQualityOnly: true,
  );
});

/// 금일 미통화 — [hubDayReceptionCallsProvider] 결과에서 파생(추가 네트워크 없음).
final hubDayUncalledCallsProvider = FutureProvider.autoDispose
    .family<List<SalesCall>, String>((ref, anchorYmd) async {
  final calls = await ref.watch(hubDayReceptionCallsProvider(anchorYmd).future);
  return uncalledCallsFrom(calls);
});

/// 흐름 기간별 접수 목록 1회 조회 → 품질·미통화 집계에 재사용.
class HubPeriodReceptionBundle {
  HubPeriodReceptionBundle(this.calls, {required List<SalesCall> uncalledCalls})
      : uncalledCalls = uncalledCalls;

  final List<SalesCall> calls;
  final List<SalesCall> uncalledCalls;

  late final CallQualityOverview quality = _buildCallQualityOverview(calls);

  late final AssigneeOverview uncalledOverview = AssigneeOverview(
    total: uncalledCalls.length,
    byAssignee: _groupByAssignee(uncalledCalls),
  );
}

final hubPeriodReceptionBundleProvider = FutureProvider.autoDispose
    .family<HubPeriodReceptionBundle, HubPeriodKey>((ref, key) async {
  final repo = ref.watch(salesCallsRepositoryProvider);
  final calls = key.period == HubPeriod.day
      ? await ref.watch(hubDayReceptionCallsProvider(key.anchorYmd).future)
      : await _fetchHubPeriodReceptionCalls(repo, key);
  return HubPeriodReceptionBundle(
    calls,
    uncalledCalls: uncalledCallsFrom(calls),
  );
});

final hubPeriodStatsProvider = FutureProvider.autoDispose
    .family<TodayStats, HubPeriodKey>((ref, key) async {
  final repo = ref.watch(salesCallsRepositoryProvider);
  switch (key.period) {
    case HubPeriod.day:
      return repo.fetchStatsForDate(key.anchorYmd);
    case HubPeriod.week:
      final range = seoulWeekRangeContaining(key.anchorYmd);
      return repo.fetchStatsForDateRange(range.$1, range.$2);
    case HubPeriod.month:
      final range = seoulMonthRangeContaining(key.anchorYmd);
      return repo.fetchStatsForDateRange(range.$1, range.$2);
  }
});

final hubPeriodFollowOverviewProvider = FutureProvider.autoDispose
    .family<AssigneeOverview, HubPeriodKey>((ref, key) async {
  final repo = ref.watch(salesCallsRepositoryProvider);
  switch (key.period) {
    case HubPeriod.day:
      final rows = await repo.fetchCallsAllPages(
        followDate: key.anchorYmd,
        incompleteOnly: true,
        excludeSimpleInquiries: true,
        includeCallHistory: false,
      );
      return AssigneeOverview(
        total: rows.length,
        byAssignee: _groupByAssignee(rows),
      );
    case HubPeriod.week:
      final range = seoulWeekRangeContaining(key.anchorYmd);
      final rows = await repo.fetchCallsAllPages(
        followRangeStart: range.$1,
        followRangeEndInclusive: range.$2,
        incompleteOnly: true,
        excludeSimpleInquiries: true,
        includeCallHistory: false,
      );
      return AssigneeOverview(
        total: rows.length,
        byAssignee: _groupByAssignee(rows),
      );
    case HubPeriod.month:
      final range = seoulMonthRangeContaining(key.anchorYmd);
      final rows = await repo.fetchCallsAllPages(
        followRangeStart: range.$1,
        followRangeEndInclusive: range.$2,
        incompleteOnly: true,
        excludeSimpleInquiries: true,
        includeCallHistory: false,
      );
      return AssigneeOverview(
        total: rows.length,
        byAssignee: _groupByAssignee(rows),
      );
  }
});

final hubPeriodQualityOverviewProvider = FutureProvider.autoDispose
    .family<CallQualityOverview, HubPeriodKey>((ref, key) async {
  final bundle = await ref.watch(hubPeriodReceptionBundleProvider(key).future);
  return bundle.quality;
});

/// 흐름 탭 기간 데이터를 병렬로 미리 불러 워터폴 대기를 줄임.
void prefetchHubPeriodFlow(
  WidgetRef ref,
  HubPeriodKey key, {
  HubPeriodKey? previousKey,
}) {
  final futures = <Future<Object?>>[
    ref.read(hubPeriodReceptionBundleProvider(key).future),
    ref.read(hubPeriodFollowOverviewProvider(key).future),
    ref.read(hubPeriodStatsProvider(key).future),
  ];
  if (previousKey != null) {
    futures.add(ref.read(hubPeriodStatsProvider(previousKey).future));
  }
  unawaited(Future.wait(futures).catchError((_) => <Object?>[]));
}

/// 미통화 탭·흐름 카드 탭 시 — 화면 숫자와 무관하게 서버에서 다시 조회.
Future<HubPeriodReceptionBundle> refreshHubPeriodUncalledBundle(
  WidgetRef ref,
  HubPeriodKey key,
) async {
  ref.invalidate(hubPeriodReceptionBundleProvider(key));
  ref.invalidate(hubPeriodStatsProvider(key));
  ref.invalidate(hubSegmentIncompleteBadgeProvider);
  if (key.period == HubPeriod.day) {
    ref.invalidate(hubDayReceptionCallsProvider(key.anchorYmd));
    ref.invalidate(hubDayUncalledCallsProvider(key.anchorYmd));
  }
  await Future.wait([
    ref.read(hubPeriodReceptionBundleProvider(key).future),
    ref.read(hubPeriodStatsProvider(key).future),
  ]);
  return ref.read(hubPeriodReceptionBundleProvider(key).future);
}

/// 미통화 그리드 담당자 탭 시 — breakdown 목록 최신화.
Future<List<SalesCall>> refreshIncompleteBreakdownCalls(
  WidgetRef ref,
  IncompleteBreakdownKey key,
) async {
  if (key.period == IncompleteSummaryPeriod.today) {
    ref.invalidate(hubDayReceptionCallsProvider(key.anchorYmd));
    ref.invalidate(hubDayUncalledCallsProvider(key.anchorYmd));
  }
  if (key.period == IncompleteSummaryPeriod.pending) {
    ref.invalidate(hubPendingUncalledCallsProvider);
  }
  ref.invalidate(incompleteBreakdownCallsProvider(key));
  ref.invalidate(hubSegmentIncompleteBadgeProvider);
  return ref.read(incompleteBreakdownCallsProvider(key).future);
}

/// 홈 미통화 탭 기간 필터 — `HomeIncompleteBreakdown`과 동일.
enum IncompleteSummaryPeriod { pending, today, week, month, year, all }

/// 최근 [pendingUncalledLookbackDays]일 내 미해결 미통화 — 접수일 무관.
final hubPendingUncalledCallsProvider =
    FutureProvider.autoDispose<List<SalesCall>>((ref) async {
  final anchor = ref.watch(homeHubFlowAnchorYmdProvider);
  final repo = ref.watch(salesCallsRepositoryProvider);
  return repo.fetchCallsAllPages(
    fromDate: pendingUncalledFromYmd(anchor),
    uncalledOnly: true,
    includeCallHistory: false,
  );
});

final hubPendingUncalledSummaryProvider =
    FutureProvider.autoDispose<PendingUncalledSummary>((ref) async {
  final calls = await ref.watch(hubPendingUncalledCallsProvider.future);
  final overrides = await ref.watch(tempManagerOverridesProvider.future);
  return summarizePendingUncalled(
    calls: calls,
    todayYmd: todayYmdSeoul(),
    overrides: overrides,
    loginName: ref.watch(authControllerProvider)?.name,
  );
});

typedef IncompleteBreakdownKey = ({
  IncompleteSummaryPeriod period,
  String anchorYmd,
});

/// 미통화 담당자별 집계용 접수 목록 — 기간별 서버 조회 + 페이지네이션(1000행 제한 회피).
final incompleteBreakdownCallsProvider =
    FutureProvider.family<List<SalesCall>, IncompleteBreakdownKey>((ref, key) async {
  final repo = ref.watch(salesCallsRepositoryProvider);
  switch (key.period) {
    case IncompleteSummaryPeriod.pending:
      return ref.watch(hubPendingUncalledCallsProvider.future);
    case IncompleteSummaryPeriod.today:
      return ref.watch(hubDayReceptionCallsProvider(key.anchorYmd).future);
    case IncompleteSummaryPeriod.week:
      final range = seoulWeekRangeContaining(key.anchorYmd);
      return repo.fetchCallsAllPages(
        dateRangeStart: range.$1,
        dateRangeEndInclusive: range.$2,
        includeCallHistory: false,
      );
    case IncompleteSummaryPeriod.month:
      final range = seoulMonthRangeContaining(key.anchorYmd);
      return repo.fetchCallsAllPages(
        dateRangeStart: range.$1,
        dateRangeEndInclusive: range.$2,
        includeCallHistory: false,
      );
    case IncompleteSummaryPeriod.year:
      final range = seoulYearRangeContaining(key.anchorYmd);
      return repo.fetchCallsAllPages(
        dateRangeStart: range.$1,
        dateRangeEndInclusive: range.$2,
        includeCallHistory: false,
      );
    case IncompleteSummaryPeriod.all:
      // 연도별로 나눠 조회 — 단일 무제한 조회 시 1000행에서 끊기는 현상 방지.
      final endYear = int.tryParse(key.anchorYmd.substring(0, 4)) ??
          DateTime.now().year;
      const startYear = 2020;
      final merged = <SalesCall>[];
      for (var y = startYear; y <= endYear; y++) {
        final range = seoulYearRangeContaining('$y-06-15');
        merged.addAll(
          await repo.fetchCallsAllPages(
            dateRangeStart: range.$1,
            dateRangeEndInclusive: range.$2,
            includeCallHistory: false,
          ),
        );
      }
      return merged;
  }
});

/// 달력에 표시 중인 주·월 구간 (`next_scheduled_date` 기준, 목록 `followDate`/`followRange`와 동일).
typedef CalendarFollowRangeKey = ({String startYmd, String endYmd});

/// [CalendarFollowRangeKey] 구간의 팔로우 통화 — `SalesCallListScreen.incompleteByDate`와 동일 API 조건.
final calendarFollowRangeProvider =
    FutureProvider.family<List<SalesCall>, CalendarFollowRangeKey>((ref, key) async {
  final repo = ref.watch(salesCallsRepositoryProvider);
  return repo.fetchCallsAllPages(
    followRangeStart: key.startYmd,
    followRangeEndInclusive: key.endYmd,
    incompleteOnly: true,
    excludeSimpleInquiries: true,
    includeCallHistory: false,
  );
});

/// 세그먼트 배지: 로그인 담당자 건수, 없으면 전체.
int segmentBadgeCountForUser(AssigneeOverview overview, String? loginName) {
  final name = loginName?.trim();
  if (name == null || name.isEmpty) return overview.total;
  for (final row in overview.byAssignee) {
    if (row.assignee == name) return row.count;
  }
  return overview.total;
}

List<String> weekYmdKeysContaining(String anchorYmd) {
  final w = seoulWeekRangeContaining(anchorYmd);
  final keys = <String>[w.$1];
  var cur = w.$1;
  for (var i = 0; i < 6; i++) {
    cur = addDaysToYmd(cur, 1);
    keys.add(cur);
  }
  return keys;
}

/// 홈 [미통화] 탭 배지 — 처리할 미통화(최근 60일), 로그인 담당자 건수.
final hubSegmentIncompleteBadgeProvider = FutureProvider<int>((ref) async {
  final summary = await ref.watch(hubPendingUncalledSummaryProvider.future);
  final loginName = ref.watch(authControllerProvider)?.name?.trim();
  if (loginName != null && loginName.isNotEmpty) {
    return summary.userCount;
  }
  return summary.total;
});

/// 홈 [달력] 탭 배지 — 흐름 앵커 기준 주/월 구간 팔로우 건수, 로그인 담당자 우선.
final hubSegmentCalendarBadgeProvider = FutureProvider<int>((ref) async {
  final anchor = ref.watch(homeHubFlowAnchorYmdProvider);
  final navStep = ref.watch(homeHubNavStepProvider);
  final loginName = ref.watch(authControllerProvider)?.name.trim();

  final range = switch (navStep) {
    HubNavStep.day => (anchor, anchor),
    HubNavStep.month => seoulMonthRangeContaining(anchor),
    HubNavStep.week => seoulWeekRangeContaining(anchor),
  };
  final calls = await ref.watch(
    calendarFollowRangeProvider((startYmd: range.$1, endYmd: range.$2)).future,
  );
  final overrides = await ref.watch(tempManagerOverridesProvider.future);

  final isMonth = navStep == HubNavStep.month;
  final monthPrefix = isMonth ? anchor.substring(0, 7) : null;
  final weekDays = isMonth ? null : weekYmdKeysContaining(anchor).toSet();

  var totalInPeriod = 0;
  var userInPeriod = 0;

  for (final c in calls) {
    final fk = c.followCalendarDateKey;
    if (fk == null || fk.length < 10) continue;
    final dateKey = fk.substring(0, 10);
    if (isMonth) {
      if (!dateKey.startsWith(monthPrefix!)) continue;
    } else {
      if (!weekDays!.contains(dateKey)) continue;
    }
    totalInPeriod++;
    if (loginName != null && loginName.isNotEmpty) {
      final assignee = displayAssigneeForCall(c, overrides, DateTime.now());
      if (assignee == loginName) userInPeriod++;
    }
  }

  if (loginName == null || loginName.isEmpty) return totalInPeriod;
  if (userInPeriod > 0) return userInPeriod;
  return totalInPeriod;
});

final bottomBarVisibilityProvider = StateProvider<bool>((ref) => true);

/// 메인 화면의 Scaffold를 제어하기 위한 Key (드로어 열기 등)
final mainScaffoldKeyProvider = Provider((ref) => GlobalKey<ScaffoldState>());
