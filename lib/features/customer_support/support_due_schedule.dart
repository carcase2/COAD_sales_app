import 'package:coad_customer_calls/core/utils/date_seoul.dart';
import 'package:coad_customer_calls/core/utils/support_permissions.dart';
import 'package:coad_customer_calls/core/utils/support_visit_capacity.dart';
import 'package:coad_customer_calls/data/support_call_log_repository.dart';
import 'package:coad_customer_calls/features/customer_support/customer_support_intake_screen.dart';
import 'package:coad_customer_calls/features/customer_support/support_schedule_filters.dart';
import 'package:coad_customer_calls/features/customer_support/support_today_desk.dart';
import 'package:coad_customer_calls/features/home/home_providers.dart';
import 'package:coad_customer_calls/providers.dart';
import 'package:coad_customer_calls/services/notification_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;

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
    if (todayVisit > 0) parts.add('오늘 방문예정 $todayVisit건');
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
  SupportDeskCounts({
    required this.all,
    required this.todayPending,
    required this.pending,
    required this.incomplete,
    required this.inProgress,
    required this.feedbackWait,
    required this.quoteWait,
    this.verbalWait = 0,
    this.unsentQuote = 0,
    this.quoteSentWait = 0,
    required this.todayVisit,
    this.todayVisitCompleted = 0,
    required this.overdueVisit,
    required this.todayDeposit,
    required this.overdueDeposit,
  });

  final int all;
  final int todayPending;
  final int pending;
  final int incomplete;
  final int inProgress;
  final int feedbackWait;
  final int quoteWait;
  final int verbalWait;
  final int unsentQuote;
  /// 정식 견적서 발송 후 고객 답 대기.
  final int quoteSentWait;
  /// 오늘 방문예정(미완료).
  final int todayVisit;
  /// 오늘 방문완료.
  final int todayVisitCompleted;
  final int overdueVisit;
  final int todayDeposit;
  final int overdueDeposit;

  int get depositDue => todayDeposit + overdueDeposit;

  static final empty = SupportDeskCounts(
    all: 0,
    todayPending: 0,
    pending: 0,
    incomplete: 0,
    inProgress: 0,
    feedbackWait: 0,
    quoteWait: 0,
    verbalWait: 0,
    unsentQuote: 0,
    quoteSentWait: 0,
    todayVisit: 0,
    todayVisitCompleted: 0,
    overdueVisit: 0,
    todayDeposit: 0,
    overdueDeposit: 0,
  );

  bool get hasAttention =>
      todayPending > 0 ||
      pending > 0 ||
      overdueVisit > 0 ||
      overdueDeposit > 0 ||
      unsentQuote > 0;
}

/// 접수 삭제·상담·방문 저장 후 홈/허브 미처리·미완료 숫자를 다시 불러온다.
void invalidateSupportWorkCaches(WidgetRef ref) {
  ref.invalidate(supportHomeStatsProvider);
  ref.invalidate(supportDeskCountsProvider);
  ref.invalidate(supportTodayDeskProvider);
}

