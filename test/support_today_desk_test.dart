import 'package:coad_customer_calls/data/support_call_log_repository.dart';
import 'package:coad_customer_calls/features/customer_support/support_today_desk.dart';
import 'package:coad_customer_calls/features/customer_support/support_today_desk_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

SupportCallLog _log({
  required String id,
  String name = '현장',
  int? status,
  String? visitDate,
  String? visitTime,
  String issue = '모터',
}) {
  return SupportCallLog(
    id: id,
    customerName: name,
    customerPhone: '01012345678',
    issue: issue,
    serviceStatusId: status,
    visitDate: visitDate,
    visitTime: visitTime,
  );
}

void main() {
  test('오늘 데스크는 미처리·방문·미발송·수금을 우선순위로 모은다', () {
    const today = '2026-09-04';
    final pending = _log(id: 'p1', name: '오늘접수', status: 4);
    final doneToday = _log(id: 'd1', name: '끝난접수', status: 1);
    final visit = _log(
      id: 'v1',
      name: '오늘방문',
      status: kSupportStatusVisitScheduled,
      visitDate: today,
      visitTime: '14:00',
    );
    final overdueVisit = _log(
      id: 'v0',
      name: '지난방문',
      status: kSupportStatusVisitScheduled,
      visitDate: '2026-09-01',
      visitTime: '10:00',
    );
    final quoteLog = _log(
      id: 'q1',
      name: '견적현장',
      status: kSupportStatusInProgress,
    );
    final depositLog = _log(
      id: 'c1',
      name: '수금현장',
      status: kSupportStatusCompleted,
    );

    final desk = buildSupportTodayDesk(
      todayYmd: today,
      todayReceptions: [pending, doneToday],
      dueEvents: [
        SupportScheduleEvent(
          kind: SupportScheduleKind.visit,
          ymd: today,
          log: visit,
          scheduledTime: '14:00',
        ),
        SupportScheduleEvent(
          kind: SupportScheduleKind.visit,
          ymd: '2026-09-01',
          log: overdueVisit,
          scheduledTime: '10:00',
        ),
        SupportScheduleEvent(
          kind: SupportScheduleKind.visit,
          ymd: today,
          log: _log(id: 'doneV', name: '방문완료', status: 1, visitDate: today),
        ),
        SupportScheduleEvent(
          kind: SupportScheduleKind.quoteSend,
          ymd: today,
          log: quoteLog,
        ),
        SupportScheduleEvent(
          kind: SupportScheduleKind.quoteSend,
          ymd: today,
          log: quoteLog,
          quoteSentYmd: today,
        ),
        SupportScheduleEvent(
          kind: SupportScheduleKind.deposit,
          ymd: '2026-09-02',
          log: depositLog,
          amount: 150000,
          depositPaid: false,
        ),
      ],
    );

    expect(desk.todayReception, 2);
    expect(desk.todayPending, 1);
    expect(desk.todayVisit, 1);
    expect(desk.overdueVisit, 1);
    expect(desk.unsentQuote, 1);
    expect(desk.overdueDeposit, 1);
    expect(desk.todayDeposit, 0);
    expect(desk.depositDue, 1);
    expect(desk.items.map((e) => e.kind).toList(), [
      SupportDeskItemKind.overdueVisit,
      SupportDeskItemKind.todayPending,
      SupportDeskItemKind.todayVisit,
      SupportDeskItemKind.unsentQuote,
      SupportDeskItemKind.overdueDeposit,
    ]);
    expect(desk.items.first.actionLabel, '방문 기록');
    expect(desk.items[1].actionLabel, '상담');
    expect(supportDeskSiteTitle(pending), '오늘접수');
  });

  test('현장명이 있으면 고객 이름 대신 현장명을 쓴다', () {
    final log = _log(
      id: 's1',
      name: '김고객',
      issue: '[긴급도 상] 오버헤드도어\n현장: 항만창고\n소음',
    );
    expect(supportDeskSiteTitle(log), '항만창고');
  });

  testWidgets('오늘 데스크 카드에 접수·방문·수금·견적이 보인다', (tester) async {
    final desk = SupportTodayDesk(
      todayYmd: '2026-09-04',
      todayReception: 3,
      todayPending: 1,
      todayVisit: 2,
      overdueVisit: 1,
      unsentQuote: 4,
      todayDeposit: 0,
      overdueDeposit: 2,
      items: [],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SupportTodayDeskCard(
            desk: desk,
            onTapReception: () {},
            onTapVisit: () {},
            onTapDeposit: () {},
            onTapQuote: () {},
            onTapItem: (_) {},
            onTapAction: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('오늘 접수'), findsOneWidget);
    expect(find.text('오늘 방문'), findsOneWidget);
    expect(find.text('수금'), findsOneWidget);
    expect(find.text('견적 미발송'), findsOneWidget);
    expect(find.text('고객 대기'), findsOneWidget);
    expect(find.text('피드백'), findsOneWidget);
    expect(find.text('구두 견적'), findsOneWidget);
    expect(find.text('발송 후'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('2'), findsNWidgets(2));
    expect(find.text('4'), findsOneWidget);
    expect(find.text('미처리 1'), findsOneWidget);
    expect(find.text('지난 1'), findsOneWidget);
    expect(find.text('지난 2'), findsOneWidget);
  });
}
