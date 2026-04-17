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
void requestConsultationCalendarWeekNavigation(WidgetRef ref) {
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

/// 오늘 `next_scheduled_date`(다음 예정일)가 오늘인 미종료 팔로우 건수.
final todayFollowCountProvider = FutureProvider<int>((ref) async {
  final repo = ref.watch(salesCallsRepositoryProvider);
  final rows = await repo.fetchCalls(
    followDate: todayYmdSeoul(),
    incompleteOnly: true,
    excludeSimpleInquiries: true,
    limit: 1000,
    includeCallHistory: false,
  );
  return rows.length;
});

final rankingCallsProvider = FutureProvider<List<SalesCall>>((ref) async {
  final repo = ref.watch(salesCallsRepositoryProvider);
  // 미통화와 완료건 모두 가져와서 통계(0/5 등)를 내기 위해 필터 제거
  return repo.fetchCalls(limit: 1000);
});

final bottomBarVisibilityProvider = StateProvider<bool>((ref) => true);

/// 메인 화면의 Scaffold를 제어하기 위한 Key (드로어 열기 등)
final mainScaffoldKeyProvider = Provider((ref) => GlobalKey<ScaffoldState>());
