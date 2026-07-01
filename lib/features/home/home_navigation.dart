import 'package:coad_customer_calls/features/home/home_providers.dart';
import 'package:coad_customer_calls/features/main/main_tab_screen.dart';
import 'package:coad_customer_calls/providers.dart';
import 'package:coad_customer_calls/services/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';

typedef HomeSalesCacheInvalidator = void Function(ProviderOrFamily provider);

/// 홈·상담현황에 쓰이는 통화 목록·통계 캐시 무효화.
void invalidateHomeSalesCaches(HomeSalesCacheInvalidator invalidate) {
  invalidate(todayCallsContentProvider);
  invalidate(hubDayReceptionCallsProvider);
  invalidate(hubDayUncalledCallsProvider);
  invalidate(calendarFollowRangeProvider);
  invalidate(hubPeriodReceptionBundleProvider);
  invalidate(hubPeriodStatsProvider);
  invalidate(hubPeriodFollowSnapshotProvider);
  invalidate(hubPeriodQualityOverviewProvider);
  invalidate(hubPendingUncalledCallsProvider);
  invalidate(hubPendingUncalledSummaryProvider);
}

/// 다른 화면에서 메인 탭 **홈**으로 돌아가며 [흐름|달력] 구역을 연다.
void openHomeHub(
  BuildContext context,
  WidgetRef ref, {
  HomeHubSection section = HomeHubSection.flow,
  CalendarFormat calendarFormat = CalendarFormat.week,
}) {
  requestHomeHubSection(ref, section, calendarFormat: calendarFormat);
  Navigator.of(context).popUntil((route) => route.isFirst);
}

/// 접수·상담 저장 후 홈 탭으로 이동하고 데이터를 다시 불러옴.
void navigateToHomeAndRefresh(
  BuildContext context,
  WidgetRef ref, {
  String? message,
}) {
  ref.read(salesCallsRepositoryProvider).invalidateTempManagerCache(
        forceRevertOnNextFetch: true,
      );
  invalidateHomeSalesCaches(ref.invalidate);
  ref.read(homeHubFlowResetTickProvider.notifier).state++;
  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute<void>(builder: (_) => const MainTabScreen()),
    (route) => false,
  );
  if (message == null) return;
  WidgetsBinding.instance.addPostFrameCallback((_) {
    final ctx = NotificationService.navigatorKey.currentContext;
    if (ctx == null) return;
    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(message)));
  });
}
