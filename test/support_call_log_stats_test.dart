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

  test('마무리·방문 완료만 완료이고 나머지는 미완료', () {
    expect(isSupportServiceStatusIncomplete(null), isTrue);
    expect(isSupportServiceStatusIncomplete(4), isTrue);
    expect(isSupportServiceStatusIncomplete(2), isTrue);
    expect(isSupportServiceStatusIncomplete(5), isTrue);
    expect(isSupportServiceStatusIncomplete(1), isFalse);
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

  test('견적서 발송예정에 발송완료 날짜를 남긴다', () {
    final planned = supportConsultOutcomeLine(
      SupportConsultOutcome.quoteSend,
      ymd: '2026-08-22',
    );
    expect(planned, '[결과: 견적서 발송 · 발송예정 2026-08-22]');
    final parsed = parseSupportConsultation('$planned\n단가 안내');
    expect(parsed.outcome, SupportConsultOutcome.quoteSend);
    expect(parsed.ymd, '2026-08-22');
    expect(parsed.sentYmd, isNull);
    final sent = rewriteSupportQuoteSentLine(
      '$planned\n단가 안내',
      sentYmd: '2026-08-23',
    );
    expect(sent, contains('발송완료 2026-08-23'));
    final done = parseSupportConsultation(sent);
    expect(done.sentYmd, '2026-08-23');
    expect(done.ymd, '2026-08-22');
    expect(done.body, '단가 안내');
    final cleared = rewriteSupportQuoteSentLine(sent);
    expect(parseSupportConsultation(cleared).sentYmd, isNull);
  });

  test('발송 완료된 견적서는 예정 알림에서 빼다', () {
    SupportCallLog log({required String id}) => SupportCallLog(
      id: id,
      customerName: id,
      customerPhone: '010',
      issue: 'x',
      serviceStatusId: kSupportStatusInProgress,
    );
    final summary = SupportDueScheduleSummary.fromEvents([
      SupportScheduleEvent(
        kind: SupportScheduleKind.quoteSend,
        ymd: '2026-08-20',
        log: log(id: 'open'),
      ),
      SupportScheduleEvent(
        kind: SupportScheduleKind.quoteSend,
        ymd: '2026-08-20',
        log: log(id: 'done'),
        quoteSentYmd: '2026-08-20',
      ),
    ], '2026-08-20');
    expect(summary.todaySend, 1);
  });

  test('방문 기록은 방문 요청으로 일정이 잡힌 뒤에만 필요하다', () {
    expect(supportVisitRecordAllowed(), isFalse);
    expect(
      supportVisitRecordAllowed(
        consultationDescriptions: ['[결과: 마무리]\n전화로 안내 완료'],
      ),
      isFalse,
    );
    expect(
      supportVisitRecordAllowed(
        consultationDescriptions: ['[결과: 구두 견적]\n견적 안내'],
      ),
      isFalse,
    );
    expect(
      supportVisitRecordAllowed(
        consultationDescriptions: ['[결과: 피드백 대기]\n전원 리셋 안내'],
      ),
      isFalse,
    );
    expect(
      supportVisitRecordAllowed(
        consultationDescriptions: ['[결과: 견적서 발송 · 발송예정 2026-08-22]\n발송'],
      ),
      isFalse,
    );
    expect(
      supportVisitRecordAllowed(
        consultationDescriptions: ['[결과: 방문 요청]\n일정 미정'],
      ),
      isFalse,
    );
    expect(
      supportVisitRecordAllowed(
        consultationDescriptions: ['[결과: 방문 요청 · 방문예정 2026-08-25]\n현장 확인'],
      ),
      isTrue,
    );
    expect(supportVisitRecordAllowed(visitDate: '2026-08-25'), isTrue);
    expect(
      supportVisitRecordAllowed(serviceStatusId: kSupportStatusVisitScheduled),
      isTrue,
    );
    expect(supportVisitRecordAllowed(existingVisitReportCount: 1), isTrue);
  });

  test('상담 결과 힌트는 마무리·피드백 대기·구두 견적·정식 견적서·방문이다', () {
    expect(
      supportConsultOutcomeHint(SupportConsultOutcome.closed),
      contains('끝냅니다'),
    );
    expect(
      supportConsultOutcomeHint(SupportConsultOutcome.feedbackWait),
      contains('다시 연락'),
    );
    expect(
      supportConsultOutcomeHint(SupportConsultOutcome.verbalQuote),
      contains('방문일'),
    );
    expect(
      supportConsultOutcomeHint(SupportConsultOutcome.quoteSend),
      contains('보낼 날'),
    );
    expect(
      supportConsultOutcomeHint(SupportConsultOutcome.visit),
      contains('방문 기록'),
    );
  });

  test('진행 상태 라벨', () {
    expect(supportCallLogProgressLabel(null), '미처리');
    expect(supportCallLogProgressLabel(4), '미처리');
    expect(supportCallLogProgressLabel(2), '답 대기·견적서');
    expect(supportCallLogProgressLabel(5), '방문예정');
    expect(supportCallLogProgressLabel(1), '완료');
  });

  test('다음 단계는 접수·상담·방문·입금 순이다', () {
    expect(
      supportFlowCue(serviceStatusId: 4, consultationCount: 0).progressLabel,
      '다음: 1차 상담',
    );
    expect(
      supportConsultOutcomeStatusId(SupportConsultOutcome.feedbackWait),
      kSupportStatusInProgress,
    );
    expect(
      parseSupportConsultation('[결과: 피드백 대기]\n전원 리셋 안내').outcome,
      SupportConsultOutcome.feedbackWait,
    );
    expect(
      supportFlowCue(
        serviceStatusId: kSupportStatusInProgress,
        consultationCount: 1,
        lastOutcome: SupportConsultOutcome.feedbackWait,
      ).progressLabel,
      '피드백 대기',
    );
    expect(
      supportFlowCue(
        serviceStatusId: kSupportStatusInProgress,
        consultationCount: 1,
        lastOutcome: SupportConsultOutcome.verbalQuote,
      ).progressLabel,
      '고객 전화 대기',
    );
    expect(
      supportFlowCue(
        serviceStatusId: kSupportStatusInProgress,
        consultationCount: 1,
        lastOutcome: SupportConsultOutcome.quoteSend,
        quoteSendYmd: '2026-08-22',
      ).progressLabel,
      '발송예정 2026-08-22',
    );
    expect(
      supportFlowCue(
        serviceStatusId: kSupportStatusInProgress,
        consultationCount: 1,
        lastOutcome: SupportConsultOutcome.quoteSend,
        quoteSendYmd: '2026-08-22',
        quoteSentYmd: '2026-08-23',
      ).progressLabel,
      '발송완료 2026-08-23',
    );
    expect(
      supportFlowCue(
        serviceStatusId: kSupportStatusVisitScheduled,
        canAddVisit: true,
        visitDate: '2026-08-25',
      ).progressLabel,
      '다음: 방문 2026-08-25',
    );
    expect(
      supportFlowCue(
        serviceStatusId: kSupportStatusCompleted,
        depositYmd: '2026-08-27',
        depositPaid: false,
      ).progressLabel,
      '입금대기 2026-08-27',
    );
    expect(
      supportFlowCue(serviceStatusId: kSupportStatusCompleted).action,
      SupportNextAction.done,
    );
  });

  test('완료된 접수는 방문 기록을 추가하지 않는다', () {
    expect(
      supportVisitRecordCanAdd(
        visitDate: '2026-08-25',
        serviceStatusId: kSupportStatusCompleted,
        existingVisitReportCount: 1,
      ),
      isFalse,
    );
    expect(
      supportVisitRecordCanAdd(
        visitDate: '2026-08-25',
        serviceStatusId: kSupportStatusVisitScheduled,
      ),
      isTrue,
    );
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

  test('피드백 대기는 2시간 뒤, 19시를 넘기면 다음날 9시', () {
    DateTime t(int h, [int m = 0]) => DateTime(2026, 9, 2, h, m);
    expect(nextSupportFeedbackWaitAt(t(15)), t(17));
    expect(nextSupportFeedbackWaitAt(t(16, 59)), t(18, 59));
    expect(nextSupportFeedbackWaitAt(t(17)), t(19));
    expect(nextSupportFeedbackWaitAt(t(17, 1)), DateTime(2026, 9, 3, 9));
    expect(nextSupportFeedbackWaitAt(t(18)), DateTime(2026, 9, 3, 9));
    expect(nextSupportFeedbackWaitAt(t(19)), DateTime(2026, 9, 3, 9));
    expect(nextSupportFeedbackWaitAt(t(22, 30)), DateTime(2026, 9, 3, 9));
    expect(
      supportFeedbackWaitNoticeTitle(
        const SupportCallLog(
          id: '1',
          customerName: '김현장',
          customerPhone: '010-0000-0000',
          issue: '모터',
        ),
      ),
      '[중] 피드백 대기',
    );
    expect(
      supportFeedbackWaitNoticeBody(
        const SupportCallLog(
          id: '1',
          customerName: '김현장',
          customerPhone: '010-0000-0000',
          issue: '모터',
        ),
      ),
      '[중] · 김현장 · 010-0000-0000 · 다시 확인해 주세요',
    );
    expect(
      supportFeedbackWaitNoticeTitle(
        const SupportCallLog(
          id: '2',
          customerName: '김현장',
          customerPhone: '010-0000-0000',
          issue: '[긴급도 상] 오버헤드도어\n현장: 한빛',
        ),
      ),
      '[상] 피드백 대기',
    );
  });
}
