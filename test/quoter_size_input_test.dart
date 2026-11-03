import 'package:coad_customer_calls/features/quoter/quoter_size_input.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseShutterSizePair', () {
    test('여러 표기에서 폭·높이를 읽는다', () {
      expect(parseShutterSizePair('3000x2500'), (width: 3000, height: 2500));
      expect(parseShutterSizePair('3,000 × 2,500'), (width: 3000, height: 2500));
      expect(parseShutterSizePair('W3000 H2500'), (width: 3000, height: 2500));
      expect(parseShutterSizePair('규격 4500*3200 입니다'), (width: 4500, height: 3200));
      expect(parseShutterSizePair('3.0m x 2.5m'), (width: 3000, height: 2500));
    });

    test('숫자가 하나뿐이거나 규격이 아니면 null', () {
      expect(parseShutterSizePair('3000'), isNull);
      expect(parseShutterSizePair(''), isNull);
      expect(parseShutterSizePair('010-1234-5678'), isNull);
    });
  });

  group('quoterQuickSizes', () {
    test('최근 값이 앞에 오고 기본값에서 중복을 뺀다', () {
      final sizes = quoterQuickSizes(
        defaults: const [2500, 3000, 3500],
        recent: const [3000, 9000, 3000],
      );
      expect(sizes.map((s) => s.mm).toList(), [3000, 9000, 2500, 3500]);
      expect(sizes.where((s) => s.recent).length, 2);
    });

    test('최근 값은 축마다 3개까지', () {
      final sizes = quoterQuickSizes(
        defaults: const [2500],
        recent: const [4000, 4100, 4200, 4300],
      );
      expect(sizes.where((s) => s.recent).map((s) => s.mm), [4000, 4100, 4200]);
    });
  });

  group('quoterTableClampNote', () {
    test('범위 안이면 null', () {
      expect(quoterTableClampNote(3000, 2500), isNull);
      expect(quoterTableClampNote(8000, 2000), isNull);
    });

    test('넘는 축을 몇 mm로 계산했는지 알린다', () {
      expect(
        quoterTableClampNote(9000, 3000),
        '폭 9,000 → 8,000mm 기준 금액 · 별도 확인',
      );
      expect(
        quoterTableClampNote(10500, 1500),
        '폭 10,500 → 8,000 · 높이 1,500 → 2,000mm 기준 금액 · 별도 확인',
      );
    });
  });
}
