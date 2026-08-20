import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class SupportUnitPriceItem {
  const SupportUnitPriceItem({
    required this.id,
    required this.name,
    this.spec = '',
    this.price,
    this.note = '',
  });

  final String id;
  final String name;
  final String spec;
  final int? price;
  final String note;

  SupportUnitPriceItem copyWith({
    String? name,
    String? spec,
    int? price,
    String? note,
    bool clearPrice = false,
  }) {
    return SupportUnitPriceItem(
      id: id,
      name: name ?? this.name,
      spec: spec ?? this.spec,
      price: clearPrice ? null : (price ?? this.price),
      note: note ?? this.note,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'spec': spec,
    'price': price,
    'note': note,
  };

  factory SupportUnitPriceItem.fromJson(Map<String, dynamic> json) {
    return SupportUnitPriceItem(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      spec: (json['spec'] ?? '').toString(),
      price: int.tryParse('${json['price'] ?? ''}'),
      note: (json['note'] ?? '').toString(),
    );
  }
}

bool supportUnitPriceMatches(SupportUnitPriceItem item, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return true;
  final blob = [
    item.name,
    item.spec,
    item.note,
    if (item.price != null) '${item.price}',
  ].join(' ').toLowerCase();
  return blob.contains(q);
}

const _prefsKey = 'support_as_unit_prices_v1';

class SupportUnitPriceStore {
  SupportUnitPriceStore(this._prefs);

  final SharedPreferences _prefs;

  List<SupportUnitPriceItem> load() {
    final raw = _prefs.getString(_prefsKey);
    if (raw == null || raw.trim().isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map(
            (e) => SupportUnitPriceItem.fromJson(Map<String, dynamic>.from(e)),
          )
          .where((e) => e.id.isNotEmpty && e.name.trim().isNotEmpty)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> save(List<SupportUnitPriceItem> items) async {
    await _prefs.setString(
      _prefsKey,
      jsonEncode(items.map((e) => e.toJson()).toList()),
    );
  }
}
