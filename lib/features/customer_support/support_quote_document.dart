import 'dart:convert';

import 'package:coad_customer_calls/core/utils/korean_amount_words.dart';
import 'package:coad_customer_calls/core/utils/phone_validation.dart';
import 'package:coad_customer_calls/features/customer_support/customer_support_flow.dart';
import 'package:coad_customer_calls/features/customer_support/support_unit_price.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

const kSupportQuoteKindPart = 'part';
const kSupportQuoteKindLabor = 'labor';
const kSupportQuoteKindEquipment = 'equipment';

const kSupportQuoteKindOrder = [
  kSupportQuoteKindPart,
  kSupportQuoteKindLabor,
  kSupportQuoteKindEquipment,
];

const kSupportQuoteUnits = ['EA', 'SET', '식', '장', 'M'];

String supportQuoteKindLabel(String kind) {
  switch (kind) {
    case kSupportQuoteKindLabor:
      return '인건비';
    case kSupportQuoteKindEquipment:
      return '장비대';
    default:
      return '부품';
  }
}

String normalizeSupportQuoteKind(String? raw) {
  switch ((raw ?? '').trim()) {
    case kSupportQuoteKindLabor:
    case '인건비':
      return kSupportQuoteKindLabor;
    case kSupportQuoteKindEquipment:
    case '장비대':
      return kSupportQuoteKindEquipment;
    default:
      return kSupportQuoteKindPart;
  }
}

String supportQuoteKindFromUnitPrice(SupportUnitPriceItem item) {
  if (item.isLabor) return kSupportQuoteKindLabor;
  final blob = '${item.name} ${item.category} ${item.note}'.toLowerCase();
  if (blob.contains('장비') || blob.contains('고소작업')) {
    return kSupportQuoteKindEquipment;
  }
  return kSupportQuoteKindPart;
}

class SupportQuoteLine {
  const SupportQuoteLine({
    required this.name,
    this.spec = '',
    this.unit = '',
    this.qty = 1,
    this.unitPrice,
    this.note = '',
    this.kind = kSupportQuoteKindPart,
  });

  final String name;
  final String spec;
  final String unit;
  final int qty;
  final int? unitPrice;
  final String note;
  final String kind;

  int get amount {
    final p = unitPrice ?? 0;
    return p <= 0 ? 0 : p * qty;
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'spec': spec,
    'unit': unit,
    'qty': qty,
    'unitPrice': unitPrice,
    'note': note,
    'kind': kind,
  };

  factory SupportQuoteLine.fromJson(Map<String, dynamic> json) {
    return SupportQuoteLine(
      name: (json['name'] ?? '').toString(),
      spec: (json['spec'] ?? '').toString(),
      unit: (json['unit'] ?? '').toString(),
      qty: int.tryParse('${json['qty'] ?? 1}') ?? 1,
      unitPrice: int.tryParse('${json['unitPrice'] ?? json['unit_price'] ?? ''}'),
      note: (json['note'] ?? '').toString(),
      kind: normalizeSupportQuoteKind(
        (json['kind'] ?? json['category'] ?? '').toString(),
      ),
    );
  }

  factory SupportQuoteLine.fromUnitPrice(
    SupportUnitPriceItem item, {
    int qty = 1,
  }) {
    return SupportQuoteLine(
      name: item.name.trim(),
      spec: item.spec.trim(),
      unit: item.unit.trim().isEmpty
          ? (item.isLabor ? '식' : 'EA')
          : item.unit.trim(),
      qty: qty <= 0 ? 1 : qty,
      unitPrice: item.price,
      note: item.displayNote,
      kind: supportQuoteKindFromUnitPrice(item),
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
    this.workName = '',
    this.quoteNo = '',
    required this.ymd,
    this.lines = const [],
    this.note = '',
    this.createdBy,
    this.createdAt,
    this.sentYmd,
    this.callLogId,
  });

  final String id;
  final String customerName;
  final String phone;
  final String email;
  final String site;
  final String address;
  final String workName;
  final String quoteNo;
  final String ymd;
  final List<SupportQuoteLine> lines;
  final String note;
  final String? createdBy;
  final String? createdAt;
  final String? sentYmd;
  final String? callLogId;

  int get total => lines.fold(0, (sum, e) => sum + e.amount);