final supportDeskCountsProvider = FutureProvider<SupportDeskCounts>((
  ref,
) async {
  final repo = ref.read(supportCallLogRepositoryProvider);
  final today = todayYmdSeoul();
  final events = await repo.listDueScheduleEvents(todayYmd: today);
  final due = SupportDueScheduleSummary.fromEvents(events, today);
  final todayPending = await repo.list(
    pendingOnly: true,
    fromYmd: today,
    toYmdInclusive: today,
    limit: 400,
  );
  final progress = await repo.list(
    statusId: kSupportStatusInProgress,
    limit: 400,
  );
  final feedbackWait = await repo.filterLogsByLastConsultOutcome(
    progress,
    SupportConsultOutcome.feedbackWait,
  );
  final quoteWait = await repo.filterLogsByLastConsultOutcome(
    progress,
    SupportConsultOutcome.quoteSend,
  );
  final verbalWaitRaw = await repo.filterLogsByLastConsultOutcome(
    progress,
    SupportConsultOutcome.verbalQuote,
  );
  var quoteSentWait = 0;
  var verbalWait = verbalWaitRaw;
  try {
    final snapsRaw = await repo.lastConsultSnapshots(progress.map((e) => e.id));
    final sentByLog = await ref
        .read(supportAsQuoteRepositoryProvider)
        .sentYmdForCallLogs(
          progress.map(
            (e) => (
              id: e.id,
              phone: e.customerPhone,
              customerName: e.customerName,
            ),
          ),
        );
    final snaps = enrichConsultSnapshotsWithQuoteSent(snapsRaw, sentByLog);
    quoteSentWait = snaps.values
        .where(
          (s) =>
              s.outcome == SupportConsultOutcome.quoteSend &&
              (s.sentYmd ?? '').trim().isNotEmpty,
        )
        .length;
    verbalWait = verbalWaitRaw
        .where((e) => snaps[e.id]?.outcome == SupportConsultOutcome.verbalQuote)
        .toList();
  } catch (_) {
    try {
      final snaps = await repo.lastConsultSnapshots(quoteWait.map((e) => e.id));
      for (final s in snaps.values) {
        if ((s.sentYmd ?? '').trim().isNotEmpty) quoteSentWait += 1;
      }
    } catch (_) {}
  }
  final todayVisitCompleted = await repo.list(
    visitOnly: true,
    fromYmd: today,
    toYmdInclusive: today,
    statusId: kSupportStatusCompleted,
    limit: 400,
  );
  var all = 0;
  var pending = progress.length;
  var incomplete = progress.length;
  try {
    all = await repo.countAll();
  } catch (_) {}
  try {
    pending = await repo.countPending();
  } catch (_) {
    final rows = await repo.list(pendingOnly: true, limit: 400);
    pending = rows.length;
  }
  try {
    incomplete = await repo.countIncomplete();
  } catch (_) {
    final rows = await repo.list(incompleteOnly: true, limit: 400);
    incomplete = rows.length;
  }
  return SupportDeskCounts(
    all: all,
    todayPending: todayPending.length,
    pending: pending,
    incomplete: incomplete,
    inProgress: progress.length,
    feedbackWait: feedbackWait.length,
    quoteWait: quoteWait.length,
    verbalWait: verbalWait.length,
    unsentQuote: due.todaySend + due.overdueSend,
    quoteSentWait: quoteSentWait,
    todayVisit: due.todayVisit,
    todayVisitCompleted: todayVisitCompleted.length,
    overdueVisit: due.overdueVisit,
    todayDeposit: due.todayDeposit,
    overdueDeposit: due.overdueDeposit,
  );
});

/// 피드백 대기 재알림. [now]는 서울 벽시계. 2시간 뒤, 그날 19:00을 넘기면 다음날 09:00.
DateTime nextSupportFeedbackWaitAt(DateTime now) {
  final plus2 = now.add(const Duration(hours: 2));
  final workEnd = DateTime(now.year, now.month, now.day, 19);
  if (plus2.isAfter(workEnd)) {
    return DateTime(
      now.year,
      now.month,
      now.day,
      9,
    ).add(const Duration(days: 1));
  }
  return plus2;
}

DateTime supportFeedbackWaitSeoulWall(DateTime utcOrLocal) {
  final utc = utcOrLocal.isUtc ? utcOrLocal : utcOrLocal.toUtc();
  final seoul = utc.add(const Duration(hours: 9));
  return DateTime(
    seoul.year,
    seoul.month,
    seoul.day,
    seoul.hour,
    seoul.minute,
    seoul.second,
  );
}

DateTime supportFeedbackWaitSeoulNow() {
  try {
    final n = tz.TZDateTime.now(tz.local);
    return DateTime(n.year, n.month, n.day, n.hour, n.minute, n.second);
  } catch (_) {
    return DateTime.now();
  }
}

String supportFeedbackWaitUrgencyLabel(String issue) {
  final match = RegExp(r'\[긴급도\s*(상|중|하)\]').firstMatch(issue);
  return match?.group(1) ?? '중';
}

String supportFeedbackWaitNoticeTitle(SupportCallLog log) {
  return '[${supportFeedbackWaitUrgencyLabel(log.issue)}] 피드백 대기';
}

String supportFeedbackWaitNoticeBody(SupportCallLog log) {
  return [
    '[${supportFeedbackWaitUrgencyLabel(log.issue)}]',
    log.customerName.trim(),
    if (log.customerPhone.trim().isNotEmpty) log.customerPhone.trim(),
    '다시 확인해 주세요',
  ].where((e) => e.isNotEmpty).join(' · ');
}

