/// 타사 단가 비교용 모델 — 견적기 화면에서 사용.
class ShutterCompanyUnitPrice {
  const ShutterCompanyUnitPrice({
    required this.id,
    required this.companyName,
    required this.unitPriceGeneral,
    required this.unitPriceInsulated,
    required this.isDefault,
    required this.sortOrder,
  });

  factory ShutterCompanyUnitPrice.fromJson(
    Map<String, dynamic> json, {
    required String fallbackId,
  }) {
    int parseInt(dynamic value) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse(value?.toString() ?? '') ?? 0;
    }

    final parsedId = (json['id'] ?? '').toString().trim();
    return ShutterCompanyUnitPrice(
      id: parsedId.isEmpty ? fallbackId : parsedId,
      companyName: (json['company_name'] ?? '').toString().trim().isEmpty
          ? '이름 미등록'
          : (json['company_name'] ?? '').toString().trim(),
      unitPriceGeneral: parseInt(json['unit_price_general']),
      unitPriceInsulated: parseInt(json['unit_price_insulated']),
      isDefault: json['is_default'] == true,
      sortOrder: parseInt(json['sort_order']),
    );
  }

  final String id;
  final String companyName;
  final int unitPriceGeneral;
  final int unitPriceInsulated;
  final bool isDefault;
  final int sortOrder;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'company_name': companyName,
        'unit_price_general': unitPriceGeneral,
        'unit_price_insulated': unitPriceInsulated,
        'is_default': isDefault,
        'sort_order': sortOrder,
      };
}

class CompanyComparisonRow {
  const CompanyComparisonRow({
    required this.company,
    required this.totalAmount,
    required this.slatAmount,
    this.deltaFromSelected = 0,
  });

  final ShutterCompanyUnitPrice company;
  final int totalAmount;
  final int slatAmount;
  final int deltaFromSelected;

  CompanyComparisonRow copyWith({int? deltaFromSelected}) {
    return CompanyComparisonRow(
      company: company,
      totalAmount: totalAmount,
      slatAmount: slatAmount,
      deltaFromSelected: deltaFromSelected ?? this.deltaFromSelected,
    );
  }
}

class CompanyContext {
  const CompanyContext({
    required this.companies,
    required this.selectedCompanyId,
    required this.selectedCompany,
    required this.fallbackUnitPriceMap,
  });

  final List<ShutterCompanyUnitPrice> companies;
  final String? selectedCompanyId;
  final ShutterCompanyUnitPrice? selectedCompany;
  final Map<String, int> fallbackUnitPriceMap;
}
