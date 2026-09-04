import 'package:coad_customer_calls/data/support_call_log_repository.dart';
import 'package:coad_customer_calls/features/customer_support/support_schedule_filters.dart';
import 'package:flutter_test/flutter_test.dart';

SupportCallLog _log({
  required String id,
  int? status,
  String? visitDate,
  String? visitTime,
}) {
  return SupportCallLog(
    id: id,
    customerName: id,
    customerPhone: '01012345678',
    issue: '모터',
    serviceStatusId: status,
    visitDate: visitDate,
    visitTime: visitTime,
  );
}

void main() {
  test('홈 고객지원 달력은 방문예정·수금예정만 남긴다', () {
    const today = '2026-09-04';
    final visitOpen = SupportScheduleEvent(
      kind: SupportScheduleKind.visit,
      ymd: today,
      log: _log(
        id: 'v1',
        status: kSupportStatusVisitScheduled,
        visitDate: today,
        visitTime: '14:00',
      ),
      scheduledTime: '14:00',
    );
    final visitDone = SupportScheduleEvent(
      kind: SupportScheduleKind.visit,
      ymd: today,
      log: _log(id: 'v2', status: kSupportStatusCompleted, visitDate: today),
      caption: '방문완료',
    );
    final quote = SupportScheduleEvent(
      kind: SupportScheduleKind.quoteSend,
      ymd: today,
      log: _log(id: 'q1', status: kSupportStatusInProgress),
    );
    final depositOpen = SupportScheduleEvent(
      kind: SupportScheduleKind.deposit,
      ymd: today,
      log: _log(id: 'd1', status: kSupportStatusCompleted),
      amount: 200000,
      depositPaid: false,
    );
    final depositPaid = SupportScheduleEvent(
      kind: SupportScheduleKind.deposit,
      ymd: today,
      log: _log(id: 'd2', status: kSupportStatusCompleted),
      depositPaid: true,
    );

    final all = [visitOpen, visitDone, quote, depositOpen, depositPaid];
    final visits = supportHomeCalendarEvents(
      all,
      kind: SupportHomeCalendarKind.visit,
    );
    final deposits = supportHomeCalendarEvents(
      all,
      kind: SupportHomeCalendarKind.deposit,
    );

    expect(visits.map((e) => e.log.id), ['v1']);
    expect(deposits.map((e) => e.log.id), ['d1']);
    expect(
      supportHomeCalendarEventsOnDay(
        all,
        kind: SupportHomeCalendarKind.visit,
        ymd: today,
      ).single.log.id,
      'v1',
    );
  });
}