  List<SupportQuoteLine> linesOfKind(String kind) =>
      lines.where((e) => e.kind == kind).toList();

  Map<String, dynamic> toJson() => {
    'id': id,
    'customerName': customerName,
    'phone': phone,
    'email': email,
    'site': site,
    'address': address,
    'workName': workName,
    'quoteNo': quoteNo,
    'ymd': ymd,
    'lines': lines.map((e) => e.toJson()).toList(),
    'note': note,
    'createdBy': createdBy,
    'createdAt': createdAt,
    'sentYmd': sentYmd,
    'callLogId': callLogId,
  };

  factory SupportQuoteDocument.fromJson(Map<String, dynamic> json) {
    final rawLines = json['lines'];
    return SupportQuoteDocument(
      id: (json['id'] ?? '').toString(),
      customerName: (json['customerName'] ?? json['customer_name'] ?? '')
          .toString(),
      phone: (json['phone'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      site: (json['site'] ?? json['site_name'] ?? '').toString(),
      address: (json['address'] ?? '').toString(),
      workName: (json['workName'] ?? json['work_name'] ?? '').toString(),
      quoteNo: (json['quoteNo'] ?? json['quote_no'] ?? '').toString(),
      ymd: (json['ymd'] ?? json['quote_date'] ?? '')
          .toString()
          .split('T')
          .first
          .split(' ')
          .first,
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
      createdBy: (json['createdBy'] ?? json['created_by'])?.toString(),
      createdAt: (json['createdAt'] ?? json['created_at'])?.toString(),
      sentYmd: () {
        final raw = json['sentYmd'] ?? json['sent_ymd'];
        if (raw == null) return null;
        final s = raw.toString().split('T').first.split(' ').first;
        return s.isEmpty ? null : s;
      }(),
      callLogId: (json['callLogId'] ?? json['call_log_id'])?.toString(),
    );
  }

  SupportQuoteDocument copyWith({
    String? sentYmd,
    String? quoteNo,
    String? callLogId,
  }) {
    return SupportQuoteDocument(
      id: id,
      customerName: customerName,
      phone: phone,
      email: email,
      site: site,
      address: address,
      workName: workName,
      quoteNo: quoteNo ?? this.quoteNo,
      ymd: ymd,
      lines: lines,
      note: note,
      createdBy: createdBy,
      createdAt: createdAt,
      sentYmd: sentYmd ?? this.sentYmd,
      callLogId: callLogId ?? this.callLogId,
    );
  }
}

bool supportQuoteMatches(SupportQuoteDocument doc, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return true;
  final digits = normalizePhoneDigits(query);
  if (digits.length >= 4 &&
      normalizePhoneDigits(doc.phone).contains(digits)) {
    return true;
  }
  final blob = [
    doc.customerName,
    doc.phone,
    doc.email,
    doc.site,
    doc.address,
    doc.workName,
    doc.quoteNo,
    doc.note,
    doc.ymd,
    doc.sentYmd ?? '',
    '${doc.total}',
    ...doc.lines.map((e) => '${e.name} ${e.spec} ${e.unit} ${e.note} ${supportQuoteKindLabel(e.kind)}'),
  ].join(' ').toLowerCase();
  return blob.contains(q);
}

bool supportQuoteBelongsToSite(
  SupportQuoteDocument doc, {
  String? phone,
  String? site,
  String? customerName,
}) {
  final phoneDigits = normalizePhoneDigits(phone ?? '');
  final docPhone = normalizePhoneDigits(doc.phone);
  if (phoneDigits.length >= 8 &&
      docPhone.length >= 8 &&
      (docPhone.contains(phoneDigits) || phoneDigits.contains(docPhone))) {
    return true;
  }
  final siteName = (site ?? '').trim().toLowerCase();
  if (siteName.isNotEmpty &&
      (doc.site.trim().toLowerCase() == siteName ||
          doc.customerName.trim().toLowerCase() == siteName)) {
    return true;
  }
  final name = (customerName ?? '').trim().toLowerCase();
  if (name.isNotEmpty && doc.customerName.trim().toLowerCase() == name) {
    return true;
  }
  return false;
}

bool supportQuoteBelongsToSample(
  SupportQuoteDocument doc,
  SupportSiteSample site,
) {
  return supportQuoteBelongsToSite(
    doc,
    phone: site.phone,
    site: site.name,
    customerName: site.name,
  );
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
    if (doc.quoteNo.trim().isNotEmpty) '견적번호: ${doc.quoteNo.trim()}',
    '견적일: ${doc.ymd}',
    '합계: $totalLabel',
    '첨부된 견적서를 확인해 주세요.',
  ].join('\n');
}

String supportQuoteKoreanTotalLabel(int amount) {
  final won = NumberFormat('#,###');
  if (amount <= 0) return '일금 영원정 (0원, VAT. 별도)';
  final words = koreanWonInWords(amount).replaceFirst(RegExp(r'원$'), '');
  return '일금 $words원정 (${won.format(amount)}원, VAT. 별도)';
}

String supportQuoteHistoryLine(SupportQuoteDocument doc) {
  final won = NumberFormat('#,###');
  final total = doc.total <= 0 ? '-' : '${won.format(doc.total)}원';
  final sent = (doc.sentYmd ?? '').trim();
  final when = sent.isNotEmpty ? sent : doc.ymd;
  final status = sent.isNotEmpty ? '발송' : '작성';
  final no = doc.quoteNo.trim();
  return [
    when,
    if (no.isNotEmpty) no,
    total,
    status,
    if (doc.workName.trim().isNotEmpty) doc.workName.trim(),
  ].join(' · ');
}

class SupportQuoteSiteGroup {
  const SupportQuoteSiteGroup({
    required this.key,
    required this.title,
    required this.quotes,
    this.phone = '',
    this.address = '',
    this.customerName = '',
  });

