import 'package:coad_customer_calls/features/unit_price/standard_unit_price.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('toStandardSizeBucket', () {
    test('2000~8000을 1000 단위 반올림', () {
      expect(toStandardSizeBucket(1999), 2000);
      expect(toStandardSizeBucket(2000), 2000);
      expect(toStandardSizeBucket(2499), 2000);
      expect(toStandardSizeBucket(2500), 3000);
      expect(toStandardSizeBucket(3600), 4000);
      expect(toStandardSizeBucket(8000), 8000);
      expect(toStandardSizeBucket(9100), 8000);
    });
  });

  group('describeStandardAdjustment', () {
    test('일괄 금액은 전체 n원으로 표현', () {
      expect(
        describeStandardAdjustment(
          type: 'amount',
          value: 100,
          cells: 55,
        ),
        '전체 100원 인상',
      );
      expect(
        describeStandardAdjustment(
          type: 'percent',
          value: -10,
          cells: 6,
        ),
        '전체 10% 인하',
      );
    });

    test('엑셀용 CSV는 가로=폭 세로=높이', () {
      final csv = buildStandardPriceGridCsv(
        title: '차고문 / STANDARD',
        widths: const [4000, 5000],
        heights: const [2150, 2700],
        cellText: (w, h) => w == 4000 && h == 2150 ? '3200000' : 'X',
      );
      expect(csv, contains('차고문 / STANDARD'));
      expect(csv, contains('높이\\폭,4000,5000'));
      expect(csv, contains('2150,3200000,X'));
    });

    test('개별 수정은 사이즈와 변동액', () {
      expect(
        describeStandardAdjustment(
          type: 'manual',
          value: 200000,
          cells: 1,
          id: 'a1',
          logs: [
            (
              adjustmentId: 'a1',
              widthMm: 4000,
              heightMm: 2150,
              oldPrice: 3200000,
              newPrice: 3400000,
            ),
          ],
        ),
        '4000×2150 200,000원 인상',
      );
    });
  });

  group('applyPriceAdjustment', () {
    test('퍼센트 인상은 0원 셀을 유지', () {
      expect(
        applyPriceAdjustment(
          oldPrice: 0,
          type: StandardAdjustType.percent,
          value: 10,
        ),
        0,
      );
      expect(
        applyPriceAdjustment(
          oldPrice: 1000000,
          type: StandardAdjustType.percent,
          value: 10,
        ),
        1100000,
      );
    });

    test('마이너스 %·금액으로 인하한다', () {
      expect(
        applyPriceAdjustment(
          oldPrice: 1000000,
          type: StandardAdjustType.percent,
          value: -10,
        ),
        900000,
      );
      expect(
        applyPriceAdjustment(
          oldPrice: 1000000,
          type: StandardAdjustType.amount,
          value: -100000,
        ),
        900000,
      );
    });

    test('금액 인상은 0 아래로 내려가지 않음', () {
      expect(
        applyPriceAdjustment(
          oldPrice: 100000,
          type: StandardAdjustType.amount,
          value: 50000,
        ),
        150000,
      );
      expect(
        applyPriceAdjustment(
          oldPrice: 30000,
          type: StandardAdjustType.amount,
          value: -50000,
        ),
        0,
      );
    });
  });

  group('inferStandardPrice', () {
    test('가까운 격자를 참조해 표준단가를 찾음', () {
      const cells = [
        StandardPriceCell(widthMm: 3000, heightMm: 4000, price: 800000),
        StandardPriceCell(widthMm: 4000, heightMm: 4000, price: 900000),
        StandardPriceCell(widthMm: 3000, heightMm: 3000, price: 700000),
      ];
      final result = inferStandardPrice(
        cells: cells,
        widthMm: 3200,
        heightMm: 4100,
      );
      expect(result.bucketWidth, 3000);
      expect(result.bucketHeight, 4000);
      expect(result.isExactBucket, isFalse);
      expect(result.match?.price, 800000);
      expect(result.nearby.map((c) => c.price), containsAll([900000, 700000]));
    });
  });
}
