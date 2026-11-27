import 'package:coad_customer_calls/data/business_card_ocr.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('명함 번호 꼬리(범위·대표) 떼기', () {
    expect(firstCardPhone('(055)343-7715~6'), '(055)343-7715');
    expect(firstCardPhone('033-252-5807~ 5808'), '033-252-5807');
    expect(firstCardPhone('(02)421-4600(代)'), '(02)421-4600');
    expect(firstCardPhone('010-2654-6278'), '010-2654-6278');
  });

  test('Claude 명함 결과 → 명함첩 초안 번호 형식', () {
    final r = BusinessCardResult.fromClaudeCard({
      'name': '배재훈',
      'company': '건영산업(주)',
      'department': '생산팀',
      'title': '사원',
      'mobile': '010-6558-9171',
      'phone': '(055)343-7715~6',
      'fax': '(055)346-7353',
    });
    final d = businessCardDraftFromResult(r);
    expect(d.mobilePhone, '010-6558-9171');
    expect(d.officePhone, '055-343-7715');
    expect(d.faxPhone, '055-346-7353');
    expect(d.title, '생산팀 사원');
  });
}
