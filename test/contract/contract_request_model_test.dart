import 'package:coad_customer_calls/data/business_card_ocr.dart';
import 'package:coad_customer_calls/features/contract/contract_request_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('명함 인식 결과 → 계약서 발주자 칸', () {
    final doc = contractDocFromBusinessCard(
      BusinessCardResult(
        name: '김철수',
        company: '(주)비렉스테크',
        title: '과장',
        department: '공무팀',
        phone: '010-1234-5678',
        officePhone: '031-123-4567',
        email: 'kim@example.com',
        address: '경기도 화성시',
      ),
    );
    expect(doc.docType, 'business_card');
    expect(
      doc.contactLine,
      '담당자: 김철수 공무팀 과장 / 010-1234-5678 / kim@example.com',
    );
    final s = contractSuggestions(
      doc,
      'business_card',
      ContractFields(sendMethod: '메일'),
    );
    expect(s.map((e) => e.key), ['client_name', 'client_address', 'mail_to']);
  });

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
    expect(validateContractFields(f), '발주자 상호를 입력해 주세요.');
    f.clientName = '비렉스테크';
    expect(validateContractFields(f), isNull);
    expect(contractRequestText(f), raw);
  });

  test('검사', () {
    expect(validateContractFields(ContractFields()), '현장명을 입력해 주세요.');
    final f = ContractFields(siteName: 'a', advanceRate: 60, progressRate: 50);
    expect(validateContractFields(f), contains('100%'));
  });

  test('사업자번호·날짜 따라오기·품목 더하기', () {
    expect(formatBizNo('1234567890'), '123-45-67890');
    final f = ContractFields(
      siteName: 'a',
      clientName: 'b',
      clientBizNo: '123',
    );
    expect(validateContractFields(f), contains('10자리'));
    expect(followStart(null, null, '2026-12-01'), '2026-12-01');
    expect(followStart('2026-12-01', '2026-12-01', '2026-12-05'), '2026-12-05');
    expect(followStart('2026-12-01', '2026-12-20', '2026-12-05'), '2026-12-20');
    expect(addContractItem('', 'A', 1), 'A 1대');
    expect(addContractItem('A 1대, B 2대', 'B', 1), 'A 1대, B 3대');
  });

  test('인식 결과 제안', () {
    final doc = RecognizedDocument({
      'doc_type': 'business_license',
      'company_name': '㈜비렉스',
      'biz_no': '123-45-67890',
      'representative': '홍길동',
      'address': '',
    });
    final cur = ContractFields(clientName: '비렉스');
    final s = contractSuggestions(doc, 'business_license', cur);
    expect(s.map((e) => e.key), ['client_biz_no', 'client_rep']);
    final card = RecognizedDocument({
      'doc_type': 'business_card',
      'person_name': '김',
      'mobile': '010',
      'email': 'a@b.com',
    });
    expect(card.contactLine, '담당자: 김 / 010 / a@b.com');
    expect(
      contractSuggestions(card, 'business_card', cur).single.key,
      'mail_to',
    );
  });
}
