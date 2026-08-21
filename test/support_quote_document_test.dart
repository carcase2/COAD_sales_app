import 'dart:convert';
import 'dart:typed_data';

import 'package:coad_customer_calls/features/customer_support/support_quote_document.dart';
import 'package:coad_customer_calls/features/customer_support/support_quote_export.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  SupportQuoteDocument doc() => const SupportQuoteDocument(
    id: '1',
    customerName: '김현장',
    email: 'as@example.com',
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
    expect(supportQuoteMatches(doc(), 'as@example.com'), isTrue);
  });

  test('이메일·파일 이름을 만든다', () {
    expect(supportQuoteFileStem(doc()), 'AS견적서_김현장_2026-08-20');
    expect(
      supportQuoteFileStem(
        const SupportQuoteDocument(
          id: '2',
          customerName: 'a/b:c',
          ymd: '2026-01-01',
        ),
      ),
      'AS견적서_a_b_c_2026-01-01',
    );
    expect(supportQuoteEmailSubject(doc()), contains('김현장'));
    expect(
      supportQuoteEmailBody(doc(), totalLabel: '170,000원'),
      contains('170,000원'),
    );
  });

  test('이메일을 json에 남긴다', () {
    final parsed = SupportQuoteDocument.fromJson(doc().toJson());
    expect(parsed.email, 'as@example.com');
    expect(parsed.total, 170000);
  });

  test('견적서 이미지를 PDF로 감싼다', () async {
    final png = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
    );
    final pdf = await supportQuotePngToPdf(Uint8List.fromList(png));
    expect(pdf.length, greaterThan(100));
    expect(ascii.decode(pdf.take(4).toList()), '%PDF');
  });
}
