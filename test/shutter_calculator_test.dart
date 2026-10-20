import 'package:coad_customer_calls/features/quoter/shutter_calculator.dart';
import 'package:coad_customer_calls/models/shutter_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ShutterCalculator.calculateArea', () {
    test('공식 ((w+100)/1000)*((h+500)/1000)', () {
      // ((3000+100)/1000) * ((2500+500)/1000) = 3.1 * 3.0 = 9.3
      expect(ShutterCalculator.calculateArea(3000, 2500), closeTo(9.3, 0.0001));
    });
  });

  group('ShutterCalculator.toGridBucket', () {
    test('하한/상한 클램프', () {
      expect(ShutterCalculator.toGridBucket(1000), ShutterCalculator.minBucket);
      expect(ShutterCalculator.toGridBucket(9000), ShutterCalculator.maxBucket);
    });

    test('500mm 단위 올림', () {
      expect(ShutterCalculator.toGridBucket(2001), 2500);
      expect(ShutterCalculator.toGridBucket(2500), 2500);
      expect(ShutterCalculator.toGridBucket(2501), 3000);
    });
  });

  group('ShutterCalculator.selectMotorModel (coad_home)', () {
    test('무게 구간별 모델', () {
      expect(ShutterCalculator.selectMotorModel(100), 'KEM-300');
      expect(ShutterCalculator.selectMotorModel(270), 'KEM-300');
      expect(ShutterCalculator.selectMotorModel(271), 'KEM-400');
      expect(ShutterCalculator.selectMotorModel(450), 'KEM-500');
      expect(ShutterCalculator.selectMotorModel(451), 'KEM-600');
      expect(ShutterCalculator.selectMotorModel(720), 'KEM-800');
      expect(ShutterCalculator.selectMotorModel(1080), 'KEM-1200');
      expect(ShutterCalculator.selectMotorModel(1800), 'KEM-2000');
      expect(ShutterCalculator.selectMotorModel(2000), '문의');
    });

    test('폭 7500↑ 시 모터 1단계 상향', () {
      // 270kg → KEM-300, 8인치면 KEM-400
      expect(ShutterCalculator.selectEffectiveMotorModel(270, 7500), 'KEM-400');
      expect(ShutterCalculator.selectEffectiveMotorModel(270, 7400), 'KEM-300');
    });
  });

  group('ShutterCalculator.bracket / box (coad_home)', () {
    test('일반 높이 구간 브라켓', () {
      expect(
        ShutterCalculator.getBracketType(isInsulated: false, heightMm: 1800),
        'KEM-150',
      );
      expect(
        ShutterCalculator.getBracketType(isInsulated: false, heightMm: 2400),
        'KEM-300, KEM-400',
      );
    });

    test('브라켓→박스 매핑', () {
      expect(
        ShutterCalculator.getShutterBoxSize(isInsulated: false, heightMm: 1800),
        '650*505',
      );
      expect(
        ShutterCalculator.getShutterBoxSize(isInsulated: false, heightMm: 4000),
        '700*555',
      );
    });

    test('단열 22mm 높이 구간', () {
      expect(
        ShutterCalculator.getBracketType(isInsulated: true, heightMm: 2000),
        'KEM-300, KEM-400',
      );
      expect(
        ShutterCalculator.getShutterBoxSize(isInsulated: true, heightMm: 2000),
        '650*505',
      );
      expect(
        ShutterCalculator.getBracketType(isInsulated: true, heightMm: 2001),
        'KEM-500, KEM-600, 주문형 브라켓',
      );
      expect(
        ShutterCalculator.getBracketType(isInsulated: true, heightMm: 3500),
        'KEM-500, KEM-600, 주문형 브라켓',
      );
      expect(
        ShutterCalculator.getShutterBoxSize(isInsulated: true, heightMm: 3500),
        '700*555',
      );
      expect(
        ShutterCalculator.getBracketType(isInsulated: true, heightMm: 5500),
        'KEM-500B, KEM-800',
      );
      expect(
        ShutterCalculator.getBracketType(isInsulated: true, heightMm: 8000),
        'KEM-800',
      );
      expect(
        ShutterCalculator.getShutterBoxSize(isInsulated: true, heightMm: 8000),
        '800*655',
      );
      expect(
        ShutterCalculator.getBracketType(isInsulated: true, heightMm: 9000),
        'KEM-1000',
      );
      expect(
        ShutterCalculator.getShutterBoxSize(isInsulated: true, heightMm: 9000),
        '855*700',
      );
      expect(
        ShutterCalculator.getShutterBoxSize(isInsulated: true, heightMm: 9001),
        '905*750',
      );
    });

    test('단열 20mm는 높이 상한이 300mm 높다', () {
      const mm20 = ShutterCalculator.insulatedSlat20Mm;
      expect(
        ShutterCalculator.getBracketType(
          isInsulated: true,
          heightMm: 2300,
          insulatedSlatMm: mm20,
        ),
        'KEM-300, KEM-400',
      );
      expect(
        ShutterCalculator.getShutterBoxSize(
          isInsulated: true,
          heightMm: 2300,
          insulatedSlatMm: mm20,
        ),
        '650*505',
      );
      expect(
        ShutterCalculator.getBracketType(
          isInsulated: true,
          heightMm: 2301,
          insulatedSlatMm: mm20,
        ),
        'KEM-500, KEM-600, 주문형 브라켓',
      );
      expect(
        ShutterCalculator.getBracketType(
          isInsulated: true,
          heightMm: 3800,
          insulatedSlatMm: mm20,
        ),
        'KEM-500, KEM-600, 주문형 브라켓',
      );
      expect(
        ShutterCalculator.getShutterBoxSize(
          isInsulated: true,
          heightMm: 3800,
          insulatedSlatMm: mm20,
        ),
        '700*555',
      );
      expect(
        ShutterCalculator.getBracketType(
          isInsulated: true,
          heightMm: 5800,
          insulatedSlatMm: mm20,
        ),
        'KEM-500B, KEM-800',
      );
      expect(
        ShutterCalculator.getBracketType(
          isInsulated: true,
          heightMm: 8300,
          insulatedSlatMm: mm20,
        ),
        'KEM-800',
      );
      expect(
        ShutterCalculator.getShutterBoxSize(
          isInsulated: true,
          heightMm: 8300,
          insulatedSlatMm: mm20,
        ),
        '800*655',
      );
      expect(
        ShutterCalculator.getBracketType(
          isInsulated: true,
          heightMm: 9300,
          insulatedSlatMm: mm20,
        ),
        'KEM-1000',
      );
      expect(
        ShutterCalculator.getShutterBoxSize(
          isInsulated: true,
          heightMm: 9300,
          insulatedSlatMm: mm20,
        ),
        '855*700',
      );
      expect(
        ShutterCalculator.getShutterBoxSize(
          isInsulated: true,
          heightMm: 9301,
          insulatedSlatMm: mm20,
        ),
        '905*750',
      );
      // 22mm면 이미 한 단계 큰 박스인 높이가 20mm에서는 이전 박스다.
      expect(
        ShutterCalculator.getShutterBoxSize(isInsulated: true, heightMm: 2100),
        '700*555',
      );
      expect(
        ShutterCalculator.getShutterBoxSize(
          isInsulated: true,
          heightMm: 2100,
          insulatedSlatMm: mm20,
        ),
        '650*505',
      );
    });

    test('명진은 20mm, 비와이메탈과 그 외는 22mm', () {
      expect(ShutterCalculator.insulatedSlatMmForCompany('명진'), 20);
      expect(ShutterCalculator.insulatedSlatMmForCompany('명진금속'), 20);
      expect(ShutterCalculator.insulatedSlatMmForCompany('비와이메탈'), 22);
      expect(ShutterCalculator.insulatedSlatMmForCompany('다른업체'), 22);
      expect(ShutterCalculator.isByMetalCompany('비와이 메탈'), isTrue);
      expect(
        ShutterCalculator.isInsulatedType(ShutterType.doubleExtrusionInsulated),
        isTrue,
      );
      expect(
        ShutterCalculator.isInsulatedType(ShutterType.doubleExtrusion),
        isFalse,
      );
    });
  });

  group('ShutterCalculator.getDbInfo / isSecurityType', () {
    test('방범·방화 분류', () {
      expect(
        ShutterCalculator.getDbInfo(ShutterType.doubleExtrusion)['category'],
        '방범',
      );
      expect(
        ShutterCalculator.getDbInfo(ShutterType.fireSteel)['category'],
        '철제방화',
      );
      expect(ShutterCalculator.isSecurityType(ShutterType.windproof), isTrue);
      expect(ShutterCalculator.isSecurityType(ShutterType.fireScreen), isFalse);
    });
  });

  group('ShutterCalculator.calculate (방범)', () {
    final gridPrices = <Map<String, dynamic>>[
      {
        'category': '방범',
        'model_type': '이중압출',
        'width_mm': 3000,
        'height_mm': 3000,
        'price': 700000,
      },
    ];
    final unitPrices = <Map<String, dynamic>>[
      {'category': '방범', 'model_type': '이중압출', 'unit_price': 81000},
    ];

    test('슬라트+시공비+부대비용 합산', () {
      final input = ShutterEstimateInput(
        type: ShutterType.doubleExtrusion,
        widthMm: 3000,
        heightMm: 2500,
        includeProfit: true,
      );
      final result = ShutterCalculator.calculate(
        input: input,
        gridPrices: gridPrices,
        unitPrices: unitPrices,
      );

      expect(result.totalAmount, greaterThan(0));
      expect(result.area, closeTo(9.3, 0.0001));
      expect(result.breakdown.any((e) => e.name.contains('스라트')), isTrue);
      expect(result.breakdown.any((e) => e.name.contains('시공')), isTrue);
      expect(result.breakdown.any((e) => e.name == '모터'), isTrue);
      expect(result.breakdown.any((e) => e.name == '당사이익'), isTrue);
      expect(result.motorModel, isNot(equals('-')));
      expect(result.boxSize, isNotEmpty);
      expect(result.bracketType, isNot(equals('-')));

      final slat = ShutterCalculator.extractSlatPrice(result);
      expect(slat, greaterThan(0));
      // 9.3 * 81000 ≈ 753300
      expect(slat, closeTo(753300, 1));
    });

    test('자재비는 스라트·모터·절곡만 합산', () {
      final input = ShutterEstimateInput(
        type: ShutterType.doubleExtrusion,
        widthMm: 3000,
        heightMm: 2500,
        includeProfit: true,
      );
      final result = ShutterCalculator.calculate(
        input: input,
        gridPrices: gridPrices,
        unitPrices: unitPrices,
      );

      expect(
        result.breakdown
            .where(ShutterCalculator.isMaterialCostItem)
            .map((e) => e.name)
            .toList(),
        ['스라트 (본체)', '모터', '절곡비용'],
      );
      expect(
        ShutterCalculator.isMaterialCostItem(
          const ShutterBreakdownItem(name: '시공 예상 비용', amount: 1),
        ),
        isFalse,
      );
      expect(
        ShutterCalculator.isMaterialCostItem(
          const ShutterBreakdownItem(name: '장비대', amount: 1),
        ),
        isFalse,
      );
      expect(
        ShutterCalculator.isMaterialCostItem(
          const ShutterBreakdownItem(name: '당사이익', amount: 1),
        ),
        isFalse,
      );

      final items = ShutterCalculator.materialCostItems(result);
      expect(items.map((e) => e.name).toList(), ['스라트 (본체)', '모터', '절곡비용']);
      expect(
        ShutterCalculator.materialCostHint(ShutterType.doubleExtrusion),
        '스라트 · 모터 · 절곡비용',
      );
      final expected = items.fold<int>(0, (sum, e) => sum + e.amount);
      expect(ShutterCalculator.materialCostTotal(result), expected);
      expect(expected, lessThan(result.totalAmount));
    });

    test('내풍압 자재비는 윈드락·프레임 포함', () {
      for (final type in [
        ShutterType.windproof,
        ShutterType.windproofInsulated,
      ]) {
        final result = ShutterCalculator.calculate(
          input: ShutterEstimateInput(
            type: type,
            widthMm: 3000,
            heightMm: 2500,
            includeProfit: true,
          ),
          gridPrices: const [],
          unitPrices: const [],
        );

        expect(result.breakdown.any((e) => e.name.contains('윈드락')), isTrue);
        expect(result.breakdown.any((e) => e.name == '프레임'), isTrue);

        final names = ShutterCalculator.materialCostItems(
          result,
        ).map((e) => e.name).toList();
        expect(names.any((n) => n.contains('스라트')), isTrue);
        expect(names, contains('모터'));
        expect(names, contains('절곡비용'));
        expect(names.any((n) => n.contains('윈드락')), isTrue);
        expect(names, contains('프레임'));
        expect(names.any((n) => n.contains('시공')), isFalse);
        expect(names, isNot(contains('당사이익')));

        expect(
          ShutterCalculator.materialCostHint(type),
          '스라트 · 모터 · 절곡 · 윈드락 · 프레임',
        );
        expect(
          ShutterCalculator.materialCostTotal(result),
          lessThan(result.totalAmount),
        );
      }
    });

    test('회사 단가 오버라이드 반영', () {
      final input = ShutterEstimateInput(
        type: ShutterType.doubleExtrusion,
        widthMm: 3000,
        heightMm: 2500,
        includeProfit: false,
      );
      final base = ShutterCalculator.calculate(
        input: input,
        gridPrices: gridPrices,
        unitPrices: unitPrices,
      );
      final overridden = ShutterCalculator.calculate(
        input: input,
        gridPrices: gridPrices,
        unitPrices: unitPrices,
        unitPriceOverrideMap: const {'이중압출': 100000},
      );
      expect(
        ShutterCalculator.extractSlatPrice(overridden),
        greaterThan(ShutterCalculator.extractSlatPrice(base)),
      );
    });
  });

  group('ShutterCalculator.unitPriceMapFromCompany', () {
    test('일반/단열 단가 매핑', () {
      final fallback = ShutterCalculator.buildSecurityFallbackUnitPriceMap([]);
      final map = ShutterCalculator.unitPriceMapFromCompany({
        'unit_price_general': 90000,
        'unit_price_insulated': 150000,
      }, fallback);
      expect(map['이중압출'], 90000);
      expect(map['내풍압'], 90000);
      expect(map['이중압출단열'], 150000);
      expect(map['내풍압단열'], 150000);
    });
  });
}
