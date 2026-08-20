import 'package:coad_customer_calls/features/customer_support/support_quote_document.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  SupportQuoteDocument doc() => const SupportQuoteDocument(
    id: '1',
    customerName: '김현장',
    site: '수성 한빛',
    ymd: '2026-08-20',
    lines: [
      SupportQuoteLine(name: '모터', spec: '800N', qty: 2, unitPrice: 85000),
    ],
    note: '유상',
  );

  test('수량×단가로 합계를 낸다', () {
    expect(doc().total, 170000);
    expect(doc().lines.first.amount, 170000);
  });

  test('고객·현장·품목으로 검색한다', () {
    expect(supportQuoteMatches(doc(), ''), isTrue);
    expect(supportQuoteMatches(doc(), '김현장'), isTrue);
    expect(supportQuoteMatches(doc(), '한빛'), isTrue);
    expect(supportQuoteMatches(doc(), '모터'), isTrue);
    expect(supportQuoteMatches(doc(), '셔터'), isFalse);
  });
}
