import 'package:coad_customer_calls/data/sales_call_consultation.dart';
import 'package:coad_customer_calls/models/sales_call.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('nextConsultationCallStage', () {
    expect(nextConsultationCallStage(0), 1);
    expect(nextConsultationCallStage(2), 3);
  });

  test('validate — 미결정 예정일 필수', () {
    expect(
      () => validateConsultationSubmit(
        consultationContent: '내용',
        statusId: CallStatusIds.undecided,
        nextScheduledDateYmd: null,
        unsuccessfulReason: null,
      ),
      throwsA(isA<SalesCallConsultationValidationException>()),
    );
    expect(
      () => validateConsultationSubmit(
        consultationContent: '내용',
        statusId: CallStatusIds.undecided,
        nextScheduledDateYmd: '2026-06-01',
        unsuccessfulReason: null,
      ),
      returnsNormally,
    );
  });

  test('validate — 수주 상담내용 선택', () {
    expect(
      () => validateConsultationSubmit(
        consultationContent: '',
        statusId: CallStatusIds.won,
        nextScheduledDateYmd: null,
        unsuccessfulReason: null,
      ),
      returnsNormally,
    );
  });

  test('validate — 미수주 사유 필수, 상담내용 선택', () {
    expect(
      () => validateConsultationSubmit(
        consultationContent: '',
        statusId: CallStatusIds.lost,
        nextScheduledDateYmd: null,
        unsuccessfulReason: null,
      ),
      throwsA(isA<SalesCallConsultationValidationException>()),
    );
    expect(
      () => validateConsultationSubmit(
        consultationContent: '',
        statusId: CallStatusIds.lost,
        nextScheduledDateYmd: null,
        unsuccessfulReason: '가격',
      ),
      returnsNormally,
    );
    expect(
      () => validateConsultationSubmit(
        consultationContent: '내용',
        statusId: CallStatusIds.lost,
        nextScheduledDateYmd: null,
        unsuccessfulReason: '가격',
      ),
      returnsNormally,
    );
  });

  test('callHistoryStatusText — 2차+ 단순문의는 기타', () {
    expect(
      callHistoryStatusText(
        statusId: CallStatusIds.simpleInquiry,
        statusName: '단순문의',
        callStage: 2,
      ),
      '기타',
    );
    expect(
      callHistoryStatusText(
        statusId: CallStatusIds.undecided,
        statusName: '미결정',
        callStage: 1,
      ),
      '미결정',
    );
  });

  test('lastConsultationSnippet — 최신 이력 한 줄', () {
    expect(lastConsultationSnippet(const []), isNull);
    expect(
      lastConsultationSnippet([
        {
          'call_stage': 1,
          'call_date': '2026-08-01',
          'consultation_content': '견적 요청',
        },
        {
          'call_stage': 2,
          'call_date': '2026-08-10',
          'consultation_content': '재연락 예정',
        },
      ]),
      '재연락 예정',
    );
  });

  test('isFollowOverdue / followOverdueDays', () {
    expect(isFollowOverdue('2026-08-16', '2026-08-17'), isTrue);
    expect(isFollowOverdue('2026-08-17', '2026-08-17'), isFalse);
    expect(followOverdueDays('2026-08-15', '2026-08-17'), 2);
    expect(followOverdueDays('2026-08-17', '2026-08-17'), isNull);
  });

  test('consultationQuickDateChips — 오늘·내일·모레·다음 주 월', () {
    final chips = consultationQuickDateChips('2026-08-17');
    expect(chips.map((c) => c.label).toList(), [
      '오늘',
      '내일',
      '모레',
      '다음 주 월',
    ]);
    expect(chips.map((c) => c.ymd).toList(), [
      '2026-08-17',
      '2026-08-18',
      '2026-08-19',
      '2026-08-24',
    ]);
  });

  test('consultationFollowDateCountMessage — 건수별 안내', () {
    expect(
      consultationFollowDateCountMessage(ymd: '2026-08-20', count: 3),
      '8월 20일 (목)에 이미 3건이 예정되어 있습니다.',
    );
    expect(
      consultationFollowDateCountMessage(ymd: '2026-08-20', count: 0),
      '8월 20일 (목)에는 예정된 상담이 없습니다.',
    );
    expect(
      consultationFollowDateCountMessage(ymd: '2026-08-20', count: null),
      '8월 20일 (목) 예정 건수를 확인하지 못했습니다.',
    );
  });

  test('resolveNextScheduledDateForSave — 미결정만 날짜', () {
    expect(
      resolveNextScheduledDateForSave(CallStatusIds.undecided, '2026-06-01'),
      '2026-06-01',
    );
    expect(resolveNextScheduledDateForSave(CallStatusIds.won, '2026-06-01'), isNull);
    expect(
      resolveNextScheduledDateForSave(CallStatusIds.simpleInquiry, '2026-06-01'),
      isNull,
    );
  });

  test('registrationStatus', () {
    expect(registrationStatus(isSimpleInquiry: true).statusId, 4);
    expect(registrationStatus(isSimpleInquiry: true).callStage, 1);
    expect(registrationStatus(isSimpleInquiry: false).statusId, 1);
    expect(registrationStatus(isSimpleInquiry: false).callStage, 0);
  });

  test('orderCallHistoryForDisplay — call_stage가 다르면 높은 차수 우선', () {
    final ordered = orderCallHistoryForDisplay([
      {'call_stage': 1, 'call_date': '2026-05-01', 'consultation_content': 'a'},
      {'call_stage': 3, 'call_date': '2026-05-10', 'consultation_content': 'c'},
      {'call_stage': 2, 'call_date': '2026-05-05', 'consultation_content': 'b'},
    ]);
    expect(displayStageFromHistoryMap(ordered[0]), 3);
    expect(displayStageFromHistoryMap(ordered[1]), 2);
    expect(displayStageFromHistoryMap(ordered[2]), 1);
  });

  test('orderCallHistoryForDisplay — call_stage가 모두 1이면 시각 순 3→2→1', () {
    final ordered = orderCallHistoryForDisplay([
      {'call_stage': 1, 'call_date': '2026-05-01', 'consultation_content': 'a'},
      {'call_stage': 1, 'call_date': '2026-05-10', 'consultation_content': 'c'},
      {'call_stage': 1, 'call_date': '2026-05-05', 'consultation_content': 'b'},
    ]);
    expect(displayStageFromHistoryMap(ordered[0]), 3);
    expect(displayStageFromHistoryMap(ordered[1]), 2);
    expect(displayStageFromHistoryMap(ordered[2]), 1);
  });

  test('statusIdFromHistoryMap — status 텍스트로 id 해석', () {
    expect(
      statusIdFromHistoryMap({'status': '미수주'}),
      CallStatusIds.lost,
    );
    expect(
      statusIdFromHistoryMap({'status_id': CallStatusIds.won}),
      CallStatusIds.won,
    );
  });

  test('effectiveStatusId — sales_calls 종료 상태 우선', () {
    final call = SalesCall(
      id: 'test',
      statusId: CallStatusIds.lost,
      callHistory: [
        {
          'status_id': CallStatusIds.undecided,
          'call_stage': 4,
          'call_date': '2026-05-29',
        },
      ],
    );
    expect(call.effectiveStatusId(), CallStatusIds.lost);
    expect(call.canEnterFurtherConsultationRound(), isFalse);
  });

  test('canEnterFurtherConsultation — 미결정만 추가 상담', () {
    expect(canEnterFurtherConsultation(CallStatusIds.undecided), isTrue);
    expect(canEnterFurtherConsultation(CallStatusIds.won), isFalse);
    expect(canEnterFurtherConsultation(CallStatusIds.lost), isFalse);
    expect(canEnterFurtherConsultation(CallStatusIds.simpleInquiry), isFalse);
    expect(canEnterFurtherConsultation(CallStatusIds.designInquiry), isFalse);
    expect(canEnterFurtherConsultation(CallStatusIds.other), isFalse);
    expect(canEnterFurtherConsultation(null), isTrue);
  });

  test('SalesCall.effectiveUnsuccessfulReason — 미수주 이력 사유', () {
    final call = SalesCall(
      id: 'test',
      statusId: CallStatusIds.lost,
      callHistory: [
        {
          'status_id': CallStatusIds.lost,
          'call_stage': 2,
          'call_date': '2026-05-28',
          'unsuccessful_reason': '가격 경쟁력 부족',
        },
      ],
    );
    expect(call.effectiveUnsuccessfulReason(), '가격 경쟁력 부족');
    expect(
      SalesCall(
        id: 'x',
        statusId: CallStatusIds.won,
        callHistory: [
          {
            'status_id': CallStatusIds.won,
            'call_stage': 3,
            'call_date': '2026-05-29',
          },
          {
            'status_id': CallStatusIds.lost,
            'call_stage': 2,
            'call_date': '2026-05-28',
            'unsuccessful_reason': '가격 경쟁력 부족',
          },
        ],
      ).effectiveUnsuccessfulReason(),
      isNull,
    );
  });

  test('SalesCall.effectiveStatusLabel — sales_calls 종료 상태 우선', () {
    final wonMain = SalesCall(
      id: 'test',
      statusId: CallStatusIds.won,
      statusLabel: '수주',
      callHistory: [
        {
          'status_id': CallStatusIds.lost,
          'call_stage': 4,
          'call_date': '2026-05-28',
        },
      ],
    );
    expect(wonMain.effectiveStatusLabel(), '수주');

    final lostMain = SalesCall(
      id: 'test2',
      statusId: CallStatusIds.lost,
      callHistory: [
        {
          'status_id': CallStatusIds.undecided,
          'call_stage': 4,
          'call_date': '2026-05-29',
        },
      ],
    );
    expect(lostMain.effectiveStatusLabel(), '미수주');
  });
}
