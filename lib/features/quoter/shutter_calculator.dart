import 'package:coad_customer_calls/models/shutter_models.dart';
import 'package:intl/intl.dart';

class ShutterCalculator {
  static const int minBucket = 2000;
  static const int maxBucket = 8000;
  static const int stepMm = 500;

  static double calculateArea(double widthMm, double heightMm) {
    // 공식: ((width + 100) / 1000) * ((height + 500) / 1000)
    return ((widthMm + 100) / 1000.0) * ((heightMm + 500) / 1000.0);
  }

  static double calculateWeight(double widthMm, double heightMm, ShutterType type) {
    final area = calculateArea(widthMm, heightMm);
    final weightPerM2 = type.toString().contains('Insulated') ? 15.0 : 10.0;
    return area * weightPerM2;
  }

  static String selectMotorModel(double weight) {
    if (weight <= 270) return 'KEM-300';
    if (weight <= 360) return 'KEM-400';
    if (weight <= 420) return 'KEM-500';
    if (weight <= 550) return 'KEM-600';
    if (weight <= 750) return 'KEM-800';
    if (weight <= 900) return 'KEM-1000';
    if (weight <= 1200) return 'KEM-1300';
    return 'KEM-2000';
  }

  static int toGridBucket(double value) {
    if (value <= minBucket) return minBucket;
    if (value >= maxBucket) return maxBucket;
    return ((value / stepMm).ceil() * stepMm).toInt();
  }

  static ShutterEstimateResult calculate({
    required ShutterEstimateInput input,
    required List<Map<String, dynamic>> gridPrices,
    required List<Map<String, dynamic>> unitPrices,
  }) {
    final area = calculateArea(input.widthMm, input.heightMm);
    final weightKg = calculateWeight(input.widthMm, input.heightMm, input.type);
    final motorModel = selectMotorModel(weightKg);
    
    final breakdown = <ShutterBreakdownItem>[];
    int total = 0;
    int bodyPriceValue = 0; // 본체가 저장용

    final info = getDbInfo(input.type);
    final category = info['category']!;
    final modelType = info['model_type'];

    final isFire = category.contains('방화');

    // [0] 격자 데이터 조회 (공통 버킷)
    final wBucket = toGridBucket(input.widthMm);
    final hBucket = toGridBucket(input.heightMm);
    final gridEntry = gridPrices.firstWhere(
      (e) => e['category'] == category && (isFire || e['model_type'] == modelType) && e['width_mm'] == wBucket && e['height_mm'] == hBucket,
      orElse: () => {},
    );
    final gridPrice = (gridEntry['price'] as num?)?.toInt();

    if (isFire) {
      // [A] 철제방화 / 스크린방화: 격자값 1개가 총액 (슬라트 계산 안함)
      final finalPrice = gridPrice ?? 0;
      total += finalPrice;
      breakdown.add(ShutterBreakdownItem(
        name: '기본 견적 (격자: ${wBucket}x${hBucket})', 
        amount: finalPrice,
        note: '방화 모델은 격자 시공비가 총액으로 적용됩니다.',
      ));
    } else {
      // [B] 방범 4종: 슬라트(공식) + 시공비(격자 or 600k) + 부대비용
      
      // 1. 슬라트 금액 계산
      final unitEntry = unitPrices.firstWhere(
        (e) => e['category'] == category && e['model_type'] == modelType,
        orElse: () => {},
      );
      int unitPriceValue = (unitEntry['unit_price'] as num?)?.toInt() ?? 0;
      if (unitPriceValue == 0) {
        unitPriceValue = (modelType?.contains('단열') ?? false) ? 144000 : 81000;
      }
      bodyPriceValue = (area * unitPriceValue).round();
      total += bodyPriceValue;
      breakdown.add(ShutterBreakdownItem(
        name: '스라트 (본체)', 
        amount: bodyPriceValue,
        note: '${area.toStringAsFixed(2)}㎡ × ${NumberFormat('#,###').format(unitPriceValue)}원',
      ));

      // 2. 시공비 (격자 있으면 격자값, 없으면 600,000원)
      final installCost = gridPrice ?? 600000;
      total += installCost;
      breakdown.add(ShutterBreakdownItem(
        name: '시공 예상 비용', 
        amount: installCost,
        note: gridPrice != null ? '격자 단가 적용 (${wBucket}x${hBucket})' : '기본 시공비 적용',
      ));

      // 3. 기타 고정 부대비용
      final motorCost = input.overrideMotorCost ?? 400000;
      final equipCost = input.overrideEquipCost ?? 200000;
      final bendingCost = input.overrideBendingCost ?? 500000;
      total += (motorCost + equipCost + bendingCost);
      breakdown.add(ShutterBreakdownItem(name: '모터', amount: motorCost));
      breakdown.add(ShutterBreakdownItem(name: '장비대', amount: equipCost));
      breakdown.add(ShutterBreakdownItem(name: '절곡비용', amount: bendingCost));

      // 4. 내풍압 특화 비용
      if (modelType?.contains('내풍압') ?? false) {
        // 윈드락: ceil((height+400)/72/10) * 2
        final windlockQty = (((input.heightMm + 400) / 72 / 10).ceil() * 2).toInt();
        final windlockUnitCost = modelType!.contains('단열') ? 10000 : 8000;
        final windlockTotal = windlockQty * windlockUnitCost;
        total += windlockTotal;
        breakdown.add(ShutterBreakdownItem(name: '윈드락 ($windlockQty 개)', amount: windlockTotal));

        // 프레임: ((height+200)*2/1000) * 70000
        final framePrice = (((input.heightMm + 200) * 2 / 1000.0) * 70000).round();
        total += framePrice;
        breakdown.add(ShutterBreakdownItem(name: '프레임비', amount: framePrice));
      }

      // 5. 당사이익
      if (input.includeProfit) {
        final profitPrice = input.overrideProfitCost ?? 800000;
        total += profitPrice;
        breakdown.add(ShutterBreakdownItem(name: '당사이익', amount: profitPrice));
      }
    }

    // 공통 추가 항목
    for (final item in input.extraItems) {
      final itemTotal = item.price * item.quantity;
      total += itemTotal;
      breakdown.add(ShutterBreakdownItem(name: '${item.name} (${item.quantity}개)', amount: itemTotal));
    }

    return ShutterEstimateResult(
      input: input,
      totalAmount: total,
      breakdown: breakdown,
      area: area,
      weightKg: weightKg,
      motorModel: motorModel,
      powerSpec: '500W',
      boxSize: '700*555',
      bracketType: '주문형 브라켓',
      slatPriceNote: !isFire ? '${area.toStringAsFixed(2)}㎡ × ${NumberFormat('#,###').format((bodyPriceValue / area).round())}원' : null,
      calculatedAt: DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now()),
    );
  }

  static Map<String, String?> getDbInfo(ShutterType type) {
    switch (type) {
      case ShutterType.doubleExtrusion: return {'category': '방범', 'model_type': '이중압출'};
      case ShutterType.doubleExtrusionInsulated: return {'category': '방범', 'model_type': '이중압출단열'};
      case ShutterType.windproof: return {'category': '방범', 'model_type': '내풍압'};
      case ShutterType.windproofInsulated: return {'category': '방범', 'model_type': '내풍압단열'};
      case ShutterType.fireSteel: return {'category': '철제방화', 'model_type': null};
      case ShutterType.fireScreen: return {'category': '방화스크린', 'model_type': null};
    }
  }
}
