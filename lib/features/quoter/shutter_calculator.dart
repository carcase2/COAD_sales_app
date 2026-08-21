import 'package:coad_customer_calls/models/shutter_models.dart';
import 'package:intl/intl.dart';

/// 셔터 견적 계산 — COAD_home `ShutterEstimatorWizard` + `shutterBoxBracketRules` 와 동일 규칙.
class ShutterCalculator {
  static const int minBucket = 2000;
  static const int maxBucket = 8000;
  static const int stepMm = 500;

  static const List<String> _motorModelOrder = [
    'KEM-300',
    'KEM-400',
    'KEM-500',
    'KEM-600',
    'KEM-800',
    'KEM-1000',
    'KEM-1200',
    'KEM-1500',
    'KEM-1800',
    'KEM-2000',
  ];

  /// 면적 공식: ((width + 100) / 1000) * ((height + 500) / 1000)
  static double calculateArea(double widthMm, double heightMm) {
    return ((widthMm + 100) / 1000.0) * ((heightMm + 500) / 1000.0);
  }

  /// 무게(kg). 철제방화/스크린방화는 0. 소수 1자리.
  static double calculateWeight(
    double widthMm,
    double heightMm,
    ShutterType type,
  ) {
    if (type == ShutterType.fireSteel || type == ShutterType.fireScreen) {
      return 0;
    }
    final isInsulated =
        type == ShutterType.doubleExtrusionInsulated ||
        type == ShutterType.windproofInsulated;
    final weightPerM2 = isInsulated ? 15.0 : 10.0;
    final calcWidth = widthMm + 100;
    final calcHeight = heightMm + 500;
    final weight = (calcWidth * calcHeight * weightPerM2) / 1000000.0;
    return (weight * 10).roundToDouble() / 10.0;
  }

  /// 폭 7500mm 이상 = 8인치 롤파이프.
  static bool isWide8InchRollPipe(double widthMm) => widthMm >= 7500;

  static String getRollPipeType(double widthMm) =>
      isWide8InchRollPipe(widthMm) ? '8인치 롤파이프' : '5인치 롤파이프';

  /// 무게 → 모터 (안전 마진 10%, coad_home 동일).
  static String selectMotorModel(double weightKg) {
    if (weightKg <= 0) return '';
    if (weightKg <= 270) return 'KEM-300';
    if (weightKg <= 360) return 'KEM-400';
    if (weightKg <= 450) return 'KEM-500';
    if (weightKg <= 540) return 'KEM-600';
    if (weightKg <= 720) return 'KEM-800';
    if (weightKg <= 900) return 'KEM-1000';
    if (weightKg <= 1080) return 'KEM-1200';
    if (weightKg <= 1350) return 'KEM-1500';
    if (weightKg <= 1620) return 'KEM-1800';
    if (weightKg <= 1800) return 'KEM-2000';
    return '문의';
  }

  /// 8인치 롤파이프면 모터 1단계 상향.
  static String selectEffectiveMotorModel(double weightKg, double widthMm) {
    final base = selectMotorModel(weightKg);
    if (base.isEmpty || base == '문의' || !isWide8InchRollPipe(widthMm)) {
      return base;
    }
    final idx = _motorModelOrder.indexOf(base);
    if (idx < 0) return base;
    return _motorModelOrder[idx + 1 < _motorModelOrder.length ? idx + 1 : idx];
  }

  static String motorPowerByModel(String model) {
    switch (model) {
      case 'KEM-300':
        return '500W';
      case 'KEM-400':
        return '600W';
      case 'KEM-500':
      case 'KEM-600':
        return '1000W';
      case 'KEM-800':
        return '1500W';
      case 'KEM-1000':
        return '1700W';
      case 'KEM-1200':
        return '2000W';
      case 'KEM-1500':
        return '2200W';
      case 'KEM-1800':
      case 'KEM-2000':
        return '2300W';
      default:
        return '-';
    }
  }

  static bool _isMotorAtLeastKem800(double weightKg, double widthMm) {
    final model = selectEffectiveMotorModel(weightKg, widthMm);
    final modelIdx = _motorModelOrder.indexOf(model);
    final kem800Idx = _motorModelOrder.indexOf('KEM-800');
    return modelIdx >= kem800Idx && modelIdx >= 0;
  }

