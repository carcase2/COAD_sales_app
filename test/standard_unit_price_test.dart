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
        heightMm: 3900,
      );
      expect(result.bucketWidth, 3000);
      expect(result.bucketHeight, 4000);
      expect(result.isExactBucket, isFalse);
      expect(result.outOfRange, isFalse);
      expect(result.match?.price, 800000);
      expect(result.nearby.map((c) => c.price), containsAll([900000, 700000]));
    });

    test('X칸이 있어도 4001은 표 최대 초과로 불가', () {
      const cells = [
        StandardPriceCell(widthMm: 2000, heightMm: 2000, price: 3500000),
        StandardPriceCell(widthMm: 3000, heightMm: 3000, price: 3800000),
        StandardPriceCell(widthMm: 3000, heightMm: 4000, price: 4000000),
        StandardPriceCell(widthMm: 4000, heightMm: 4000, price: 4300000),
        StandardPriceCell(
          widthMm: 5000,
          heightMm: 4000,
          price: 0,
          available: false,
        ),
        StandardPriceCell(
          widthMm: 5000,
          heightMm: 5000,
          price: 0,
          available: false,
        ),
      ];
      final overWidth = inferStandardPrice(
        cells: cells,
        widthMm: 4001,
        heightMm: 4000,
      );
      expect(overWidth.outOfRange, isTrue);
      expect(overWidth.estimatedPrice, isNull);
      expect(
        describeSizeLookup(overWidth),
        '입력 4001 × 4000 · 폭 최대 4000mm까지 · 불가',
      );

      final overHeight = inferStandardPrice(
        cells: cells,
        widthMm: 4000,
        heightMm: 4001,
      );
      expect(overHeight.outOfRange, isTrue);
      expect(overHeight.estimatedPrice, isNull);
    });

    test('사이값이면 보간 예상단가', () {
      const cells = [
        StandardPriceCell(widthMm: 3000, heightMm: 4000, price: 800000),
        StandardPriceCell(widthMm: 4000, heightMm: 4000, price: 900000),
        StandardPriceCell(widthMm: 3000, heightMm: 3000, price: 700000),
        StandardPriceCell(widthMm: 4000, heightMm: 3000, price: 780000),
      ];
      final result = inferStandardPrice(
        cells: cells,
        widthMm: 3200,
        heightMm: 4000,
      );
      expect(result.isEstimated, isTrue);
      expect(result.estimatedPrice, 820000);
      expect(result.outOfRange, isFalse);
    });

    test('차고문은 2150 초과 시 2700 5단 가격', () {
      const garage = [
        StandardPriceCell(widthMm: 4000, heightMm: 2150, price: 3200000),
        StandardPriceCell(widthMm: 4500, heightMm: 2150, price: 3300000),
        StandardPriceCell(widthMm: 5000, heightMm: 2150, price: 3400000),
        StandardPriceCell(widthMm: 4000, heightMm: 2700, price: 3600000),
        StandardPriceCell(widthMm: 4500, heightMm: 2700, price: 3900000),
        StandardPriceCell(widthMm: 5000, heightMm: 2700, price: 4200000),
      ];
      final four = inferStandardPrice(
        cells: garage,
        widthMm: 4000,
        heightMm: 2150,
        ceilingHeights: true,
      );
      expect(four.estimatedPrice, 3200000);
      expect(four.isEstimated, isFalse);

      final overFour = inferStandardPrice(
        cells: garage,
        widthMm: 4000,
        heightMm: 2151,
        ceilingHeights: true,
      );
      expect(overFour.outOfRange, isFalse);
      expect(overFour.isEstimated, isFalse);
      expect(overFour.estimatedPrice, 3600000);
      expect(overFour.lowerHeight, 2700);
      expect(
        describeSizeLookup(overFour),
        '입력 4000 × 2151 · 높이 2151 → 2700 (5단)',
      );

      final midWidth = inferStandardPrice(
        cells: garage,
        widthMm: 4250,
        heightMm: 2400,
        ceilingHeights: true,
      );
      expect(midWidth.isEstimated, isTrue);
      expect(midWidth.estimatedPrice, 3750000);
      expect(midWidth.lowerHeight, 2700);

      final overFive = inferStandardPrice(
        cells: garage,
        widthMm: 4000,
        heightMm: 2701,
        ceilingHeights: true,
      );
      expect(overFive.outOfRange, isTrue);
      expect(overFive.estimatedPrice, isNull);
    });
  });

  group('sameSizeQuotes / formatStandardQuoteLine', () {
    test('같은 사이즈로 모델별 단가를 모은다', () {
      final quotes = sameSizeQuotes(
        models: const [
          (id: 'a', name: 'STANDARD', color: '#111111'),
          (id: 'b', name: 'PREMIUM', color: '#222222'),
        ],
        cellsByModel: const {
          'a': [
            StandardPriceCell(widthMm: 4000, heightMm: 3000, price: 1000000),
          ],
          'b': [
            StandardPriceCell(widthMm: 4000, heightMm: 3000, price: 1300000),
          ],
        },
        widthMm: 4000,
        heightMm: 3000,
      );
      expect(quotes.map((q) => q.price).toList(), [1000000, 1300000]);
      expect(quotes.first.unavailable, isFalse);
    });

    test('견적 한 줄은 분류·모델·사이즈·금액', () {
      const cells = [
        StandardPriceCell(widthMm: 3000, heightMm: 4000, price: 800000),
        StandardPriceCell(widthMm: 4000, heightMm: 4000, price: 900000),
      ];
      final exact = inferStandardPrice(
        cells: cells,
        widthMm: 3000,
        heightMm: 4000,
      );
      expect(
        formatStandardQuoteLine(
          categoryName: '스피드도어',
          modelName: 'STANDARD',
          inference: exact,
        ),
        '스피드도어 / STANDARD · 3000×4000 · 800,000원',
      );
      final mid = inferStandardPrice(
        cells: cells,
        widthMm: 3200,
        heightMm: 4000,
      );
      expect(
        formatStandardQuoteLine(
          categoryName: '스피드도어',
          modelName: 'STANDARD',
          inference: mid,
        ),
        contains('사이값 추정'),
      );
    });
  });
}
