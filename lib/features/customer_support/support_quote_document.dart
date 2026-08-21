import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class SupportQuoteLine {
  const SupportQuoteLine({
    required this.name,
    this.spec = '',
    this.qty = 1,
    this.unitPrice,
    this.note = '',
  });

  final String name;
  final String spec;
  final int qty;
  final int? unitPrice;
  final String note;

  int get amount {
    final p = unitPrice ?? 0;
    return p <= 0 ? 0 : p * qty;
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'spec': spec,
    'qty': qty,
    'unitPrice': unitPrice,
    'note': note,
  };

  factory SupportQuoteLine.fromJson(Map<String, dynamic> json) {
    return SupportQuoteLine(
      name: (json['name'] ?? '').toString(),
      spec: (json['spec'] ?? '').toString(),
      qty: int.tryParse('${json['qty'] ?? 1}') ?? 1,
      unitPrice: int.tryParse('${json['unitPrice'] ?? ''}'),
      note: (json['note'] ?? '').toString(),
    );
  }
}

class SupportQuoteDocument {
  const SupportQuoteDocument({
    required this.id,
    required this.customerName,
    this.phone = '',
    this.email = '',
    this.site = '',
    this.address = '',
    required this.ymd,
    this.lines = const [],
    this.note = '',
    this.createdBy,
    this.createdAt,
  });

  final String id;
  final String customerName;
  final String phone;
  final String email;
  final String site;
  final String address;
  final String ymd;
  final List<SupportQuoteLine> lines;
  final String note;
  final String? createdBy;
  final String? createdAt;

  int get total => lines.fold(0, (sum, e) => sum + e.amount);

  Map<String, dynamic> toJson() => {
    'id': id,
    'customerName': customerName,
    'phone': phone,
    'email': email,
    'site': site,
    'address': address,
    'ymd': ymd,
    'lines': lines.map((e) => e.toJson()).toList(),
    'note': note,
    'createdBy': createdBy,
    'createdAt': createdAt,
  };

  factory SupportQuoteDocument.fromJson(Map<String, dynamic> json) {
    final rawLines = json['lines'];
    return SupportQuoteDocument(
      id: (json['id'] ?? '').toString(),
      customerName: (json['customerName'] ?? '').toString(),
      phone: (json['phone'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      site: (json['site'] ?? '').toString(),
      address: (json['address'] ?? '').toString(),
      ymd: (json['ymd'] ?? '').toString(),
      lines: rawLines is List
          ? rawLines
                .whereType<Map>()
                .map(
                  (e) =>
                      SupportQuoteLine.fromJson(Map<String, dynamic>.from(e)),
                )
                .toList()
          : const [],
      note: (json['note'] ?? '').toString(),
      createdBy: json['createdBy']?.toString(),
      createdAt: json['createdAt']?.toString(),
    );
  }
}

bool supportQuoteMatches(SupportQuoteDocument doc, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return true;
  final blob = [
    doc.customerName,
    doc.phone,
    doc.email,
    doc.site,
    doc.address,
    doc.note,
    doc.ymd,
    ...doc.lines.map((e) => '${e.name} ${e.spec} ${e.note}'),
  ].join(' ').toLowerCase();
  return blob.contains(q);
}

String supportQuoteFileStem(SupportQuoteDocument doc) {
  final raw = doc.customerName.trim().isEmpty ? '고객' : doc.customerName.trim();
  final safe = raw.replaceAll(RegExp(r'[\\/:*?"<>|\s]+'), '_');
  final day = doc.ymd.trim().isEmpty ? '' : '_${doc.ymd.trim()}';
  return 'AS견적서_$safe$day';
}

String supportQuoteEmailSubject(SupportQuoteDocument doc) {
  final name = doc.customerName.trim().isEmpty ? '고객' : doc.customerName.trim();
  return '[COAD A/S 견적서] $name ${doc.ymd}'.trim();
}

String supportQuoteEmailBody(
  SupportQuoteDocument doc, {
  required String totalLabel,
}) {
  final name = doc.customerName.trim().isEmpty ? '고객' : doc.customerName.trim();
  final site = doc.site.trim();
  return [
    '$name 고객님 A/S 견적서입니다.',
    if (site.isNotEmpty) '현장: $site',
    '견적일: ${doc.ymd}',
    '합계: $totalLabel',
    '첨부된 견적서를 확인해 주세요.',
  ].join('\n');
}

const _prefsKey = 'support_as_quotes_v1';

class SupportQuoteStore {
  SupportQuoteStore(this._prefs);

  final SharedPreferences _prefs;

  List<SupportQuoteDocument> load() {
    final raw = _prefs.getString(_prefsKey);
    if (raw == null || raw.trim().isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map(
            (e) => SupportQuoteDocument.fromJson(Map<String, dynamic>.from(e)),
          )
          .where((e) => e.id.isNotEmpty)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> save(List<SupportQuoteDocument> items) async {
    await _prefs.setString(
      _prefsKey,
      jsonEncode(items.map((e) => e.toJson()).toList()),
    );
  }
}
