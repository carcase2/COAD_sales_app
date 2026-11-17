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

  /// 일반 스라트 ㎡당 무게(kg).
  static const double slatWeightGeneralKgPerM2 = 10;

  /// 단열 스라트 ㎡당 무게(kg) — 비와이메탈 등 기본(22mm).
  static const double slatWeightInsulatedKgPerM2 = 15;

  /// 단열 스라트 ㎡당 무게(kg) — 명진(20mm).
  static const double slatWeightInsulatedMyungjinKgPerM2 = 17;

  /// 단열 여부·스라트 두께(명진 20mm)에 따른 ㎡당 무게 — coad_home `slatWeightKgPerM2`.
  static double slatWeightKgPerM2({
    required bool isInsulated,
    int insulatedSlatMm = insulatedSlat22Mm,
  }) {
    if (!isInsulated) return slatWeightGeneralKgPerM2;
    return insulatedSlatMm == insulatedSlat20Mm
        ? slatWeightInsulatedMyungjinKgPerM2
        : slatWeightInsulatedKgPerM2;
  }

  /// 무게(kg). 철제방화/스크린방화는 0. 소수 1자리.
  /// [insulatedSlatMm] 20(명진)이면 단열 17kg/㎡.
  static double calculateWeight(
    double widthMm,
    double heightMm,
    ShutterType type, {
    int insulatedSlatMm = insulatedSlat22Mm,
  }) {
    if (type == ShutterType.fireSteel || type == ShutterType.fireScreen) {
      return 0;
    }
    final isInsulated =
        type == ShutterType.doubleExtrusionInsulated ||
        type == ShutterType.windproofInsulated;
    final weightPerM2 = slatWeightKgPerM2(
      isInsulated: isInsulated,
      insulatedSlatMm: insulatedSlatMm,
    );
    final calcWidth = widthMm + 100;
    final calcHeight = heightMm + 500;
    final weight = (calcWidth * calcHeight * weightPerM2) / 1000000.0;
    return (weight * 10).roundToDouble() / 10.0;
  }

  /// 롤파이프 선정표(제조사 카탈로그) — 폭(mm) 상한 → 인치.
  static const List<(double, int)> rollPipeInchByWidth = [
    (3900, 4),
    (5900, 5),
    (7900, 6),
    (9900, 8),
    (11900, 10),
    (12900, 12),
  ];

  /// 롤파이프 선정표 — 중량(kg) 상한 → 인치.
  static const List<(double, int)> rollPipeInchByWeight = [
    (300, 4),
    (500, 5),
    (800, 6),
    (1000, 8),
    (1200, 10),
    (1300, 12),
  ];

  static int? _inchFromSteps(double value, List<(double, int)> steps) {
    for (final (max, inch) in steps) {
      if (value <= max) return inch;
    }
    return null;
  }

  /// 롤파이프 인치 = 폭 기준·중량 기준 중 큰 값. 표 범위를 넘으면 null(문의).
  static int? getRollPipeInch(double widthMm, double weightKg) {
    if (widthMm <= 0) return null;
    final byWidth = _inchFromSteps(widthMm, rollPipeInchByWidth);
    final byWeight =
        _inchFromSteps(weightKg < 0 ? 0 : weightKg, rollPipeInchByWeight);
    if (byWidth == null || byWeight == null) return null;
    return byWidth > byWeight ? byWidth : byWeight;
  }

  /// 롤파이프가 8인치 이상인가 (선정표 기준, 범위 초과=문의도 포함).
  /// 8인치 이상이면 모터 1단계 상향, 초고형 박스 높이 구간 500mm 낮춤.
  static bool isWide8InchRollPipe(double widthMm, [double weightKg = 0]) {
    if (widthMm <= 0) return false;
    final inch = getRollPipeInch(widthMm, weightKg);
    return inch == null || inch >= 8;
  }

  /// 화면 표시용: "6인치 롤파이프" / "별도 문의" / ''.
  static String getRollPipeType(double widthMm, [double weightKg = 0]) {
    if (widthMm <= 0) return '';
    final inch = getRollPipeInch(widthMm, weightKg);
    return inch == null ? '별도 문의' : '$inch인치 롤파이프';
  }

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
    if (base.isEmpty || base == '문의' || !isWide8InchRollPipe(widthMm, weightKg)) {
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

  static bool _isMotorAtLeast(
    double weightKg,
    double widthMm,
    String minModel,
  ) {
    final model = selectEffectiveMotorModel(weightKg, widthMm);
    if (model == '문의') return true;
    final modelIdx = _motorModelOrder.indexOf(model);
    return modelIdx >= 0 && modelIdx >= _motorModelOrder.indexOf(minModel);
  }

  static bool _isMotorAtLeastKem800(double weightKg, double widthMm) =>
      _isMotorAtLeast(weightKg, widthMm, 'KEM-800');

  /// 모터(8인치 상향 포함)가 KEM-1000 이상이면 셔터박스는 별도 문의.
  static const String shutterBoxInquiry = '별도 문의';

  static String _resolve500B800(
    String bracket,
    double weightKg,
    double widthMm,
  ) {
    if (bracket != 'KEM-500B, KEM-800') return bracket;
    if (weightKg <= 0) return 'KEM-500B, KEM-800';
    return _isMotorAtLeastKem800(weightKg, widthMm) ? 'KEM-800' : 'KEM-500B';
  }

  /// 단열 스라트. 비와이메탈 22mm, 명진 20mm.
  /// 20mm는 22mm와 같은 브라켓·박스이고 높이 상한만 300mm 높다.
  static const int insulatedSlat22Mm = 22;
  static const int insulatedSlat20Mm = 20;
  static const int insulatedSlat20HeightBumpMm = 300;

  static String _compactCompanyName(String? name) =>
      (name ?? '').replaceAll(RegExp(r'\s+'), '');

  static bool isMyungjinCompany(String? name) =>
      _compactCompanyName(name).contains('명진');

  static bool isByMetalCompany(String? name) =>
      _compactCompanyName(name).contains('비와이');

  /// 명진만 단열 20mm. 비와이메탈과 그 외 업체는 22mm.
  static int insulatedSlatMmForCompany(String? companyName) =>
      isMyungjinCompany(companyName) ? insulatedSlat20Mm : insulatedSlat22Mm;

  static bool isInsulatedType(ShutterType type) {
    final model = getDbInfo(type)['model_type'];
    return model?.contains('단열') ?? false;
  }

  static int _insulatedHeightBumpMm({
    required bool isInsulated,
    required int insulatedSlatMm,
  }) {
    if (!isInsulated || insulatedSlatMm != insulatedSlat20Mm) return 0;
    return insulatedSlat20HeightBumpMm;
  }

  /// 브라켓 종류 — coad_home `getBracketType`.
  /// [insulatedSlatMm] 20이면 단열 높이 구간이 300mm 올라간다.
  static String getBracketType({
    required bool isInsulated,
    required double heightMm,
    double widthMm = 0,
    double weightKg = 0,
    int insulatedSlatMm = insulatedSlat22Mm,
  }) {
    if (heightMm <= 0) return '-';

    if (isInsulated) {
      final bump = _insulatedHeightBumpMm(
        isInsulated: true,
        insulatedSlatMm: insulatedSlatMm,
      );
      if (heightMm <= 2000 + bump) return 'KEM-300, KEM-400';
      if (heightMm <= 3500 + bump) {
        return 'KEM-500, KEM-600, 주문형 브라켓';
      }
      if (heightMm <= 5500 + bump) {
        return _resolve500B800('KEM-500B, KEM-800', weightKg, widthMm);
      }
      if (heightMm <= 8000 + bump) return 'KEM-800';
      if (heightMm <= 9000 + bump) return 'KEM-1000';
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
  /// [insulatedSlatMm] 20이면 단열 높이 구간이 300mm 올라간다.
  static String getShutterBoxSize({
    required bool isInsulated,
    required double heightMm,
    double weightKg = 0,
    double widthMm = 0,
    int insulatedSlatMm = insulatedSlat22Mm,
  }) {
    if (weightKg > 0 && _isMotorAtLeast(weightKg, widthMm, 'KEM-1000')) {
      return shutterBoxInquiry;
    }
    final bracketStr = getBracketType(
      isInsulated: isInsulated,
      heightMm: heightMm,
      widthMm: widthMm,
      weightKg: weightKg,
      insulatedSlatMm: insulatedSlatMm,
    );
    final parts = bracketStr.split(',');
    for (final part in parts) {
      final size = _boxSizeForBracket(part.trim());
      if (size != null) return size;
    }

    final bump = _insulatedHeightBumpMm(
      isInsulated: isInsulated,
      insulatedSlatMm: insulatedSlatMm,
    );
    final wide = isWide8InchRollPipe(widthMm, weightKg);
    if (isInsulated && heightMm > (wide ? 8500 : 9000) + bump) return '905*750';
    if (isInsulated && heightMm > (wide ? 6500 : 7000) + bump) return '855*700';
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
    int insulatedSlatMm = insulatedSlat22Mm,
  }) {
    final area = calculateArea(input.widthMm, input.heightMm);
    final isInsulatedInput = isInsulatedType(input.type);
    final weightKg = calculateWeight(
      input.widthMm,
      input.heightMm,
      input.type,
      insulatedSlatMm: isInsulatedInput && insulatedSlatMm == insulatedSlat20Mm
          ? insulatedSlat20Mm
          : insulatedSlat22Mm,
    );
    final motorModel = selectEffectiveMotorModel(weightKg, input.widthMm);
    final powerSpec = motorPowerByModel(motorModel);

    final info = getDbInfo(input.type);
    final category = info['category']!;
    final modelType = info['model_type'];
    final isInsulated = modelType?.contains('단열') ?? false;
    final slatMm = isInsulated && insulatedSlatMm == insulatedSlat20Mm
        ? insulatedSlat20Mm
        : insulatedSlat22Mm;
    final bracketType = getBracketType(
      isInsulated: isInsulated,
      heightMm: input.heightMm,
      widthMm: input.widthMm,
      weightKg: weightKg,
      insulatedSlatMm: slatMm,
    );
    final boxSize = getShutterBoxSize(
      isInsulated: isInsulated,
      heightMm: input.heightMm,
      weightKg: weightKg,
      widthMm: input.widthMm,
      insulatedSlatMm: slatMm,
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
        // DB shutter_unit_price_grid·shutter_unit_prices 의 분류 이름과 같아야 한다.
        // '방화스크린'으로 찾던 동안 스크린방화 견적이 늘 0원(격자 미등록)이었다.
        return {'category': '스크린방화', 'model_type': null};
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
