import 'package:coad_customer_calls/data/support_visit_report.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('유상 방문 기록 왕복', () {
    const report = SupportVisitReport(
      visitYmd: '2026-08-20',
      visitTime: '10:00',
      completed: true,
      paid: true,
      amount: 85000,
      depositYmd: '2026-08-27',
      parts: ['리모컨', '모터'],
      photoUrls: ['https://example.com/a.jpg'],
      notes: '모터 교체 완료',
      createdBy: '김경덕',
    );
    final raw = serializeSupportVisitReport(report);
    expect(isSupportVisitReportText(raw), isTrue);
    final parsed = parseSupportVisitReport(raw, createdBy: '김경덕');
    expect(parsed, isNotNull);
    expect(parsed!.visitYmd, '2026-08-20');
    expect(parsed.visitTime, '10:00');
    expect(parsed.completed, isTrue);
    expect(parsed.isPaid, isTrue);
    expect(parsed.amount, 85000);
    expect(parsed.depositYmd, '2026-08-27');
    expect(parsed.depositPaid, isFalse);
    expect(parsed.parts, ['리모컨', '모터']);
    expect(parsed.photoUrls, ['https://example.com/a.jpg']);
    expect(parsed.notes, '모터 교체 완료');
    expect(parsed.createdBy, '김경덕');
  });

  test('무상이면 금액·입금일을 넣지 않는다', () {
    const report = SupportVisitReport(
      visitYmd: '2026-08-20',
      visitTime: '11:00',
      completed: true,
      paid: false,
      amount: 1000,
      depositYmd: '2026-08-21',
      notes: '무상 점검',
    );
    final parsed = parseSupportVisitReport(serializeSupportVisitReport(report));
    expect(parsed!.isPaid, isFalse);
    expect(parsed.amount, isNull);
    expect(parsed.depositYmd, isNull);
    expect(parsed.visitTime, '11:00');
    expect(parsed.notes, '무상 점검');
  });

  test('미완료면 다음 방문일·시간이 남는다', () {
    const report = SupportVisitReport(
      visitYmd: '2026-08-20',
      visitTime: '09:00',
      completed: false,
      paid: false,
      nextVisitYmd: '2026-08-25',
      nextVisitTeamId: 'team-1',
      nextVisitTime: '10:00',
      notes: '부품 대기',
    );
    final parsed = parseSupportVisitReport(serializeSupportVisitReport(report));
    expect(parsed!.completed, isFalse);
    expect(parsed.visitTime, '09:00');
    expect(parsed.nextVisitYmd, '2026-08-25');
    expect(parsed.nextVisitTime, '10:00');
  });

  test('입금완료 여부를 저장한다', () {
    const report = SupportVisitReport(
      visitYmd: '2026-08-20',
      visitTime: '14:00',
      completed: true,
      paid: true,
      amount: 50000,
      depositYmd: '2026-08-27',
      depositPaid: true,
      notes: '입금 확인',
    );
    final parsed = parseSupportVisitReport(serializeSupportVisitReport(report));
    expect(parsed!.depositPaid, isTrue);
    expect(parsed.copyWith(depositPaid: false).depositPaid, isFalse);
  });

  test('상담 텍스트는 방문 기록이 아니다', () {
    expect(isSupportVisitReportText('[결과: 방문 요청 · 방문예정 2026-08-20]'), isFalse);
    expect(parseSupportVisitReport('현장 확인'), isNull);
  });

  test('완료+유상은 금액·입금예정일이 필요하다', () {
    expect(
      supportVisitReportIssue(
        const SupportVisitReport(
          visitYmd: '2026-08-20',
          visitTime: '10:00',
          completed: true,
          paid: true,
          notes: '교체 완료',
        ),
      ),
      '유상이면 금액을 입력해 주세요.',
    );
    expect(
      supportVisitReportIssue(
        const SupportVisitReport(
          visitYmd: '2026-08-20',
          visitTime: '10:00',
          completed: true,
          paid: true,
          amount: 85000,
          notes: '교체 완료',
        ),
      ),
      '유상이면 입금예정일을 선택해 주세요.',
    );
    expect(
      supportVisitReportIssue(
        const SupportVisitReport(
          visitYmd: '2026-08-20',
          visitTime: '10:00',
          completed: true,
          paid: true,
          amount: 85000,
          depositYmd: '2026-08-27',
          notes: '교체 완료',
        ),
      ),
      isNull,
    );
  });

  test('미완료는 다음 방문일·팀이 필요하고 유상은 보지 않는다', () {
    expect(
      supportVisitReportIssue(
        const SupportVisitReport(
          visitYmd: '2026-08-20',
          completed: false,
          paid: true,
          amount: 1000,
          notes: '부품 대기',
        ),
      ),
      '방문 시간을 선택해 주세요.',
    );
    expect(
      supportVisitReportIssue(
        const SupportVisitReport(
          visitYmd: '2026-08-20',
          visitTime: '10:00',
          completed: false,
          paid: true,
          amount: 1000,
          notes: '부품 대기',
        ),
      ),
      '미완료이면 다음 방문일을 선택해 주세요.',
    );
    expect(
      supportVisitReportIssue(
        const SupportVisitReport(
          visitYmd: '2026-08-20',
          visitTime: '10:00',
          completed: false,
          paid: false,
          nextVisitYmd: '2026-08-25',
          notes: '부품 대기',
        ),
      ),
      '미완료이면 다음 방문 팀을 선택해 주세요.',
    );
    expect(
      supportVisitReportIssue(
        const SupportVisitReport(
          visitYmd: '2026-08-20',
          visitTime: '10:00',
          completed: false,
          paid: false,
          nextVisitYmd: '2026-08-25',
          nextVisitTeamId: 'team-1',
          notes: '부품 대기',
        ),
      ),
      '미완료이면 다음 방문 시간을 선택해 주세요.',
    );
    expect(
      supportVisitReportIssue(
        const SupportVisitReport(
          visitYmd: '2026-08-20',
          visitTime: '10:00',
          completed: false,
          paid: false,
          nextVisitYmd: '2026-08-25',
          nextVisitTeamId: 'team-1',
          nextVisitTime: '10:00',
          notes: '부품 대기',
        ),
      ),
      isNull,
    );
  });

  test('완료+무상은 금액 없이 저장한다', () {
    expect(
      supportVisitReportIssue(
        const SupportVisitReport(
          visitYmd: '2026-08-20',
          visitTime: '10:00',
          completed: true,
          paid: false,
          notes: '무상 점검',
        ),
      ),
      isNull,
    );
  });
}
