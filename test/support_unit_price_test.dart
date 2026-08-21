import 'package:coad_customer_calls/features/customer_support/support_unit_price.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  SupportUnitPriceItem item({
    String name = '모터',
    String spec = '800N',
    int? price = 85000,
    String note = '유상',
  }) => SupportUnitPriceItem(
    id: '1',
    name: name,
    spec: spec,
    price: price,
    note: note,
  );

  test('빈 검색은 모두 통과', () {
    expect(supportUnitPriceMatches(item(), ''), isTrue);
    expect(supportUnitPriceMatches(item(), '  '), isTrue);
  });

  test('품명·규격·비고·금액으로 검색한다', () {
    expect(supportUnitPriceMatches(item(), '모터'), isTrue);
    expect(supportUnitPriceMatches(item(), '800'), isTrue);
    expect(supportUnitPriceMatches(item(), '유상'), isTrue);
    expect(supportUnitPriceMatches(item(), '85000'), isTrue);
    expect(supportUnitPriceMatches(item(), '리모컨'), isFalse);
  });
}