  static String _resolve500B800(
    String bracket,
    double weightKg,
    double widthMm,
  ) {
    if (bracket != 'KEM-500B, KEM-800') return bracket;
    if (weightKg <= 0) return 'KEM-500B, KEM-800';
    return _isMotorAtLeastKem800(weightKg, widthMm) ? 'KEM-800' : 'KEM-500B';
  }

  /// 브라켓 종류 — coad_home `getBracketType`.
  static String getBracketType({
    required bool isInsulated,
    required double heightMm,
    double widthMm = 0,
    double weightKg = 0,
  }) {
    if (heightMm <= 0) return '-';

    if (isInsulated) {
      if (heightMm <= 2000) return 'KEM-300, KEM-400';
      if (heightMm <= 3500) return 'KEM-500, KEM-600';
      if (heightMm <= 5500) {
        return _resolve500B800('KEM-500B, KEM-800', weightKg, widthMm);
      }
      if (heightMm <= 8000) return 'KEM-800';
      if (heightMm <= 9000) return 'KEM-1000';
      return '-';
    }

    if (heightMm <= 2000) return 'KEM-150';
    if (heightMm <= 2500) return 'KEM-300, KEM-400';
    if (heightMm <= 3000) return 'KEM-300, KEM-400, 주문형 브라켓';
    if (heightMm <= 5000) return 'KEM-500, 주문형 브라켓';
    if (heightMm <= 8999) {
      return _resolve500B800('KEM-500B, KEM-800', weightKg, widthMm);
    }
    return '-';
  }

  static String? _boxSizeForBracket(String bracket) {
    switch (bracket) {
      case 'KEM-150':
      case 'KEM-300':
      case 'KEM-400':
        return '650*505';
      case 'KEM-500':
      case 'KEM-600':
      case '주문형 브라켓':
      case 'KEM-500B':
        return '700*555';
      case 'KEM-800':
        return '800*655';
      case 'KEM-1000':
        return '855*700';
      default:
        return null;
    }
  }

