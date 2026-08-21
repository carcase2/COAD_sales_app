import 'dart:async';

import 'package:coad_customer_calls/core/utils/date_seoul.dart';
import 'package:coad_customer_calls/data/sales_calls_repository.dart';
import 'package:coad_customer_calls/data/temp_manager_logic.dart';
import 'package:coad_customer_calls/features/sales_calls/master_data_provider.dart';
import 'package:coad_customer_calls/models/sales_call.dart';
import 'package:coad_customer_calls/models/temp_manager_override.dart';
import 'package:coad_customer_calls/models/today_stats.dart';
import 'package:coad_customer_calls/data/support_call_log_repository.dart';
import 'package:coad_customer_calls/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';

/// 흐름 탭 · 미통화 0건 안내(설정) — `SettingsScreen`·`HomeHubScreen` 공유.
const String homeFlowUncalledPopupPrefKey = 'home_flow_no_uncalled_popup_v2';

/// 금일 팔로우 최초 예정 건수(기기·일자별) — 완료 후 목록에서 빠져도 진행률 유지.
String homeFlowFollowBaselinePrefKey(String ymd) =>
    'hub_follow_baseline_v1_$ymd';

/// 처리할 미통화 조회 기간 — 접수일 무관, 최근 N일.
const int pendingUncalledLookbackDays = 60;

String pendingUncalledFromYmd(String anchorYmd) =>
    addDaysToYmd(anchorYmd, -pendingUncalledLookbackDays);

