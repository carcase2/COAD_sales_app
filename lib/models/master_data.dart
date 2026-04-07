class NamedMasterRow {
  NamedMasterRow({required this.id, required this.name, this.extra = const {}});

  final String id;
  final String name;
  final Map<String, String> extra;

  factory NamedMasterRow.fromJson(Map<String, dynamic> json) {
    final id = _pick(json, const ['id']) ?? '';
    final name = _pick(json, const ['name', 'sido', 'region', 'title']) ?? '';
    final extra = <String, String>{};
    for (final e in json.entries) {
      if (e.value != null) extra[e.key] = e.value.toString();
    }
    return NamedMasterRow(id: id, name: name.isNotEmpty ? name : id, extra: extra);
  }
}

class MasterDataBundle {
  MasterDataBundle({
    required this.productCategories,
    required this.inquiryMethods,
    required this.regions,
  });

  final List<NamedMasterRow> productCategories;
  final List<NamedMasterRow> inquiryMethods;
  final List<NamedMasterRow> regions;

  factory MasterDataBundle.fromJson(Map<String, dynamic> json) {
    return MasterDataBundle(
      productCategories: _list(json, const ['product_categories', 'productCategories']),
      inquiryMethods: _list(json, const ['inquiry_methods', 'inquiryMethods']),
      regions: _list(json, const ['regions']),
    );
  }
}

List<NamedMasterRow> _list(Map<String, dynamic> json, List<String> keys) {
  for (final k in keys) {
    final v = json[k];
    if (v is List) {
      return v
          .whereType<Map>()
          .map((e) => NamedMasterRow.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
  }
  return [];
}

String? _pick(Map<String, dynamic> json, List<String> keys) {
  for (final k in keys) {
    final v = json[k];
    if (v != null) return v.toString();
  }
  return null;
}
