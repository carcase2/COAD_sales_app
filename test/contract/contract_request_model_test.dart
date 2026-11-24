import 'package:coad_customer_calls/features/contract/contract_request_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parseWon', () {
    expect(parseWon('550만원'), 5500000);
    expect(parseWon('5,500,000원'), 5500000);
    expect(parseWon('1억 2천만원'), 120000000);
    expect(parseWon('2천5백50만'), 25500000);
    expect(parseWon('abc'), isNull);
  });

  test('단톡방 글 붙여 넣기 → 글 복사 왕복', () {
    const raw = '''[계약서 작성 요청]

*현장명: 비렉스테크
*공사장소: 경기도 화성시
*품목/ 수량: C-1(스탠다드) 1대
*공사기간: 26/12/1-26/12/12
*계약금액: 공급가 550만원
*선급금 30%
*기성금 70%
선급금지급시기: 26.11.26
기성금지급시기: 공사완료 후 20일 이내
*선급금 증권 여부x
*계약이행보증금 여부O
*하자보증금 여부x
*무상보증기간 하드웨어 1년
*보내는 방법: 메일 (a@b.com)
*통장사본 함께 보내기''';
    final f = ContractFields();
    expect(applyContractRequestText(f, raw), greaterThan(10));
    expect(f.siteName, '비렉스테크');
    expect(f.periodStart, '2026-12-01');
    expect(f.periodEnd, '2026-12-12');
    expect(f.supplyAmount, 5500000);
    expect(f.advanceRate, 30);
    expect(f.performanceBond, true);
    expect(f.advanceBond, false);
    expect(f.mailTo, 'a@b.com');
    expect(f.withBankbook, true);
    expect(f.note, '');
    expect(validateContractFields(f), isNull);
    expect(contractRequestText(f), raw);
  });

  test('검사', () {
    expect(validateContractFields(ContractFields()), '현장명을 입력해 주세요.');
    final f = ContractFields(siteName: 'a', advanceRate: 60, progressRate: 50);
    expect(validateContractFields(f), contains('100%'));
  });
}