  /// 셔터박스 — coad_home `getShutterBoxSize`.
  static String getShutterBoxSize({
    required bool isInsulated,
    required double heightMm,
    double weightKg = 0,
    double widthMm = 0,
  }) {
    final bracketStr = getBracketType(
      isInsulated: isInsulated,
      heightMm: heightMm,
      widthMm: widthMm,
      weightKg: weightKg,
    );
    final parts = bracketStr.split(',');
    for (final part in parts) {
      final size = _boxSizeForBracket(part.trim());
      if (size != null) return size;
    }

    final wide = isWide8InchRollPipe(widthMm);
    if (isInsulated && heightMm > (wide ? 8500 : 9000)) return '905*750';
    if (isInsulated && heightMm > (wide ? 6500 : 7000)) return '855*700';
    if (!isInsulated && heightMm > (wide ? 7999 : 8999)) return '855*700';
    return '650*505';
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
    Map<String, int>? unitPriceOverrideMap,
  }) {
    final area = calculateArea(input.widthMm, input.heightMm);
    final weightKg = calculateWeight(input.widthMm, input.heightMm, input.type);
    final motorModel = selectEffectiveMotorModel(weightKg, input.widthMm);
    final powerSpec = motorPowerByModel(motorModel);

    final info = getDbInfo(input.type);
    final category = info['category']!;
    final modelType = info['model_type'];
    final isInsulated = modelType?.contains('단열') ?? false;
    final bracketType = getBracketType(
      isInsulated: isInsulated,
      heightMm: input.heightMm,
      widthMm: input.widthMm,
      weightKg: weightKg,
    );
    final boxSize = getShutterBoxSize(
      isInsulated: isInsulated,
      heightMm: input.heightMm,
      weightKg: weightKg,
      widthMm: input.widthMm,
    );

    final breakdown = <ShutterBreakdownItem>[];
    var total = 0;
    var bodyPriceValue = 0;

    final isFire = category.contains('방화');

    final wBucket = toGridBucket(input.widthMm);
    final hBucket = toGridBucket(input.heightMm);
    final gridEntry = gridPrices.firstWhere(
      (e) =>
          e['category'] == category &&
          (isFire || e['model_type'] == modelType) &&
          e['width_mm'] == wBucket &&
          e['height_mm'] == hBucket,
      orElse: () => <String, dynamic>{},
    );
    final gridPrice = (gridEntry['price'] as num?)?.toInt();

    if (isFire) {
      // 철제방화/스크린방화: 격자 시공비만 (부대비용 미적용)
      final finalPrice = gridPrice ?? 0;
      total += finalPrice;
      breakdown.add(
        ShutterBreakdownItem(
          name: '예상 시공비',
          amount: finalPrice,
          note: gridPrice != null
              ? '격자 단가 (${wBucket}x$hBucket)'
              : '격자 미등록 — 별도 문의',
        ),
      );
    } else {
      // 방범: 슬라트 + 시공비(격자 or 기본) + 부대비용

      final unitEntry = unitPrices.firstWhere(
        (e) => e['category'] == category && e['model_type'] == modelType,
        orElse: () => <String, dynamic>{},
      );
      var unitPriceValue = (unitEntry['unit_price'] as num?)?.toInt() ?? 0;
      final overrideUnitPrice = modelType == null
          ? null
          : unitPriceOverrideMap?[modelType];
      if ((overrideUnitPrice ?? 0) > 0) {
        unitPriceValue = overrideUnitPrice!;
      }
      if (unitPriceValue == 0) {
        unitPriceValue = (modelType?.contains('단열') ?? false) ? 144000 : 81000;
      }
      bodyPriceValue = (area * unitPriceValue).round();
      total += bodyPriceValue;
      breakdown.add(
        ShutterBreakdownItem(
          name: '스라트 (본체)',
          amount: bodyPriceValue,
          note:
              '${area.toStringAsFixed(2)}㎡ × ${NumberFormat('#,###').format(unitPriceValue)}원',
        ),
      );

      // 시공비: 격자 우선, 없으면 입력 override 또는 기본 800,000 (웹 기본값)
      final defaultInstall = input.overrideInstallCost ?? 800000;
      final installCost = gridPrice ?? defaultInstall;
      total += installCost;
      breakdown.add(
        ShutterBreakdownItem(
          name: '시공 예상 비용',
          amount: installCost,
          note: gridPrice != null
              ? '격자 단가 적용 (${wBucket}x$hBucket)'
              : '기본 시공비 적용',
        ),
      );

      final motorCost = input.overrideMotorCost ?? 400000;
      final equipCost = input.overrideEquipCost ?? 200000;
      final bendingCost = input.overrideBendingCost ?? 500000;
      if (input.includeMotor) {
        total += motorCost;
        breakdown.add(
          ShutterBreakdownItem(
            name: '모터',
            amount: motorCost,
            note: motorModel.isEmpty ? null : '$motorModel · $powerSpec',
          ),
        );
      }
      if (input.includeEquipment) {
        total += equipCost;
        breakdown.add(ShutterBreakdownItem(name: '장비대', amount: equipCost));
      }
      if (input.includeBending) {
        total += bendingCost;
        breakdown.add(ShutterBreakdownItem(name: '절곡비용', amount: bendingCost));
      }

      // 내풍압: 윈드락 + 프레임
      if (modelType?.contains('내풍압') ?? false) {
        final windlockQty = (((input.heightMm + 400) / 72 / 10).ceil() * 2)
            .toInt();
        final windlockUnitCost = modelType!.contains('단열') ? 10000 : 8000;
        final windlockTotal = windlockQty * windlockUnitCost;
        total += windlockTotal;
        breakdown.add(
          ShutterBreakdownItem(
            name: '윈드락 ($windlockQty 개)',
            amount: windlockTotal,
          ),
        );

        final framePrice = (((input.heightMm + 200) * 2 / 1000.0) * 70000)
            .round();
        total += framePrice;
        breakdown.add(ShutterBreakdownItem(name: '프레임', amount: framePrice));
      }

      if (input.includeProfit) {
        final profitPrice = input.overrideProfitCost ?? 800000;
        total += profitPrice;
        breakdown.add(ShutterBreakdownItem(name: '당사이익', amount: profitPrice));
      }
    }

    for (final item in input.extraItems) {
      final itemTotal = item.price * item.quantity;
      total += itemTotal;
      breakdown.add(
        ShutterBreakdownItem(
          name: item.quantity > 1
              ? '${item.name} (${item.quantity}개)'
              : item.name,
          amount: itemTotal,
        ),
      );
    }

    return ShutterEstimateResult(
      input: input,
      totalAmount: total,
      breakdown: breakdown,
      area: area,
      weightKg: weightKg,
      motorModel: motorModel.isEmpty ? '-' : motorModel,
      powerSpec: powerSpec,
      boxSize: boxSize,
      bracketType: bracketType,
      slatPriceNote: !isFire && area > 0 && bodyPriceValue > 0
          ? '${area.toStringAsFixed(2)}㎡ × ${NumberFormat('#,###').format((bodyPriceValue / area).round())}원'
          : null,
      calculatedAt: DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now()),
    );
  }

  static Map<String, String?> getDbInfo(ShutterType type) {
    switch (type) {
      case ShutterType.doubleExtrusion:
        return {'category': '방범', 'model_type': '이중압출'};
      case ShutterType.doubleExtrusionInsulated:
        return {'category': '방범', 'model_type': '이중압출단열'};
      case ShutterType.windproof:
        return {'category': '방범', 'model_type': '내풍압'};
      case ShutterType.windproofInsulated:
        return {'category': '방범', 'model_type': '내풍압단열'};
      case ShutterType.fireSteel:
        return {'category': '철제방화', 'model_type': null};
      case ShutterType.fireScreen:
        return {'category': '방화스크린', 'model_type': null};
    }
  }

  static bool isSecurityType(ShutterType type) {
    final info = getDbInfo(type);
    return info['category'] == '방범';
  }

  static Map<String, int> buildSecurityFallbackUnitPriceMap(
    List<Map<String, dynamic>> unitPrices,
  ) {
    int pick(String modelType, int fallback) {
      final row = unitPrices.firstWhere(
        (e) => e['category'] == '방범' && e['model_type'] == modelType,
        orElse: () => <String, dynamic>{},
      );
      final parsed = (row['unit_price'] as num?)?.toInt() ?? 0;
      return parsed > 0 ? parsed : fallback;
    }

    final general = pick('이중압출', 81000);
    final insulated = pick('이중압출단열', 144000);
    return <String, int>{
      '이중압출': general,
      '내풍압': general,
      '이중압출단열': insulated,
      '내풍압단열': insulated,
    };
  }

  static Map<String, int> unitPriceMapFromCompany(
    Map<String, dynamic> companyRow,
    Map<String, int> fallbackMap,
  ) {
    final result = Map<String, int>.from(fallbackMap);
    final general = (companyRow['unit_price_general'] as num?)?.toInt() ?? 0;
    final insulated =
        (companyRow['unit_price_insulated'] as num?)?.toInt() ?? 0;

    if (general > 0) {
      result['이중압출'] = general;
      result['내풍압'] = general;
    }
    if (insulated > 0) {
      result['이중압출단열'] = insulated;
      result['내풍압단열'] = insulated;
    }
    return result;
  }

  static int extractSlatPrice(ShutterEstimateResult result) {
    return result.breakdown
        .where((item) => item.name.contains('스라트'))
        .fold<int>(0, (sum, item) => sum + item.amount);
  }

  /// 자재비 항목 — 스라트, 모터, 절곡비용.
  /// 내풍압·내풍압단열은 윈드락·프레임도 포함.
  static bool isMaterialCostItem(ShutterBreakdownItem item) {
    final n = item.name;
    return n.contains('스라트') ||
        n.contains('모터') ||
        n.contains('절곡') ||
        n.contains('윈드락') ||
        n.contains('프레임');
  }

  static bool isWindproofType(ShutterType type) =>
      type == ShutterType.windproof || type == ShutterType.windproofInsulated;

  /// 견적 내역 토글·푸터에 쓰는 자재비 범위 안내.
  static String materialCostHint(ShutterType type) {
    if (isWindproofType(type)) {
      return '스라트 · 모터 · 절곡 · 윈드락 · 프레임';
    }
    return '스라트 · 모터 · 절곡비용';
  }

  /// 스라트 → 모터 → 절곡 → 윈드락 → 프레임 순.
  static List<ShutterBreakdownItem> materialCostItems(
    ShutterEstimateResult result,
  ) {
    final items = result.breakdown.where(isMaterialCostItem).toList();
    items.sort((a, b) => _materialRank(a).compareTo(_materialRank(b)));
    return items;
  }

  static int materialCostTotal(ShutterEstimateResult result) {
    return materialCostItems(result).fold<int>(0, (sum, e) => sum + e.amount);
  }

  static int _materialRank(ShutterBreakdownItem item) {
    final n = item.name;
    if (n.contains('스라트')) return 0;
    if (n.contains('모터')) return 1;
    if (n.contains('절곡')) return 2;
    if (n.contains('윈드락')) return 3;
    if (n.contains('프레임')) return 4;
    return 9;
  }
}
