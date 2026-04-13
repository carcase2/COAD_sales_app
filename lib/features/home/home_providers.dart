import 'package:coad_customer_calls/core/utils/date_seoul.dart';
import 'package:coad_customer_calls/models/sales_call.dart';
import 'package:coad_customer_calls/models/today_stats.dart';
import 'package:coad_customer_calls/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final todayCallsContentProvider = FutureProvider<List<SalesCall>>((ref) async {
  final repo = ref.watch(salesCallsRepositoryProvider);
  return repo.fetchCalls(date: todayYmdSeoul(), limit: 100, includeCallHistory: false);
});

final todayStatsProvider = FutureProvider<TodayStats>((ref) async {
  final repo = ref.watch(salesCallsRepositoryProvider);
  return repo.fetchTodayStats();
});

final rankingCallsProvider = FutureProvider<List<SalesCall>>((ref) async {
  final repo = ref.watch(salesCallsRepositoryProvider);
  // 미통화와 완료건 모두 가져와서 통계(0/5 등)를 내기 위해 필터 제거
  return repo.fetchCalls(limit: 1000);
});