  final String key;
  final String title;
  final String phone;
  final String address;
  final String customerName;
  final List<SupportQuoteDocument> quotes;

  int get total => quotes.fold(0, (sum, e) => sum + e.total);

  SupportSiteSample toSiteSample() {
    return SupportSiteSample(
      id: key,
      name: title,
      address: address,
      phone: phone,
      assignee: '',
      revisitCount: 0,
      installCompletedYmd: null,
      addresses: [if (address.trim().isNotEmpty) address.trim()],
      history: quotes.map(supportQuoteHistoryLine).toList(),
      quotes: quotes.map(supportQuoteHistoryLine).toList(),
      hasBusinessLicense: false,
      hasChecksheet: false,
    );
  }
}

String supportQuoteSiteGroupKey(SupportQuoteDocument doc) {
  final phone = normalizePhoneDigits(doc.phone);
  if (phone.length >= 8) return 'p:$phone';
  final site = doc.site.trim().toLowerCase();
  if (site.isNotEmpty) return 's:$site';
  final name = doc.customerName.trim().toLowerCase();
  if (name.isNotEmpty) return 'n:$name';
  return 'id:${doc.id}';
}

List<SupportQuoteSiteGroup> supportQuoteSiteGroups(
  List<SupportQuoteDocument> items,
) {
  final map = <String, List<SupportQuoteDocument>>{};
  for (final doc in items) {
    map.putIfAbsent(supportQuoteSiteGroupKey(doc), () => []).add(doc);
  }
  final groups = <SupportQuoteSiteGroup>[];
  for (final entry in map.entries) {
    final quotes = [...entry.value]
      ..sort((a, b) => b.ymd.compareTo(a.ymd));
    String pick(String Function(SupportQuoteDocument doc) of) {
      for (final q in quotes) {
        final v = of(q).trim();
        if (v.isNotEmpty) return v;
      }
      return '';
    }

    final title = pick((q) => q.site).isNotEmpty
        ? pick((q) => q.site)
        : (pick((q) => q.customerName).isNotEmpty
              ? pick((q) => q.customerName)
              : '(현장 없음)');
    groups.add(
      SupportQuoteSiteGroup(
        key: entry.key,
        title: title,
        phone: pick((q) => q.phone),
        address: pick((q) => q.address),
        customerName: pick((q) => q.customerName),
        quotes: quotes,
      ),
    );
  }
  groups.sort((a, b) {
    final ay = a.quotes.isEmpty ? '' : a.quotes.first.ymd;
    final by = b.quotes.isEmpty ? '' : b.quotes.first.ymd;
    return by.compareTo(ay);
  });
  return groups;
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
