import 'package:coad_customer_calls/core/utils/date_seoul.dart';
import 'package:coad_customer_calls/core/utils/support_permissions.dart';
import 'package:coad_customer_calls/data/support_call_log_repository.dart';
import 'package:coad_customer_calls/features/home/home_providers.dart';
import 'package:coad_customer_calls/providers.dart';
import 'package:coad_customer_calls/services/notification_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 오늘·지난 방문/발송 예정 건수. 완료(status 1)는 빼다.
class SupportDueScheduleSummary {
  const SupportDueScheduleSummary({
    required this.todayVisit,
    required this.overdueVisit,
    required this.todaySend,
    required this.overdueSend,
    this.todayDeposit = 0,
    this.overdueDeposit = 0,
  });

  final int todayVisit;
  final int overdueVisit;
  final int todaySend;
  final int overdueSend;
  final int todayDeposit;
  final int overdueDeposit;

  static const empty = SupportDueScheduleSummary(
    todayVisit: 0,
    overdueVisit: 0,
    todaySend: 0,
    overdueSend: 0,
  );

  bool get hasAny =>
      todayVisit > 0 ||
      overdueVisit > 0 ||
      todaySend > 0 ||
      overdueSend > 0 ||
      todayDeposit > 0 ||
      overdueDeposit > 0;

  String get title => '[A/S] 방문·발송 예정';

  String get body {
    final parts = <String>[];
    if (todayVisit > 0) parts.add('오늘 방문 $todayVisit건');
    if (todaySend > 0) parts.add('오늘 발송 $todaySend건');
    if (todayDeposit > 0) parts.add('오늘 입금 $todayDeposit건');
    if (overdueVisit > 0) parts.add('지난 방문 $overdueVisit건');
    if (overdueSend > 0) parts.add('지난 발송 $overdueSend건');
    if (overdueDeposit > 0) parts.add('지난 입금 $overdueDeposit건');
    return parts.join(' · ');
  }

  factory SupportDueScheduleSummary.fromEvents(
    List<SupportScheduleEvent> events,
    String todayYmd,
  ) {
    var todayVisit = 0;
    var overdueVisit = 0;
    var todaySend = 0;
    var overdueSend = 0;
    var todayDeposit = 0;
    var overdueDeposit = 0;
    for (final e in events) {
      final ymd = e.ymd;
      if (ymd.isEmpty) continue;
      final overdue = ymd.compareTo(todayYmd) < 0;
      final today = ymd == todayYmd;
      if (!overdue && !today) continue;
      if (e.kind == SupportScheduleKind.deposit) {
        if (e.depositPaid == true) continue;
        if (today) {
          todayDeposit += 1;
        } else {
          overdueDeposit += 1;
        }
        continue;
      }
      if (e.log.serviceStatusId == kSupportStatusCompleted) continue;
      if (e.kind == SupportScheduleKind.visit) {
        if (today) {
          todayVisit += 1;
        } else {
          overdueVisit += 1;
        }
      } else if (e.kind == SupportScheduleKind.quoteSend) {
        if (e.quoteSent) continue;
        if (today) {
          todaySend += 1;
        } else {
          overdueSend += 1;
        }
      }
    }
    return SupportDueScheduleSummary(
      todayVisit: todayVisit,
      overdueVisit: overdueVisit,
      todaySend: todaySend,
      overdueSend: overdueSend,
      todayDeposit: todayDeposit,
      overdueDeposit: overdueDeposit,
    );
  }
}

class SupportDeskCounts {
  const SupportDeskCounts({
    required this.todayPending,
    required this.pending,
    required this.incomplete,
    required this.inProgress,
    required this.todayVisit,
    required this.overdueVisit,
    required this.todayDeposit,
    required this.overdueDeposit,
  });

  final int todayPending;
  final int pending;
  final int incomplete;
  final int inProgress;
  final int todayVisit;
  final int overdueVisit;
  final int todayDeposit;
  final int overdueDeposit;

  static const empty = SupportDeskCounts(
    todayPending: 0,
    pending: 0,
    incomplete: 0,
    inProgress: 0,
    todayVisit: 0,
    overdueVisit: 0,
    todayDeposit: 0,
    overdueDeposit: 0,
  );

  bool get hasAttention =>
      todayPending > 0 || pending > 0 || overdueVisit > 0 || overdueDeposit > 0;
}

/// 접수 삭제·상담·방문 저장 후 홈/허브 미처리·미완료 숫자를 다시 불러온다.
void invalidateSupportWorkCaches(WidgetRef ref) {
  ref.invalidate(supportHomeStatsProvider);
  ref.invalidate(supportDeskCountsProvider);
}

final supportDeskCountsProvider = FutureProvider<SupportDeskCounts>((
  ref,
) async {
  final repo = ref.read(supportCallLogRepositoryProvider);
  final today = todayYmdSeoul();
  final events = await repo.listDueScheduleEvents(todayYmd: today);
  final due = SupportDueScheduleSummary.fromEvents(events, today);
  final pending = await repo.list(pendingOnly: true, limit: 200);
  final todayPending = await repo.list(
    pendingOnly: true,
    fromYmd: today,
    toYmdInclusive: today,
    limit: 200,
  );
  final progress = await repo.list(
    statusId: kSupportStatusInProgress,
    limit: 200,
  );
  final incomplete = await repo.list(incompleteOnly: true, limit: 400);
  return SupportDeskCounts(
    todayPending: todayPending.length,
    pending: pending.length,
    incomplete: incomplete.length,
    inProgress: progress.length,
    todayVisit: due.todayVisit,
    overdueVisit: due.overdueVisit,
    todayDeposit: due.todayDeposit,
    overdueDeposit: due.overdueDeposit,
  );
});

/// 로그인·재개·상담 저장 후 9/13/18 로컬 예약을 맞춘다.
Future<void> refreshSupportDueReminders(WidgetRef ref) async {
  final user = ref.read(authControllerProvider);
  if (!canAccessCustomerSupport(user)) {
    await NotificationService.cancelAsDueReminders();
    return;
  }
  final enabled =
      ref
          .read(appDependenciesProvider)
          .prefs
          .getBool(NotificationService.prefKeyNotifyAsDue) ??
      true;
  if (!enabled) {
    await NotificationService.cancelAsDueReminders();
    return;
  }
  try {
    final today = todayYmdSeoul();
    final events = await ref
        .read(supportCallLogRepositoryProvider)
        .listDueScheduleEvents(todayYmd: today);
    final summary = SupportDueScheduleSummary.fromEvents(events, today);
    await NotificationService.syncAsDueReminders(
      hasAny: summary.hasAny,
      title: summary.title,
      body: summary.body,
    );
  } catch (e) {
    debugPrint('[as-due] reminder refresh failed: $e');
  }
}
