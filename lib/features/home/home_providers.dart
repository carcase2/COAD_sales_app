import 'dart:async';

import 'package:coad_customer_calls/core/utils/date_seoul.dart';
import 'package:coad_customer_calls/models/sales_call.dart';
import 'package:coad_customer_calls/models/today_stats.dart';
import 'package:coad_customer_calls/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';

/// 홈 통합 화면의 [흐름 | 미통화 | 달력] 구역 — `HomeHubScreen`이 소비.
enum HomeHubSection { flow, incomplete, calendar }

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
    unawaited(ref.read(rankingCallsProvider.future));
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

final todayStatsProvider = FutureProvider<TodayStats>((ref) async {
  final repo = ref.watch(salesCallsRepositoryProvider);
  return repo.fetchTodayStats();
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

/// 오늘 `next_scheduled_date`(다음 예정일)가 오늘인 미종료 팔로우 — 총건 + 담당자별 건수(동일 API 1회).
final todayFollowOverviewProvider = FutureProvider<AssigneeOverview>((ref) async {
  final repo = ref.watch(salesCallsRepositoryProvider);
  final rows = await repo.fetchCalls(
    followDate: todayYmdSeoul(),
    incompleteOnly: true,
    excludeSimpleInquiries: true,
    limit: 1000,
    includeCallHistory: false,
  );
  return AssigneeOverview(total: rows.length, byAssignee: _groupByAssignee(rows));
});

/// 금일 미통화(uncalled) — `SalesCallListScreen`(incomplete·오늘)과 동일 fetch 조건, 담당자별 건수.
final todayIncompleteOverviewProvider = FutureProvider<AssigneeOverview>((ref) async {
  final repo = ref.watch(salesCallsRepositoryProvider);
  final rows = await repo.fetchCalls(
    date: todayYmdSeoul(),
    uncalledOnly: true,
    limit: 1000,
    includeCallHistory: true,
  );
  return AssigneeOverview(total: rows.length, byAssignee: _groupByAssignee(rows));
});

/// 금일 접수 기준 품질 지표:
/// - 미통화 비율(미통화/총 접수)
/// - 접수 후 첫 상담까지 평균 소요 시간(분)
final todayCallQualityOverviewProvider = FutureProvider<CallQualityOverview>((ref) async {
  final repo = ref.watch(salesCallsRepositoryProvider);
  final rows = await repo.fetchCalls(
    date: todayYmdSeoul(),
    limit: 1000,
    includeCallHistory: true,
  );
  return _buildCallQualityOverview(rows);
});

/// 홈 허브 흐름 카드 구간 — 하루 / 금주 / 금월.
enum HubPeriod { day, week, month }

typedef HubPeriodKey = ({HubPeriod period, String anchorYmd});

final hubPeriodStatsProvider =
    FutureProvider.family<TodayStats, HubPeriodKey>((ref, key) async {
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

final hubPeriodFollowOverviewProvider =
    FutureProvider.family<AssigneeOverview, HubPeriodKey>((ref, key) async {
  final repo = ref.watch(salesCallsRepositoryProvider);
  switch (key.period) {
    case HubPeriod.day:
      final rows = await repo.fetchCalls(
        followDate: key.anchorYmd,
        incompleteOnly: true,
        excludeSimpleInquiries: true,
        limit: 1000,
        includeCallHistory: false,
      );
      return AssigneeOverview(
        total: rows.length,
        byAssignee: _groupByAssignee(rows),
      );
    case HubPeriod.week:
      final range = seoulWeekRangeContaining(key.anchorYmd);
      final rows = await repo.fetchCalls(
        followRangeStart: range.$1,
        followRangeEndInclusive: range.$2,
        incompleteOnly: true,
        excludeSimpleInquiries: true,
        limit: 1000,
        includeCallHistory: false,
      );
      return AssigneeOverview(
        total: rows.length,
        byAssignee: _groupByAssignee(rows),
      );
    case HubPeriod.month:
      final range = seoulMonthRangeContaining(key.anchorYmd);
      final rows = await repo.fetchCalls(
        followRangeStart: range.$1,
        followRangeEndInclusive: range.$2,
        incompleteOnly: true,
        excludeSimpleInquiries: true,
        limit: 1000,
        includeCallHistory: false,
      );
      return AssigneeOverview(
        total: rows.length,
        byAssignee: _groupByAssignee(rows),
      );
  }
});

final hubPeriodQualityOverviewProvider =
    FutureProvider.family<CallQualityOverview, HubPeriodKey>((ref, key) async {
  final repo = ref.watch(salesCallsRepositoryProvider);
  switch (key.period) {
    case HubPeriod.day:
      final rows = await repo.fetchCalls(
        date: key.anchorYmd,
        limit: 1000,
        includeCallHistory: true,
      );
      return _buildCallQualityOverview(rows);
    case HubPeriod.week:
      final range = seoulWeekRangeContaining(key.anchorYmd);
      final rows = await repo.fetchCalls(
        dateRangeStart: range.$1,
        dateRangeEndInclusive: range.$2,
        limit: 1000,
        includeCallHistory: true,
      );
      return _buildCallQualityOverview(rows);
    case HubPeriod.month:
      final range = seoulMonthRangeContaining(key.anchorYmd);
      final rows = await repo.fetchCalls(
        dateRangeStart: range.$1,
        dateRangeEndInclusive: range.$2,
        limit: 1000,
        includeCallHistory: true,
      );
      return _buildCallQualityOverview(rows);
  }
});

final rankingCallsProvider = FutureProvider<List<SalesCall>>((ref) async {
  final repo = ref.watch(salesCallsRepositoryProvider);
  // 미통화·달력 집계에는 상담 이력 불필요. embed 제거로 페이로드·타임아웃(연결 끊김) 방지
  return repo.fetchCalls(limit: 1000, includeCallHistory: false);
});

/// 달력에 표시 중인 주·월 구간 (`next_scheduled_date` 기준, 목록 `followDate`/`followRange`와 동일).
typedef CalendarFollowRangeKey = ({String startYmd, String endYmd});

/// [CalendarFollowRangeKey] 구간의 팔로우 통화 — `SalesCallListScreen.incompleteByDate`와 동일 API 조건.
final calendarFollowRangeProvider =
    FutureProvider.family<List<SalesCall>, CalendarFollowRangeKey>((ref, key) async {
  final repo = ref.watch(salesCallsRepositoryProvider);
  return repo.fetchCalls(
    followRangeStart: key.startYmd,
    followRangeEndInclusive: key.endYmd,
    incompleteOnly: true,
    excludeSimpleInquiries: true,
    includeCallHistory: false,
    limit: 2000,
  );
});

final bottomBarVisibilityProvider = StateProvider<bool>((ref) => true);

/// 메인 화면의 Scaffold를 제어하기 위한 Key (드로어 열기 등)
final mainScaffoldKeyProvider = Provider((ref) => GlobalKey<ScaffoldState>());
