import 'dart:async';

import 'package:coad_customer_calls/core/utils/date_seoul.dart';
import 'package:coad_customer_calls/models/sales_call.dart';
import 'package:coad_customer_calls/models/today_stats.dart';
import 'package:coad_customer_calls/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';

/// 상담현황 → 달력 탭 → (선택) 주간 등 — `MainTab`·`ConsultationStatusScreen`이 한 번씩 소비.
typedef ConsultationLaunchTarget = ({int tabIndex, CalendarFormat calendarFormat});

final pendingConsultationLaunchProvider = StateProvider<ConsultationLaunchTarget?>((ref) => null);

/// 열기 메뉴 등: 상담현황의 **달력** 탭, **주간 달력** 형식으로 이동.
/// [`rankingCallsProvider`]를 먼저 시작해 탭 전환 후 로딩 대기 시간을 줄임.
void requestConsultationCalendarWeekNavigation(WidgetRef ref) {
  unawaited(ref.read(rankingCallsProvider.future));
  ref.read(pendingConsultationLaunchProvider.notifier).state = (
    tabIndex: 2,
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

final rankingCallsProvider = FutureProvider<List<SalesCall>>((ref) async {
  final repo = ref.watch(salesCallsRepositoryProvider);
  // 미통화·달력 집계에는 상담 이력 불필요. embed 제거로 페이로드·타임아웃(연결 끊김) 방지
  return repo.fetchCalls(limit: 1000, includeCallHistory: false);
});

final bottomBarVisibilityProvider = StateProvider<bool>((ref) => true);

/// 메인 화면의 Scaffold를 제어하기 위한 Key (드로어 열기 등)
final mainScaffoldKeyProvider = Provider((ref) => GlobalKey<ScaffoldState>());
