import 'package:coad_customer_calls/data/support_call_log_repository.dart';

/// 홈 고객지원 달력: 방문예정 / 수금예정.
enum SupportHomeCalendarKind { visit, deposit }

bool isSupportVisitEventOpen(SupportScheduleEvent e) {
  if (e.kind != SupportScheduleKind.visit) return false;
  if (e.log.serviceStatusId == kSupportStatusCompleted) return false;
  final cap = (e.caption ?? '').trim();
  if (cap == '방문완료' || cap.startsWith('방문완료')) return false;
  final report = e.visitReport;
  if (report != null &&
      report.completed &&
      report.visitYmd.trim() == e.ymd.trim()) {
    return false;
  }
  return true;
}

bool isSupportDepositEventOpen(SupportScheduleEvent e) {
  if (e.kind != SupportScheduleKind.deposit) return false;
  return e.depositPaid != true;
}

List<SupportScheduleEvent> supportHomeCalendarEvents(
  List<SupportScheduleEvent> events, {
  required SupportHomeCalendarKind kind,
}) {
  final out = <SupportScheduleEvent>[];
  for (final e in events) {
    switch (kind) {
      case SupportHomeCalendarKind.visit:
        if (isSupportVisitEventOpen(e)) out.add(e);
      case SupportHomeCalendarKind.deposit:
        if (isSupportDepositEventOpen(e)) out.add(e);
    }
  }
  out.sort((a, b) {
    final byDay = a.ymd.compareTo(b.ymd);
    if (byDay != 0) return byDay;
    final at = (a.scheduledTime ?? a.actualTime ?? a.log.visitTime ?? '').trim();
    final bt = (b.scheduledTime ?? b.actualTime ?? b.log.visitTime ?? '').trim();
    return at.compareTo(bt);
  });
  return out;
}

List<SupportScheduleEvent> supportHomeCalendarEventsOnDay(
  List<SupportScheduleEvent> events, {
  required SupportHomeCalendarKind kind,
  required String ymd,
}) {
  return supportHomeCalendarEvents(
    events,
    kind: kind,
  ).where((e) => e.ymd == ymd).toList();
}
