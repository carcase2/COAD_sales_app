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

    test('롤파이프 8인치 이상이면 모터 1단계 상향', () {
      // 270kg → KEM-300, 폭 8000(8인치)이면 KEM-400
      expect(ShutterCalculator.selectEffectiveMotorModel(270, 8000), 'KEM-400');
      // 폭 7500은 6인치 → 상향 없음
      expect(ShutterCalculator.selectEffectiveMotorModel(270, 7500), 'KEM-300');
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

  group('ShutterCalculator.calculate (방화)', () {
    // DB shutter_unit_price_grid 의 실제 분류 이름 — 철제방화 · 스크린방화.
    final gridPrices = <Map<String, dynamic>>[
      {
        'category': '철제방화',
        'model_type': '',
        'width_mm': 3000,
        'height_mm': 3000,
        'price': 2100000,
      },
      {
        'category': '스크린방화',
        'model_type': '',
        'width_mm': 3000,
        'height_mm': 3000,
        'price': 1800000,
      },
    ];

    test('스크린방화는 DB 분류 「스크린방화」 격자 단가로 계산한다', () {
      expect(
        ShutterCalculator.getDbInfo(ShutterType.fireScreen)['category'],
        '스크린방화',
      );
      final result = ShutterCalculator.calculate(
        input: ShutterEstimateInput(
          type: ShutterType.fireScreen,
          widthMm: 2800,
          heightMm: 3000,
        ),
        gridPrices: gridPrices,
        unitPrices: const [],
      );
      expect(result.totalAmount, 1800000);
      expect(result.breakdown.single.note, contains('격자 단가 (3000x3000)'));
    });

    test('철제방화와 스크린방화는 서로의 격자를 쓰지 않는다', () {
      final steel = ShutterCalculator.calculate(
        input: ShutterEstimateInput(
          type: ShutterType.fireSteel,
          widthMm: 3000,
          heightMm: 3000,
        ),
        gridPrices: gridPrices,
        unitPrices: const [],
      );
      expect(steel.totalAmount, 2100000);
    });
  });

  group('모터 KEM-1000 이상 → 셔터박스 별도 문의 (coad_home)', () {
    String box(bool ins, double h, double w, double width) =>
        ShutterCalculator.getShutterBoxSize(
          isInsulated: ins,
          heightMm: h,
          weightKg: w,
          widthMm: width,
        );
    const inquiry = ShutterCalculator.shutterBoxInquiry;

    test('720kg(KEM-800)까지 박스 규칙, 721kg(KEM-1000)부터 별도 문의', () {
      expect(box(false, 6000, 720, 3000), '800*655');
      expect(box(false, 6000, 721, 3000), inquiry);
    });
    test('KEM-1200(1000kg)도 별도 문의 — 단열·높이 무관', () {
      expect(box(true, 6000, 1000, 3000), inquiry);
      expect(box(true, 9100, 1000, 3000), inquiry);
    });
    test('8인치 상향으로 KEM-1000이 되면 별도 문의', () {
      expect(box(false, 6000, 720, 8000), inquiry);
      expect(box(false, 6000, 720, 7500), '800*655');
    });
    test('1800kg 초과(모터 문의)도 별도 문의', () {
      expect(box(false, 6000, 2000, 3000), inquiry);
    });
  });

  group('㎡당 무게 (coad_home shutterSpecSettings)', () {
    test('일반 10, 단열 15, 명진(20mm) 단열 17', () {
      expect(ShutterCalculator.slatWeightKgPerM2(isInsulated: false), 10);
      expect(ShutterCalculator.slatWeightKgPerM2(isInsulated: true), 15);
      expect(
        ShutterCalculator.slatWeightKgPerM2(
          isInsulated: true,
          insulatedSlatMm: ShutterCalculator.insulatedSlat20Mm,
        ),
        17,
      );
    });
    test('명진 단열은 17kg/㎡로 무게 계산', () {
      // (3000+100)*(3000+500)=10.85㎡
      expect(
        ShutterCalculator.calculateWeight(
          3000,
          3000,
          ShutterType.doubleExtrusionInsulated,
        ),
        162.8,
      );
      expect(
        ShutterCalculator.calculateWeight(
          3000,
          3000,
          ShutterType.doubleExtrusionInsulated,
          insulatedSlatMm: ShutterCalculator.insulatedSlat20Mm,
        ),
        184.5,
      );
    });
  });

  group('롤파이프 선정표 (coad_home)', () {
    const weights = <double>[150, 250, 300, 400, 500, 600, 800, 1000, 1200, 1300];
    const table = <(double, List<int>)>[
      (2900, [4, 4, 4, 5, 5, 6, 6, 8, 10, 12]),
      (3900, [4, 4, 4, 5, 5, 6, 6, 8, 10, 12]),
      (4900, [5, 5, 5, 5, 5, 6, 6, 8, 10, 12]),
      (5900, [5, 5, 5, 5, 5, 6, 6, 8, 10, 12]),
      (6900, [6, 6, 6, 6, 6, 6, 6, 8, 10, 12]),
      (7900, [6, 6, 6, 6, 6, 6, 6, 8, 10, 12]),
      (8900, [8, 8, 8, 8, 8, 8, 8, 8, 10, 12]),
      (9900, [8, 8, 8, 8, 8, 8, 8, 8, 10, 12]),
      (10900, [10, 10, 10, 10, 10, 10, 10, 10, 10, 12]),
      (11900, [10, 10, 10, 10, 10, 10, 10, 10, 10, 12]),
      (12900, [12, 12, 12, 12, 12, 12, 12, 12, 12, 12]),
    ];
    for (final (width, row) in table) {
      test('폭 ${width.toInt()}mm', () {
        expect(
          weights.map((w) => ShutterCalculator.getRollPipeInch(width, w)),
          row,
        );
      });
    }
    test('표 범위를 넘으면 문의', () {
      expect(ShutterCalculator.getRollPipeInch(13000, 100), isNull);
      expect(ShutterCalculator.getRollPipeInch(3000, 1301), isNull);
      expect(ShutterCalculator.getRollPipeType(3000, 1301), '별도 문의');
      expect(ShutterCalculator.getRollPipeType(3000, 200), '4인치 롤파이프');
      expect(ShutterCalculator.getRollPipeType(0, 200), '');
    });
  });
}
