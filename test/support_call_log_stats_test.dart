import 'package:coad_customer_calls/core/utils/date_seoul.dart';
import 'package:coad_customer_calls/data/support_call_log_repository.dart';
import 'package:coad_customer_calls/features/customer_support/customer_support_intake_screen.dart';
import 'package:coad_customer_calls/features/customer_support/support_due_schedule.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('service_status 4 and empty count as pending', () {
    expect(isSupportServiceStatusPending(null), isTrue);
    expect(isSupportServiceStatusPending(4), isTrue);
    expect(isSupportServiceStatusPending(1), isFalse);
    expect(isSupportServiceStatusPending(5), isFalse);
  });

  test('parseSupportIssueBody reads urgency, product, site, body', () {
    final parsed = parseSupportIssueBody('[긴급도 상] 오버헤드도어\n현장: 항\n가');
    expect(parsed.urgency, SupportUrgency.high);
    expect(parsed.productName, '오버헤드도어');
    expect(parsed.siteName, '항');
    expect(parsed.body, '가');
  });

  test('parseSupportIssueBody keeps plain issue as body', () {
    final parsed = parseSupportIssueBody('111');
    expect(parsed.urgency, SupportUrgency.mid);
    expect(parsed.productName, '');
    expect(parsed.siteName, '');
    expect(parsed.body, '111');
  });

  test('parseSupportUrlList reads json array and list', () {
    expect(parseSupportUrlList(null), isEmpty);
    expect(parseSupportUrlList(['a.jpg', 'b.pdf']), ['a.jpg', 'b.pdf']);
    expect(parseSupportUrlList('["https://x/a.jpg"]'), ['https://x/a.jpg']);
  });

  test('consult outcome maps to status and parse line', () {
    expect(
      supportConsultOutcomeStatusId(SupportConsultOutcome.closed),
      kSupportStatusCompleted,
    );
    expect(
      supportConsultOutcomeStatusId(SupportConsultOutcome.visit),
      kSupportStatusVisitScheduled,
    );
    final line = supportConsultOutcomeLine(
      SupportConsultOutcome.visit,
      ymd: '2026-08-25',
    );
    final parsed = parseSupportConsultation('$line\n현장 확인 후 교체');
    expect(parsed.outcome, SupportConsultOutcome.visit);
    expect(parsed.ymd, '2026-08-25');
    expect(parsed.body, '현장 확인 후 교체');
  });

  test('naive support timestamps are UTC shown as KST', () {
    final utc = parseSupabaseTimestampUtc('2026-08-20T07:18:31.084362');
    expect(utc, isNotNull);
    expect(utc!.isUtc, isTrue);
    expect(utc.hour, 7);
    expect(formatSeoulMonthDayTime(utc), '8/20 16:18');
    expect(formatSeoulDateTimeDots(utc), '2026.08.20 16:18');
  });

  test('due schedule summary skips completed and splits today vs overdue', () {
    SupportCallLog log({required String id, int? status}) => SupportCallLog(
      id: id,
      customerName: id,
      customerPhone: '010',
      issue: 'x',
      serviceStatusId: status,
    );
    const today = '2026-08-20';
    final summary = SupportDueScheduleSummary.fromEvents([
      SupportScheduleEvent(
        kind: SupportScheduleKind.visit,
        ymd: today,
        log: log(id: 'v1', status: kSupportStatusVisitScheduled),
      ),
      SupportScheduleEvent(
        kind: SupportScheduleKind.visit,
        ymd: '2026-08-18',
        log: log(id: 'v2', status: kSupportStatusVisitScheduled),
      ),
      SupportScheduleEvent(
        kind: SupportScheduleKind.visit,
        ymd: '2026-08-18',
        log: log(id: 'done', status: kSupportStatusCompleted),
      ),
      SupportScheduleEvent(
        kind: SupportScheduleKind.quoteSend,
        ymd: today,
        log: log(id: 's1', status: kSupportStatusInProgress),
      ),
      SupportScheduleEvent(
        kind: SupportScheduleKind.quoteSend,
        ymd: '2026-08-01',
        log: log(id: 's2'),
      ),
      SupportScheduleEvent(
        kind: SupportScheduleKind.visit,
        ymd: '2026-08-25',
        log: log(id: 'future', status: kSupportStatusVisitScheduled),
      ),
    ], today);
    expect(summary.todayVisit, 1);
    expect(summary.overdueVisit, 1);
    expect(summary.todaySend, 1);
    expect(summary.overdueSend, 1);
    expect(summary.hasAny, isTrue);
    expect(summary.body, '오늘 방문 1건 · 오늘 발송 1건 · 지난 방문 1건 · 지난 발송 1건');
  });

  test('due schedule summary empty when nothing pending', () {
    expect(
      SupportDueScheduleSummary.fromEvents(const [], '2026-08-20').hasAny,
      isFalse,
    );
    expect(SupportDueScheduleSummary.empty.body, isEmpty);
  });
}