/// 로그인·재개·상담 저장 후 9/13/18 로컬 예약, 피드백 대기, 방문 2시간 전 알림을 맞춘다.
Future<void> refreshSupportDueReminders(WidgetRef ref) async {
  final user = ref.read(authControllerProvider);
  if (!canAccessCustomerSupport(user)) {
    await NotificationService.cancelAsDueReminders();
    await NotificationService.cancelFeedbackWaitReminders();
    await NotificationService.cancelVisitSoonReminders();
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
    await NotificationService.cancelFeedbackWaitReminders();
    await NotificationService.cancelVisitSoonReminders();
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
  try {
    await _syncFeedbackWaitReminders(ref);
  } catch (e) {
    debugPrint('[as-feedback] reminder refresh failed: $e');
  }
  try {
    await _syncVisitSoonReminders(ref);
  } catch (e) {
    debugPrint('[as-visit-soon] reminder refresh failed: $e');
  }
}

Future<void> _syncFeedbackWaitReminders(WidgetRef ref) async {
  final items = await ref
      .read(supportCallLogRepositoryProvider)
      .listFeedbackWaitItems();
  final now = supportFeedbackWaitSeoulNow();
  final notices = <SupportFeedbackWaitNotice>[];
  for (final item in items.take(50)) {
    var when = nextSupportFeedbackWaitAt(
      supportFeedbackWaitSeoulWall(item.lastConsultAt),
    );
    if (!when.isAfter(now)) {
      when = nextSupportFeedbackWaitAt(now);
    }
    if (!when.isAfter(now)) continue;
    notices.add(
      SupportFeedbackWaitNotice(
        id: item.log.id,
        title: supportFeedbackWaitNoticeTitle(item.log),
        body: supportFeedbackWaitNoticeBody(item.log),
        when: when,
      ),
    );
  }
  await NotificationService.syncFeedbackWaitReminders(notices);
}

/// 방문 예정(서울 벽시계) 시각. 시간 없으면 null.
DateTime? supportVisitDateTimeSeoul({
  required String ymd,
  required String time,
}) {
  final day = ymd.trim();
  final slot = normalizeSupportVisitTime(time);
  if (day.length < 10 || slot.length < 4) return null;
  final y = int.tryParse(day.substring(0, 4));
  final m = int.tryParse(day.substring(5, 7));
  final d = int.tryParse(day.substring(8, 10));
  final hh = int.tryParse(slot.substring(0, 2));
  final mm = slot.length >= 5 ? int.tryParse(slot.substring(3, 5)) ?? 0 : 0;
  if (y == null || m == null || d == null || hh == null) return null;
  if (m < 1 || m > 12 || d < 1 || d > 31 || hh < 0 || hh > 23) return null;
  return DateTime(y, m, d, hh, mm.clamp(0, 59));
}

/// 방문 2시간 전 알림 시각.
DateTime? supportVisitSoonReminderAt({
  required String ymd,
  required String time,
}) {
  final visit = supportVisitDateTimeSeoul(ymd: ymd, time: time);
  if (visit == null) return null;
  return visit.subtract(const Duration(hours: 2));
}

String supportVisitSoonNoticeTitle(SupportCallLog log) {
  final site = parseSupportIssueBody(log.issue).siteName.trim();
  final name = log.customerName.trim();
  final label = site.isNotEmpty ? site : (name.isEmpty ? '방문 예정' : name);
  return '방문 2시간 전 · $label';
}

String supportVisitSoonNoticeBody({
  required SupportCallLog log,
  required String ymd,
  required String time,
}) {
  final slot = normalizeSupportVisitTime(time);
  String dayLabel = ymd;
  if (ymd.length >= 10) {
    final m = int.tryParse(ymd.substring(5, 7)) ?? 0;
    final d = int.tryParse(ymd.substring(8, 10)) ?? 0;
    dayLabel = '$m/$d';
  }
  return [
    '$dayLabel $slot',
    if (log.customerPhone.trim().isNotEmpty) log.customerPhone.trim(),
    '방문 준비해 주세요',
  ].where((e) => e.isNotEmpty).join(' · ');
}

Future<void> _syncVisitSoonReminders(WidgetRef ref) async {
  final today = todayYmdSeoul();
  final toYmd = addDaysToYmd(today, 21);
  final events = await ref
      .read(supportCallLogRepositoryProvider)
      .listScheduleEvents(fromYmd: today, toYmdInclusive: toYmd);
  final now = supportFeedbackWaitSeoulNow();
  final notices = <SupportVisitSoonNotice>[];
  final seen = <String>{};
  for (final e in events) {
    if (e.kind != SupportScheduleKind.visit) continue;
    if (!isSupportVisitEventOpen(e)) continue;
    final id = e.log.id.trim();
    if (id.isEmpty || !seen.add(id)) continue;
    final time = normalizeSupportVisitTime(
      e.scheduledTime ?? e.log.visitTime,
    );
    if (time.isEmpty) continue;
    final when = supportVisitSoonReminderAt(ymd: e.ymd, time: time);
    if (when == null || !when.isAfter(now)) continue;
    notices.add(
      SupportVisitSoonNotice(
        id: id,
        title: supportVisitSoonNoticeTitle(e.log),
        body: supportVisitSoonNoticeBody(
          log: e.log,
          ymd: e.ymd,
          time: time,
        ),
        when: when,
      ),
    );
    if (notices.length >= 80) break;
  }
  await NotificationService.syncVisitSoonReminders(notices);
}
