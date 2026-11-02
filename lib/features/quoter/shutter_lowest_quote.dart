import 'package:coad_customer_calls/features/quoter/quoter_company_models.dart';
import 'package:coad_customer_calls/features/quoter/shutter_calculator.dart';
import 'package:coad_customer_calls/models/shutter_models.dart';

/// 셔터 견적기가 처음 산출할 때와 같은 기본 비용.
const shutterQuoteDefaultMotor = 400000;
const shutterQuoteDefaultInstall = 800000;
const shutterQuoteDefaultEquip = 200000;
const shutterQuoteDefaultBending = 500000;
const shutterQuoteDefaultProfit = 800000;

const _baseCompanyId = '__base_unit_price__';
const _baseCompanyName = '비와이메탈';

/// 한 사이즈·종류의 최저 업체 셔터 견적.
class ShutterLowestQuote {
  const ShutterLowestQuote({required this.result, this.companyName});

  final ShutterEstimateResult result;
  final String? companyName;
}

/// 폭·높이·종류로 셔터 견적기 산출. 방범은 최저가 업체를 고른다.
ShutterLowestQuote runLowestShutterQuote({
  required ShutterType type,
  required int widthMm,
  required int heightMm,
  required Map<String, List<Map<String, dynamic>>> prices,
}) {
  final grid = prices['grid'] ?? const [];
  final unit = prices['unit'] ?? const [];
  final input = ShutterEstimateInput(
    type: type,
    widthMm: widthMm.toDouble(),
    heightMm: heightMm.toDouble(),
    includeInstallation: true,
    includeMotor: true,
    includeProfit: true,
    overrideMotorCost: shutterQuoteDefaultMotor,
    overrideInstallCost: shutterQuoteDefaultInstall,
    overrideEquipCost: shutterQuoteDefaultEquip,
    overrideBendingCost: shutterQuoteDefaultBending,
    overrideProfitCost: shutterQuoteDefaultProfit,
  );
  final fallbackMap = ShutterCalculator.buildSecurityFallbackUnitPriceMap(unit);
  final companies = _companies(
    rawRows: prices['company'] ?? const [],
    fallbackMap: fallbackMap,
  );
  final preferred = _lowestCompany(
    type: type,
    input: input,
    grid: grid,
    unit: unit,
    companies: companies,
    fallbackMap: fallbackMap,
  );
  final unitMap = preferred == null || preferred.id == _baseCompanyId
      ? null
      : ShutterCalculator.unitPriceMapFromCompany(
          preferred.toJson(),
          fallbackMap,
        );
  final result = ShutterCalculator.calculate(
    input: input,
    gridPrices: grid,
    unitPrices: unit,
    unitPriceOverrideMap: unitMap,
    insulatedSlatMm: ShutterCalculator.insulatedSlatMmForCompany(
      preferred?.companyName,
    ),
  );
  return ShutterLowestQuote(
    result: result,
    companyName: preferred?.companyName,
  );
}

List<ShutterCompanyUnitPrice> _companies({
  required List<Map<String, dynamic>> rawRows,
  required Map<String, int> fallbackMap,
}) {
  final registered =
      rawRows
          .asMap()
          .entries
          .map(
            (entry) => ShutterCompanyUnitPrice.fromJson(
              entry.value,
              fallbackId: 'company_${entry.key}',
            ),
          )
          .toList()
        ..sort((a, b) {
          final byOrder = a.sortOrder.compareTo(b.sortOrder);
          if (byOrder != 0) return byOrder;
          return a.companyName.compareTo(b.companyName);
        });
  final hasBase = registered.any(
    (company) => company.companyName.replaceAll(' ', '') == _baseCompanyName,
  );
  if (hasBase) return registered;
  return [
    ShutterCompanyUnitPrice(
      id: _baseCompanyId,
      companyName: _baseCompanyName,
      unitPriceGeneral: fallbackMap['이중압출'] ?? 81000,
      unitPriceInsulated: fallbackMap['이중압출단열'] ?? 144000,
      isDefault: true,
      sortOrder: -1,
    ),
    ...registered,
  ];
}

ShutterCompanyUnitPrice? _lowestCompany({
  required ShutterType type,
  required ShutterEstimateInput input,
  required List<Map<String, dynamic>> grid,
  required List<Map<String, dynamic>> unit,
  required List<ShutterCompanyUnitPrice> companies,
  required Map<String, int> fallbackMap,
}) {
  if (!ShutterCalculator.isSecurityType(type) || companies.isEmpty) return null;
  ShutterCompanyUnitPrice? cheapest;
  var cheapestTotal = 0;
  for (final company in companies) {
    final unitMap = company.id == _baseCompanyId
        ? null
        : ShutterCalculator.unitPriceMapFromCompany(
            company.toJson(),
            fallbackMap,
          );
    final total = ShutterCalculator.calculate(
      input: input,
      gridPrices: grid,
      unitPrices: unit,
      unitPriceOverrideMap: unitMap,
      insulatedSlatMm: ShutterCalculator.insulatedSlatMmForCompany(
        company.companyName,
      ),
    ).totalAmount;
    if (total <= 0) continue;
    if (cheapest == null || total < cheapestTotal) {
      cheapest = company;
      cheapestTotal = total;
    }
  }
  return cheapest;
}