/// 지연 팔로우 조회 하한 — 너무 오래된 건은 제외.
const int overdueFollowLookbackDays = 180;

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
    if (me.isNotEmpty && displayAssigneeForCall(call, overrides, now) == me) {
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

/// 홈 통합 화면의 [흐름 | 달력] 구역 — `HomeHubScreen`이 소비.
enum HomeHubSection { flow, calendar }

/// 흐름 탭 상단 일/주/월 — 달력과 공유.
enum HubNavStep { day, week, month }

final homeHubNavStepProvider = StateProvider<HubNavStep>(
  (ref) => HubNavStep.day,
);

final homeHubFlowAnchorYmdProvider = StateProvider<String>(
  (ref) => todayYmdSeoul(),
);

typedef ConsultationLaunchTarget = ({
  HomeHubSection section,
  CalendarFormat calendarFormat,
});

final pendingConsultationLaunchProvider =
    StateProvider<ConsultationLaunchTarget?>((ref) => null);

/// [MainTabScreen]이 홈(탭 0)으로 이동할 때마다 증가. [HomeHubScreen]이 업무 흐름을 **일·금일**로 맞춤.
final homeHubFlowResetTickProvider = StateProvider<int>((ref) => 0);

/// 홈으로 이동한 뒤 지정 구역(흐름·달력)을 연다.
void requestHomeHubSection(
  WidgetRef ref,
  HomeHubSection section, {
  CalendarFormat calendarFormat = CalendarFormat.week,
}) {
  unawaited(ref.read(hubPendingUncalledSummaryProvider.future));
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

/// 금일 접수 — [hubDayReceptionCallsProvider]와 동일 소스(중복 fetch 방지).
final todayCallsContentProvider = FutureProvider<List<SalesCall>>((ref) async {
  final today = todayYmdSeoul();
  return ref.watch(hubDayReceptionCallsProvider(today).future);
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
    final a = (c.assignedTo == null || c.assignedTo!.isEmpty)
        ? '미지정'
        : c.assignedTo!;
    counts[a] = (counts[a] ?? 0) + 1;
  }
  final list = counts.entries
      .map((e) => (assignee: e.key, count: e.value))
      .toList();
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
    final a = (c.assignedTo == null || c.assignedTo!.isEmpty)
        ? '미지정'
        : c.assignedTo!;
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
  final assigneeRows =
      byAssignee.entries.map((e) => metricFor(e.key, e.value)).toList()
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

final supportHomeStatsProvider = FutureProvider.autoDispose
    .family<SupportHomePeriodStats, HubPeriodKey>((ref, key) async {
      final range = switch (key.period) {
        HubPeriod.day => (key.anchorYmd, key.anchorYmd),
        HubPeriod.week => seoulWeekRangeContaining(key.anchorYmd),
        HubPeriod.month => seoulMonthRangeContaining(key.anchorYmd),
      };
      return ref
          .read(supportCallLogRepositoryProvider)
          .periodStats(fromYmd: range.$1, toYmdInclusive: range.$2);
    });

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
  final color =
      palette[idx < 0
          ? assignee.hashCode.abs() % palette.length
          : idx % palette.length];
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
      final calls = await ref.watch(
        hubDayReceptionCallsProvider(anchorYmd).future,
      );
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

TodayStats _statsFromReceptionCalls(List<SalesCall> calls) {
  final total = calls.length;
  final incomplete = calls.where((c) => c.isMissed).length;
  return TodayStats(
    todayCount: total,
    incompleteCount: incomplete,
    completedToday: total - incomplete,
  );
}

/// 접수 bundle에서 파생 — 별도 stats API·Future 없음.
/// reload/refresh 중에는 이전 수치를 유지해 카드가 잠깐 0으로 떨어지지 않게 한다.
final hubPeriodStatsProvider = Provider.autoDispose
    .family<AsyncValue<TodayStats>, HubPeriodKey>((ref, key) {
      final bundleAsync = ref.watch(hubPeriodReceptionBundleProvider(key));
      return bundleAsync.when(
        skipLoadingOnReload: true,
        skipLoadingOnRefresh: true,
        data: (bundle) =>
            AsyncValue.data(_statsFromReceptionCalls(bundle.calls)),
        loading: () => const AsyncValue.loading(),
        error: (e, st) => AsyncValue.error(e, st),
      );
    });

/// 전기간(전일·전주·전월) 비교 배너용 경량 통계 — 전건 조회 없이
/// `id·status_id·call_stage` 컬럼만 내려받음. 상세 목록이 필요하면 탭 시점에 조회.
final hubPeriodLightStatsProvider = FutureProvider.autoDispose
    .family<TodayStats, HubPeriodKey>((ref, key) async {
      final repo = ref.watch(salesCallsRepositoryProvider);
      final (String start, String end) = switch (key.period) {
        HubPeriod.day => (key.anchorYmd, key.anchorYmd),
        HubPeriod.week => seoulWeekRangeContaining(key.anchorYmd),
        HubPeriod.month => seoulMonthRangeContaining(key.anchorYmd),
      };
      return repo.fetchStatsForDateRange(start, end);
    });

Future<List<SalesCall>> _fetchHubPeriodFollowCalls(
  SalesCallsRepository repo,
  HubPeriodKey key,
) async {
  switch (key.period) {
    case HubPeriod.day:
      return repo.fetchCallsAllPages(
        followDate: key.anchorYmd,
        excludeSimpleInquiries: true,
        includeCallHistory: false,
      );
    case HubPeriod.week:
      final range = seoulWeekRangeContaining(key.anchorYmd);
      return repo.fetchCallsAllPages(
        followRangeStart: range.$1,
        followRangeEndInclusive: range.$2,
        excludeSimpleInquiries: true,
        includeCallHistory: false,
      );
    case HubPeriod.month:
      final range = seoulMonthRangeContaining(key.anchorYmd);
      return repo.fetchCallsAllPages(
        followRangeStart: range.$1,
        followRangeEndInclusive: range.$2,
        excludeSimpleInquiries: true,
        includeCallHistory: false,
      );
  }
}

/// 팔로우 예정·완료·남음 — 기간 내 1회 조회 + (금일) 최초 건수 저장.
class HubPeriodFollowSnapshot {
  HubPeriodFollowSnapshot({
    required List<SalesCall> calls,
    required this.remainingCalls,
    this.dayBaselineTotal,
  }) : calls = calls;

  final List<SalesCall> calls;
  final List<SalesCall> remainingCalls;

  /// 금일만 SharedPreferences 기준선. 주·월은 null → [calls] 길이 사용.
  final int? dayBaselineTotal;

  int get total => dayBaselineTotal ?? calls.length;

  int get remaining => remainingCalls.length;

  int get completed => (total - remaining).clamp(0, total);

  AssigneeOverview get incompleteOverview => AssigneeOverview(
    total: remaining,
    byAssignee: _groupByAssignee(remainingCalls),
  );
}

Future<int> _resolveFollowDayBaseline(
  Ref ref,
  String ymd,
  int currentTotalCalls,
  int currentRemaining,
) async {
  final prefs = ref.read(appDependenciesProvider).prefs;
  final key = homeFlowFollowBaselinePrefKey(ymd);
  var baseline = prefs.getInt(key);
  final observed = currentTotalCalls > currentRemaining
      ? currentTotalCalls
      : currentRemaining;

  if (baseline == null) {
    baseline = observed;
    await prefs.setInt(key, baseline);
  } else if (observed > baseline) {
    // 당일 중 새로 잡힌 팔로우 — 기준선을 올려 전체 건수에 반영.
    baseline = observed;
    await prefs.setInt(key, baseline);
  }

  return baseline;
}

List<SalesCall> _followRemainingCalls(List<SalesCall> calls) =>
    calls.where((c) => ![2, 3, 4].contains(c.statusId)).toList();

final hubPeriodFollowSnapshotProvider = FutureProvider.autoDispose
    .family<HubPeriodFollowSnapshot, HubPeriodKey>((ref, key) async {
      final repo = ref.watch(salesCallsRepositoryProvider);
      final calls = await _fetchHubPeriodFollowCalls(repo, key);
      final remainingCalls = _followRemainingCalls(calls);

      if (key.period == HubPeriod.day) {
        final baseline = await _resolveFollowDayBaseline(
          ref,
          key.anchorYmd,
          calls.length,
          remainingCalls.length,
        );
        return HubPeriodFollowSnapshot(
          calls: calls,
          remainingCalls: remainingCalls,
          dayBaselineTotal: baseline,
        );
      }

      return HubPeriodFollowSnapshot(
        calls: calls,
        remainingCalls: remainingCalls,
      );
    });

final hubPeriodFollowOverviewProvider = Provider.autoDispose
    .family<AsyncValue<AssigneeOverview>, HubPeriodKey>((ref, key) {
      final snapshotAsync = ref.watch(hubPeriodFollowSnapshotProvider(key));
      return snapshotAsync.when(
        skipLoadingOnReload: true,
        skipLoadingOnRefresh: true,
        data: (snapshot) => AsyncValue.data(snapshot.incompleteOverview),
        loading: () => const AsyncValue.loading(),
        error: (e, st) => AsyncValue.error(e, st),
      );
    });

Future<List<SalesCall>> _fetchHubPeriodUpdatedCalls(
  SalesCallsRepository repo,
  HubPeriodKey key,
) async {
  switch (key.period) {
    case HubPeriod.day:
      return repo.fetchCallsAllPages(
        updatedAtRangeStartYmd: key.anchorYmd,
        includeCallHistory: false,
      );
    case HubPeriod.week:
      final range = seoulWeekRangeContaining(key.anchorYmd);
      return repo.fetchCallsAllPages(
        updatedAtRangeStartYmd: range.$1,
        updatedAtRangeEndInclusiveYmd: range.$2,
        includeCallHistory: false,
      );
    case HubPeriod.month:
      final range = seoulMonthRangeContaining(key.anchorYmd);
      return repo.fetchCallsAllPages(
        updatedAtRangeStartYmd: range.$1,
        updatedAtRangeEndInclusiveYmd: range.$2,
        includeCallHistory: false,
      );
  }
}

/// 기간 내 `updated_at` 건 — coad_home 「금일 업데이트」와 동일 기준.
final hubPeriodUpdatedCallsProvider = FutureProvider.autoDispose
    .family<List<SalesCall>, HubPeriodKey>((ref, key) async {
      final repo = ref.watch(salesCallsRepositoryProvider);
      return _fetchHubPeriodUpdatedCalls(repo, key);
    });

final hubPeriodUpdatedOverviewProvider = Provider.autoDispose
    .family<AsyncValue<AssigneeOverview>, HubPeriodKey>((ref, key) {
      final callsAsync = ref.watch(hubPeriodUpdatedCallsProvider(key));
      return callsAsync.when(
        skipLoadingOnReload: true,
        skipLoadingOnRefresh: true,
        data: (calls) => AsyncValue.data(
          AssigneeOverview(
            total: calls.length,
            byAssignee: _groupByAssignee(calls),
          ),
        ),
        loading: () => const AsyncValue.loading(),
        error: (e, st) => AsyncValue.error(e, st),
      );
    });

final hubPeriodQualityOverviewProvider = FutureProvider.autoDispose
    .family<CallQualityOverview, HubPeriodKey>((ref, key) async {
      final bundle = await ref.watch(
        hubPeriodReceptionBundleProvider(key).future,
      );
      return bundle.quality;
    });

/// 흐름 탭 기간 데이터를 병렬로 미리 불러 워터폴 대기를 줄임.
/// 전기간은 비교 배너용 경량 통계만 미리 조회(전건 fetch 없음).
void prefetchHubPeriodFlow(
  WidgetRef ref,
  HubPeriodKey key, {
  HubPeriodKey? previousKey,
}) {
  final futures = <Future<Object?>>[
    ref.read(hubPeriodReceptionBundleProvider(key).future),
    ref.read(hubPeriodFollowSnapshotProvider(key).future),
    ref.read(hubPeriodUpdatedCallsProvider(key).future),
  ];
  if (previousKey != null) {
    futures.add(ref.read(hubPeriodLightStatsProvider(previousKey).future));
  }
  unawaited(Future.wait(futures).catchError((_) => <Object?>[]));
}

/// day 기간 접수/미통화 카드는 [hubDayReceptionCallsProvider]가 실제 소스다.
/// bundle만 invalidate하면 day 캐시(빈 목록 포함)가 재사용되어 카드가 0에 고정될 수 있다.
void invalidateHubPeriodReceptionSources(
  void Function(ProviderOrFamily provider) invalidate,
  HubPeriodKey key,
) {
  if (key.period == HubPeriod.day) {
    invalidate(hubDayReceptionCallsProvider(key.anchorYmd));
    invalidate(hubDayUncalledCallsProvider(key.anchorYmd));
  }
  invalidate(hubPeriodReceptionBundleProvider(key));
  invalidate(hubPeriodQualityOverviewProvider(key));
}

/// pull-to-refresh / 재시도 — 흐름 탭 활성 기간 데이터를 서버에서 다시 조회.
Future<void> refreshHubPeriodFlow(
  WidgetRef ref,
  HubPeriodKey key, {
  HubPeriodKey? previousKey,
}) async {
  invalidateHubPeriodReceptionSources(ref.invalidate, key);
  ref.invalidate(hubPeriodFollowSnapshotProvider(key));
  ref.invalidate(hubPeriodUpdatedCallsProvider(key));
  ref.invalidate(hubPendingUncalledCallsProvider);
  if (previousKey != null) {
    ref.invalidate(hubPeriodLightStatsProvider(previousKey));
  }

  final futures = <Future<Object?>>[
    ref.read(hubPeriodReceptionBundleProvider(key).future),
    ref.read(hubPeriodFollowSnapshotProvider(key).future),
    ref.read(hubPeriodUpdatedCallsProvider(key).future),
    ref.read(hubPeriodQualityOverviewProvider(key).future),
    ref.read(hubPendingUncalledSummaryProvider.future),
  ];
  if (previousKey != null) {
    futures.add(ref.read(hubPeriodLightStatsProvider(previousKey).future));
  }
  // RefreshIndicator 완료용 — 개별 provider 오류는 각 AsyncValue에 남긴다.
  await Future.wait(futures.map((f) => f.catchError((_) => null)));
}

/// 흐름 카드 탭 시 — 화면 숫자와 무관하게 서버에서 다시 조회.
Future<HubPeriodReceptionBundle> refreshHubPeriodUncalledBundle(
  WidgetRef ref,
  HubPeriodKey key,
) async {
  // day 소스를 먼저 무효화한 뒤 bundle을 다시 읽어 빈 day 캐시 재사용을 막는다.
  invalidateHubPeriodReceptionSources(ref.invalidate, key);
  return ref.read(hubPeriodReceptionBundleProvider(key).future);
}

/// 임시 담당 오버라이드 — 실패해도 빈 목록으로 진행(미통화 조회 자체를 막지 않음).
Future<List<TempManagerOverride>> _pendingUncalledOverrides(Ref ref) async {
  try {
    return await ref.watch(tempManagerOverridesProvider.future);
  } catch (_) {
    return const <TempManagerOverride>[];
  }
}

/// 최근 [pendingUncalledLookbackDays]일 내 미해결 미통화 — 접수일 무관.
/// 배지·담당자 집계 전용 경량 조회(필요 컬럼만) — 목록 화면은 자체 전체 조회 사용.
final hubPendingUncalledCallsProvider =
    FutureProvider.autoDispose<List<SalesCall>>((ref) async {
      final anchor = ref.watch(homeHubFlowAnchorYmdProvider);
      final repo = ref.watch(salesCallsRepositoryProvider);
      final calls = await repo.fetchPendingUncalledLite(
        fromYmd: pendingUncalledFromYmd(anchor),
      );
      final overrides = await _pendingUncalledOverrides(ref);
      return applyCallDisplayOverrides(calls, overrides, DateTime.now());
    });

final hubPendingUncalledSummaryProvider =
    FutureProvider.autoDispose<PendingUncalledSummary>((ref) async {
      final calls = await ref.watch(hubPendingUncalledCallsProvider.future);
      final overrides = await _pendingUncalledOverrides(ref);
      return summarizePendingUncalled(
        calls: calls,
        todayYmd: todayYmdSeoul(),
        overrides: overrides,
        loginName: ref.watch(authControllerProvider.select((u) => u?.name)),
      );
    });

/// 예정일이 오늘보다 과거인 미종료 팔로우.
final hubOverdueFollowCallsProvider =
    FutureProvider.autoDispose<List<SalesCall>>((ref) async {
      final today = todayYmdSeoul();
      final repo = ref.watch(salesCallsRepositoryProvider);
      final calls = await repo.fetchCallsAllPages(
        followRangeStart: addDaysToYmd(today, -overdueFollowLookbackDays),
        followRangeEndInclusive: addDaysToYmd(today, -1),
        incompleteOnly: true,
        excludeSimpleInquiries: true,
        includeCallHistory: false,
        cacheLocally: false,
      );
      final overrides = await _pendingUncalledOverrides(ref);
      final applied = applyCallDisplayOverrides(
        calls,
        overrides,
        DateTime.now(),
      );
      applied.sort((a, b) {
        final ak = a.followCalendarDateKey ?? '';
        final bk = b.followCalendarDateKey ?? '';
        final byDate = ak.compareTo(bk);
        if (byDate != 0) return byDate;
        return (a.customerName ?? '').compareTo(b.customerName ?? '');
      });
      return applied;
    });

/// 달력에 표시 중인 주·월 구간 (`next_scheduled_date` 기준, 목록 `followDate`/`followRange`와 동일).
typedef CalendarFollowRangeKey = ({String startYmd, String endYmd});

/// [CalendarFollowRangeKey] 구간의 팔로우 통화 — `SalesCallListScreen.incompleteByDate`와 동일 API 조건.
final calendarFollowRangeProvider =
    FutureProvider.family<List<SalesCall>, CalendarFollowRangeKey>((
      ref,
      key,
    ) async {
      final repo = ref.watch(salesCallsRepositoryProvider);
      return repo.fetchCallsAllPages(
        followRangeStart: key.startYmd,
        followRangeEndInclusive: key.endYmd,
        incompleteOnly: true,
        excludeSimpleInquiries: true,
        includeCallHistory: false,
        cacheLocally: false,
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

int _countCalendarBadgeInPeriod({
  required List<SalesCall> calls,
  required List<TempManagerOverride> overrides,
  required HubNavStep navStep,
  required String anchor,
  required String? loginName,
}) {
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
}

/// 홈 [흐름] 탭 배지 — 처리할 미통화(최근 60일), 로그인 담당자 건수.
final hubSegmentIncompleteBadgeProvider = Provider<AsyncValue<int>>((ref) {
  final summaryAsync = ref.watch(hubPendingUncalledSummaryProvider);
  final loginName = ref.watch(
    authControllerProvider.select((u) => u?.name.trim()),
  );
  return summaryAsync.when(
    data: (summary) {
      if (loginName != null && loginName.isNotEmpty) {
        return AsyncValue.data(summary.userCount);
      }
      return AsyncValue.data(summary.total);
    },
    loading: () => const AsyncValue.loading(),
    error: (e, st) => AsyncValue.error(e, st),
  );
});

/// 홈 [달력] 탭 배지 — [calendarFollowRangeProvider] 결과에서 파생(추가 fetch 없음).
final hubSegmentCalendarBadgeProvider = Provider<AsyncValue<int>>((ref) {
  final anchor = ref.watch(homeHubFlowAnchorYmdProvider);
  final navStep = ref.watch(homeHubNavStepProvider);
  final loginName = ref.watch(
    authControllerProvider.select((u) => u?.name.trim()),
  );

  final range = switch (navStep) {
    HubNavStep.day => (anchor, anchor),
    HubNavStep.month => seoulMonthRangeContaining(anchor),
    HubNavStep.week => seoulWeekRangeContaining(anchor),
  };
  final callsAsync = ref.watch(
    calendarFollowRangeProvider((startYmd: range.$1, endYmd: range.$2)),
  );
  final overrides =
      ref.watch(tempManagerOverridesProvider).valueOrNull ??
      const <TempManagerOverride>[];

  return callsAsync.when(
    data: (calls) => AsyncValue.data(
      _countCalendarBadgeInPeriod(
        calls: calls,
        overrides: overrides,
        navStep: navStep,
        anchor: anchor,
        loginName: loginName,
      ),
    ),
    loading: () => const AsyncValue.loading(),
    error: (e, st) => AsyncValue.error(e, st),
  );
});

/// 오프라인 미전송(접수·상담) 대기 건수 — 홈·메인 배너 공유.
final pendingSyncCountProvider = StateProvider<int>((ref) => 0);

/// 대기 건수 갱신. [autoSync] true면 건수가 있을 때 동기화 시도.
Future<({int count, int synced})> refreshPendingSyncCount(
  WidgetRef ref, {
  bool autoSync = false,
}) async {
  final repo = ref.read(salesCallsRepositoryProvider);
  var count = await repo.getPendingCount();
  ref.read(pendingSyncCountProvider.notifier).state = count;
  var synced = 0;
  if (autoSync && count > 0) {
    synced = await repo.syncPendingCalls();
    count = await repo.getPendingCount();
    ref.read(pendingSyncCountProvider.notifier).state = count;
  }
  return (count: count, synced: synced);
}
