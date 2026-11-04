import 'package:coad_customer_calls/features/quoter/quoter_company_models.dart';
import 'package:coad_customer_calls/features/quoter/shutter_calculator.dart';
import 'package:coad_customer_calls/models/shutter_models.dart';

/// 셔터 단가 테이블 묶음 (`shutterPricesFutureProvider`): grid · unit · company.
typedef ShutterPriceTables = Map<String, List<Map<String, dynamic>>>;

/// COAD_home: 기준 단가(비와이메탈) + 등록 업체 목록.
const kShutterBaseCompanyId = '__base_unit_price__';
const kShutterBaseCompanyName = '비와이메탈';

/// 셔터 견적의 스라트 밖 비용. 기본값은 COAD_home DEFAULT_COSTS 와 같다.
class ShutterQuickCosts {
  const ShutterQuickCosts({
    this.motor = 400000,
    this.install = 800000,
    this.equip = 200000,
    this.bending = 500000,
    this.profit = 800000,
  });

  final int motor;
  final int install;
  final int equip;
  final int bending;
  final int profit;

  bool get isDefault => this == const ShutterQuickCosts();

  int get total => motor + install + equip + bending + profit;

  ShutterQuickCosts copyWith({
    int? motor,
    int? install,
    int? equip,
    int? bending,
    int? profit,
  }) {
    return ShutterQuickCosts(
      motor: motor ?? this.motor,
      install: install ?? this.install,
      equip: equip ?? this.equip,
      bending: bending ?? this.bending,
      profit: profit ?? this.profit,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ShutterQuickCosts &&
      other.motor == motor &&
      other.install == install &&
      other.equip == equip &&
      other.bending == bending &&
      other.profit == profit;

  @override
  int get hashCode => Object.hash(motor, install, equip, bending, profit);
}

ShutterEstimateInput shutterEstimateInput({
  required ShutterType type,
  required double widthMm,
  required double heightMm,
  int? motorCost,
  int? installCost,
  int? equipCost,
  int? bendingCost,
  int? profitCost,
}) {
  return ShutterEstimateInput(
    type: type,
    widthMm: widthMm,
    heightMm: heightMm,
    includeInstallation: true,
    includeMotor: true,
    includeProfit: true,
    overrideMotorCost: motorCost,
    overrideInstallCost: installCost,
    overrideEquipCost: equipCost,
    overrideBendingCost: bendingCost,
    overrideProfitCost: profitCost,
  );
}

List<ShutterCompanyUnitPrice> _parseCompanyRows(
  List<Map<String, dynamic>> rawRows,
) {
  final rows = rawRows
      .asMap()
      .entries
      .map(
        (entry) => ShutterCompanyUnitPrice.fromJson(
          entry.value,
          fallbackId: 'company_${entry.key}',
        ),
      )
      .toList();
  rows.sort((a, b) {
    final orderCompare = a.sortOrder.compareTo(b.sortOrder);
    if (orderCompare != 0) return orderCompare;
    return a.companyName.compareTo(b.companyName);
  });
  return rows;
}

/// 웹과 동일: 비와이메탈(기준) + 회사 단가 테이블 업체.
List<ShutterCompanyUnitPrice> shutterComparisonCompanies({
  required List<Map<String, dynamic>> rawRows,
  required Map<String, int> fallbackMap,
}) {
  final registered = _parseCompanyRows(rawRows);
  final hasBaseName = registered.any(
    (c) => c.companyName.replaceAll(' ', '') == kShutterBaseCompanyName,
  );
  if (hasBaseName) return registered;

  final base = ShutterCompanyUnitPrice(
    id: kShutterBaseCompanyId,
    companyName: kShutterBaseCompanyName,
    unitPriceGeneral: fallbackMap['이중압출'] ?? 81000,
    unitPriceInsulated: fallbackMap['이중압출단열'] ?? 144000,
    isDefault: true,
    sortOrder: -1,
  );
  return [base, ...registered];
}

CompanyContext shutterCompanyContext({
  required ShutterPriceTables prices,
  required ShutterType type,
  required String? selectedCompanyId,
}) {
  final fallbackMap = ShutterCalculator.buildSecurityFallbackUnitPriceMap(
    prices['unit'] as List<Map<String, dynamic>>,
  );
  final companies = shutterComparisonCompanies(
    rawRows: prices['company'] ?? const [],
    fallbackMap: fallbackMap,
  );
  if (!ShutterCalculator.isSecurityType(type) || companies.isEmpty) {
    return CompanyContext(
      companies: companies,
      selectedCompanyId: null,
      selectedCompany: null,
      fallbackUnitPriceMap: fallbackMap,
    );
  }

  ShutterCompanyUnitPrice? selected;
  ShutterCompanyUnitPrice? defaultCompany;
  for (final company in companies) {
    if (company.id == selectedCompanyId) {
      selected = company;
    }
    if (defaultCompany == null && company.isDefault) {
      defaultCompany = company;
    }
  }
  final resolved = selected ?? defaultCompany ?? companies.first;
  return CompanyContext(
    companies: companies,
    selectedCompanyId: resolved.id,
    selectedCompany: resolved,
    fallbackUnitPriceMap: fallbackMap,
  );
}

/// 업체 하나로 계산. 기준(비와이메탈)은 unit 테이블 단가, 그 외는 회사 단가 오버라이드.
ShutterEstimateResult shutterCalculateFor({
  required ShutterPriceTables prices,
  required ShutterEstimateInput input,
  required CompanyContext context,
}) {
  final company = context.selectedCompany;
  final unitMap = company == null || company.id == kShutterBaseCompanyId
      ? null
      : ShutterCalculator.unitPriceMapFromCompany(
          company.toJson(),
          context.fallbackUnitPriceMap,
        );
  return ShutterCalculator.calculate(
    input: input,
    gridPrices: prices['grid'] as List<Map<String, dynamic>>,
    unitPrices: prices['unit'] as List<Map<String, dynamic>>,
    unitPriceOverrideMap: unitMap,
    insulatedSlatMm: ShutterCalculator.insulatedSlatMmForCompany(
      company?.companyName,
    ),
  );
}

List<CompanyComparisonRow> shutterCompanyComparisons({
  required ShutterPriceTables prices,
  required ShutterEstimateInput input,
  required String? selectedCompanyId,
}) {
  if (!ShutterCalculator.isSecurityType(input.type)) return const [];
  final fallbackMap = ShutterCalculator.buildSecurityFallbackUnitPriceMap(
    prices['unit'] as List<Map<String, dynamic>>,
  );
  final companies = shutterComparisonCompanies(
    rawRows: prices['company'] ?? const [],
    fallbackMap: fallbackMap,
  );
  if (companies.isEmpty) return const [];

  final rows = companies.map((company) {
    final estimate = shutterCalculateFor(
      prices: prices,
      input: input,
      context: CompanyContext(
        companies: companies,
        selectedCompanyId: company.id,
        selectedCompany: company,
        fallbackUnitPriceMap: fallbackMap,
      ),
    );
    return CompanyComparisonRow(
      company: company,
      totalAmount: estimate.totalAmount,
      slatAmount: ShutterCalculator.extractSlatPrice(estimate),
    );
  }).toList();
  int? selectedTotal;
  for (final row in rows) {
    if (row.company.id == selectedCompanyId) {
      selectedTotal = row.totalAmount;
      break;
    }
  }
  return rows
      .map(
        (row) => row.copyWith(
          deltaFromSelected: selectedTotal == null
              ? 0
              : row.totalAmount - selectedTotal,
        ),
      )
      .toList();
}

/// 산출 직후 최저가 업체 자동 선택 (COAD_home generateEstimate).
String? shutterLowestCompanyId(List<CompanyComparisonRow> rows) {
  CompanyComparisonRow? minRow;
  for (final row in rows) {
    if (row.totalAmount <= 0) continue;
    if (minRow == null || row.totalAmount < minRow.totalAmount) {
      minRow = row;
    }
  }
  return minRow?.company.id;
}

/// 견적 한 번의 결과: 적용 업체로 계산한 값과 업체 비교표.
class ShutterQuickEstimate {
  const ShutterQuickEstimate({
    required this.result,
    required this.comparisons,
    required this.companyId,
    required this.companyName,
  });

  final ShutterEstimateResult result;
  final List<CompanyComparisonRow> comparisons;
  final String? companyId;
  final String? companyName;

  int get total => result.totalAmount;
}

/// 셔터 종류·규격·비용으로 바로 계산한다.
/// [companyId]가 없으면 최저가 업체를 고른다 (셔터 견적기 산출과 같음).
ShutterQuickEstimate shutterQuickEstimate({
  required ShutterPriceTables prices,
  required ShutterType type,
  required int widthMm,
  required int heightMm,
  ShutterQuickCosts costs = const ShutterQuickCosts(),
  String? companyId,
}) {
  final input = shutterEstimateInput(
    type: type,
    widthMm: widthMm.toDouble(),
    heightMm: heightMm.toDouble(),
    motorCost: costs.motor,
    installCost: costs.install,
    equipCost: costs.equip,
    bendingCost: costs.bending,
    profitCost: costs.profit,
  );
  var pickId = companyId;
  if (pickId == null) {
    final first = shutterCompanyContext(
      prices: prices,
      type: type,
      selectedCompanyId: null,
    );
    final rows = shutterCompanyComparisons(
      prices: prices,
      input: input,
      selectedCompanyId: first.selectedCompanyId,
    );
    pickId = shutterLowestCompanyId(rows) ?? first.selectedCompanyId;
  }
  final context = shutterCompanyContext(
    prices: prices,
    type: type,
    selectedCompanyId: pickId,
  );
  final result = shutterCalculateFor(
    prices: prices,
    input: input,
    context: context,
  );
  return ShutterQuickEstimate(
    result: result,
    comparisons: shutterCompanyComparisons(
      prices: prices,
      input: input,
      selectedCompanyId: context.selectedCompanyId,
    ),
    companyId: context.selectedCompanyId,
    companyName: context.selectedCompany?.companyName,
  );
}
