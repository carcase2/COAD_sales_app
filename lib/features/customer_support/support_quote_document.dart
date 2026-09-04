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
      unitPrice: int.tryParse(
        '${json['unitPrice'] ?? json['unit_price'] ?? ''}',
      ),
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

class SupportQuoteEditEvent {
  const SupportQuoteEditEvent({
    required this.at,
    required this.by,
    required this.summary,
  });

  final String at;
  final String by;
  final String summary;

  Map<String, dynamic> toJson() => {
    'at': at,
    'by': by,
    'summary': summary,
  };

  factory SupportQuoteEditEvent.fromJson(Map<String, dynamic> json) {
    return SupportQuoteEditEvent(
      at: (json['at'] ?? '').toString(),
      by: (json['by'] ?? '').toString(),
      summary: (json['summary'] ?? '').toString(),
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
    this.updatedBy,
    this.updatedAt,
    this.sentYmd,
    this.callLogId,
    this.negoAmount = 0,
    this.negoPercent = 0,
    this.editHistory = const [],
    this.pdfPath,
    this.pdfUploadedAt,
    this.pdfUploadedBy,
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
  final String? updatedBy;
  final String? updatedAt;
  final String? sentYmd;
  final String? callLogId;

  /// 네고 할인 금액(원). [negoPercent]와 배타.
  final int negoAmount;

  /// 네고 할인율(%). [negoAmount]와 배타.
  final double negoPercent;

  /// 저장 이력 (시간순). 최근 항목이 뒤에 온다.
  final List<SupportQuoteEditEvent> editHistory;

  /// Storage 객체 경로 (`support-as-quotes` 버킷).
  final String? pdfPath;
  final String? pdfUploadedAt;

  /// PDF를 클라우드에 올린 사람(최종작성자).
  final String? pdfUploadedBy;

  static const editHistoryLimit = 40;

  bool get hasCloudPdf => (pdfPath ?? '').trim().isNotEmpty;

  /// 품목 합계(네고 전).
  int get listTotal => lines.fold(0, (sum, e) => sum + e.amount);

  /// 네고로 깎는 금액.
  int get negoOff {
    final list = listTotal;
    if (list <= 0) return 0;
    if (negoPercent > 0) {
      final cut = (list * negoPercent / 100).round();
      return cut > list ? list : cut;
    }
    if (negoAmount > 0) return negoAmount > list ? list : negoAmount;
    return 0;
  }

  bool get hasNego => negoOff > 0;

  /// 네고 반영 최종 합계.
  int get total => listTotal - negoOff;

  String get negoSummary {
    if (!hasNego) return '';
    final won = NumberFormat('#,###');
    if (negoPercent > 0) {
      final p = negoPercent == negoPercent.roundToDouble()
          ? '${negoPercent.round()}'
          : negoPercent.toStringAsFixed(1);
      return '$p% (−${won.format(negoOff)}원)';
    }
    return '−${won.format(negoOff)}원';
  }

  bool get isSent => (sentYmd ?? '').trim().isNotEmpty;

  bool get wasEdited =>
      (updatedAt ?? '').trim().isNotEmpty &&
      (updatedAt!.trim() != (createdAt ?? '').trim() ||
          ((updatedBy ?? '').trim().isNotEmpty &&
              (updatedBy!.trim() != (createdBy ?? '').trim())));

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
    'updatedBy': updatedBy,
    'updatedAt': updatedAt,
    'sentYmd': sentYmd,
    'callLogId': callLogId,
    'negoAmount': negoAmount,
    'negoPercent': negoPercent,
    'editHistory': editHistory.map((e) => e.toJson()).toList(),
    'pdfPath': pdfPath,
    'pdfUploadedAt': pdfUploadedAt,
    'pdfUploadedBy': pdfUploadedBy,
  };

  factory SupportQuoteDocument.fromJson(Map<String, dynamic> json) {
    final rawLines = json['lines'];
    final rawHistory = json['editHistory'] ?? json['edit_history'];
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
      updatedBy: (json['updatedBy'] ?? json['updated_by'])?.toString(),
      updatedAt: (json['updatedAt'] ?? json['updated_at'])?.toString(),
      sentYmd: () {
        final raw = json['sentYmd'] ?? json['sent_ymd'];
        if (raw == null) return null;
        final s = raw.toString().split('T').first.split(' ').first;
        return s.isEmpty ? null : s;
      }(),
      callLogId: (json['callLogId'] ?? json['call_log_id'])?.toString(),
      negoAmount:
          int.tryParse(
            '${json['negoAmount'] ?? json['nego_amount'] ?? 0}',
          ) ??
          0,
      negoPercent:
          double.tryParse(
            '${json['negoPercent'] ?? json['nego_percent'] ?? 0}',
          ) ??
          0,
      editHistory: rawHistory is List
          ? rawHistory
                .whereType<Map>()
                .map(
                  (e) => SupportQuoteEditEvent.fromJson(
                    Map<String, dynamic>.from(e),
                  ),
                )
                .toList()
          : const [],
      pdfPath: () {
        final raw = json['pdfPath'] ?? json['pdf_path'];
        if (raw == null) return null;
        final s = raw.toString().trim();
        return s.isEmpty ? null : s;
      }(),
      pdfUploadedAt: (json['pdfUploadedAt'] ?? json['pdf_uploaded_at'])
          ?.toString(),
      pdfUploadedBy: (json['pdfUploadedBy'] ?? json['pdf_uploaded_by'])
          ?.toString(),
    );
  }

  SupportQuoteDocument copyWith({
    String? sentYmd,
    bool clearSentYmd = false,
    String? quoteNo,
    String? callLogId,
    int? negoAmount,
    double? negoPercent,
    String? createdBy,
    String? createdAt,
    String? updatedBy,
    String? updatedAt,
    List<SupportQuoteEditEvent>? editHistory,
    String? customerName,
    String? phone,
    String? email,
    String? site,
    String? address,
    String? workName,
    String? ymd,
    List<SupportQuoteLine>? lines,
    String? note,
    String? pdfPath,
    String? pdfUploadedAt,
    String? pdfUploadedBy,
  }) {
    return SupportQuoteDocument(
      id: id,
      customerName: customerName ?? this.customerName,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      site: site ?? this.site,
      address: address ?? this.address,
      workName: workName ?? this.workName,
      quoteNo: quoteNo ?? this.quoteNo,
      ymd: ymd ?? this.ymd,
      lines: lines ?? this.lines,
      note: note ?? this.note,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedBy: updatedBy ?? this.updatedBy,
      updatedAt: updatedAt ?? this.updatedAt,
      sentYmd: clearSentYmd ? null : (sentYmd ?? this.sentYmd),
      callLogId: callLogId ?? this.callLogId,
      negoAmount: negoAmount ?? this.negoAmount,
      negoPercent: negoPercent ?? this.negoPercent,
      editHistory: editHistory ?? this.editHistory,
      pdfPath: pdfPath ?? this.pdfPath,
      pdfUploadedAt: pdfUploadedAt ?? this.pdfUploadedAt,
      pdfUploadedBy: pdfUploadedBy ?? this.pdfUploadedBy,
    );
  }
}

bool supportQuoteMatches(SupportQuoteDocument doc, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return true;
  final digits = normalizePhoneDigits(query);
  if (digits.length >= 4 && normalizePhoneDigits(doc.phone).contains(digits)) {
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
    ...doc.lines.map(
      (e) =>
          '${e.name} ${e.spec} ${e.unit} ${e.note} ${supportQuoteKindLabel(e.kind)}',
    ),
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

String supportQuoteConsultBody(SupportQuoteDocument doc) {
  final won = NumberFormat('#,###');
  return [
    supportQuoteHistoryLine(doc),
    for (final line in doc.lines)
      [
        supportQuoteKindLabel(line.kind),
        line.name.trim(),
        if (line.spec.trim().isNotEmpty) line.spec.trim(),
        if (line.qty > 0) '${line.qty}${line.unit.trim()}',
        if (line.amount > 0) '${won.format(line.amount)}원',
      ].where((e) => e.trim().isNotEmpty).join(' · '),
    if (doc.total > 0) '합계 ${won.format(doc.total)}원',
    if (doc.hasNego) '네고 ${doc.negoSummary} (품목 ${won.format(doc.listTotal)}원)',
  ].where((e) => e.trim().isNotEmpty).join('\n');
}

String supportQuoteHistoryLine(SupportQuoteDocument doc) {
  final won = NumberFormat('#,###');
  final total = doc.total <= 0 ? '-' : '${won.format(doc.total)}원';
  final sent = (doc.sentYmd ?? '').trim();
  final when = sent.isNotEmpty ? sent : doc.ymd;
  final status = sent.isNotEmpty ? '발송완료' : '미발송';
  final no = doc.quoteNo.trim();
  return [
    when,
    if (no.isNotEmpty) no,
    total,
    status,
    if (doc.workName.trim().isNotEmpty) doc.workName.trim(),
  ].join(' · ');
}

String supportQuoteSnapshotSummary(SupportQuoteDocument doc) {
  final won = NumberFormat('#,###');
  return [
    '품목 ${doc.lines.length}건',
    '합계 ${doc.total <= 0 ? '0' : won.format(doc.total)}원',
    if (doc.hasNego) '네고 ${doc.negoSummary}',
    if (doc.isSent) '발송완료',
  ].join(' · ');
}

String supportQuoteEditDiffSummary(
  SupportQuoteDocument before,
  SupportQuoteDocument after,
) {
  final won = NumberFormat('#,###');
  final changes = <String>[];
  if (before.total != after.total) {
    changes.add(
      '합계 ${won.format(before.total)}→${won.format(after.total)}원',
    );
  }
  if (before.lines.length != after.lines.length) {
    changes.add('품목 ${before.lines.length}→${after.lines.length}건');
  }
  if (before.negoOff != after.negoOff ||
      before.negoPercent != after.negoPercent ||
      before.negoAmount != after.negoAmount) {
    if (after.hasNego) {
      changes.add('네고 ${after.negoSummary}');
    } else if (before.hasNego) {
      changes.add('네고 해제');
    }
  }
  if (before.customerName.trim() != after.customerName.trim()) {
    changes.add('고객명 변경');
  }
  if (before.site.trim() != after.site.trim()) {
    changes.add('현장 변경');
  }
  if (before.ymd.trim() != after.ymd.trim()) {
    changes.add('견적일 ${before.ymd}→${after.ymd}');
  }
  if ((before.sentYmd ?? '') != (after.sentYmd ?? '')) {
    changes.add(after.isSent ? '발송완료 표시' : '미발송 표시');
  }
  if (before.note.trim() != after.note.trim()) {
    changes.add('비고 변경');
  }
  if (changes.isEmpty) {
    changes.add('내용 저장 · ${supportQuoteSnapshotSummary(after)}');
  }
  return changes.join(' · ');
}

String _supportQuoteShortWhen(String? iso) {
  final raw = (iso ?? '').trim();
  if (raw.isEmpty) return '';
  final dt = DateTime.tryParse(raw);
  if (dt == null) {
    return raw.length >= 16 ? raw.substring(0, 16).replaceFirst('T', ' ') : raw;
  }
  final local = dt.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)} '
      '${two(local.hour)}:${two(local.minute)}';
}

/// 목록·상세용: 생성일·작성자·수정자·발송일
String supportQuoteAuditLine(SupportQuoteDocument doc) {
  final createdBy = (doc.createdBy ?? '').trim();
  final updatedBy = (doc.updatedBy ?? '').trim();
  final pdfBy = (doc.pdfUploadedBy ?? '').trim();
  final createdAt = _supportQuoteShortWhen(doc.createdAt);
  final updatedAt = _supportQuoteShortWhen(doc.updatedAt);
  final created = [
    if (createdBy.isNotEmpty) '작성 $createdBy',
    if (createdAt.isNotEmpty) createdAt,
  ].join(' ');
  final edited =
      doc.wasEdited ||
      (updatedBy.isNotEmpty && updatedBy != createdBy) ||
      (updatedAt.isNotEmpty && updatedAt != createdAt);
  final updated = !edited
      ? ''
      : [
          if (updatedBy.isNotEmpty) '수정 $updatedBy',
          if (updatedAt.isNotEmpty) updatedAt,
        ].join(' ');
  final finalAuthor = pdfBy.isNotEmpty && pdfBy != createdBy && pdfBy != updatedBy
      ? '최종 $pdfBy'
      : (pdfBy.isNotEmpty && !edited ? '최종 $pdfBy' : '');
  final sent = (doc.sentYmd ?? '').trim();
  final sentLine = sent.isEmpty ? '' : '발송 $sent';
  final cloud = doc.hasCloudPdf ? '클라우드 PDF' : '';
  return [
    if (created.isNotEmpty) created,
    if (updated.isNotEmpty) updated,
    if (finalAuthor.isNotEmpty) finalAuthor,
    if (sentLine.isNotEmpty) sentLine,
    if (cloud.isNotEmpty) cloud,
  ].join(' · ');
}

List<SupportQuoteEditEvent> supportQuoteAppendEditHistory({
  required List<SupportQuoteEditEvent> previous,
  required String at,
  required String by,
  required String summary,
}) {
  final next = [
    ...previous,
    SupportQuoteEditEvent(
      at: at,
      by: by.trim().isEmpty ? '미상' : by.trim(),
      summary: summary,
    ),
  ];
  if (next.length <= SupportQuoteDocument.editHistoryLimit) return next;
  return next.sublist(next.length - SupportQuoteDocument.editHistoryLimit);
}

/// 방문 기록에 넣을 견적서. 이 접수 발송분 우선, 없으면 현장 발송분, 없으면 최신.
SupportQuoteDocument? pickSupportQuoteForVisitReport(
  List<SupportQuoteDocument> quotes, {
  required String callLogId,
}) {
  if (quotes.isEmpty) return null;
  final logId = callLogId.trim();
  final forLog = logId.isEmpty
      ? const <SupportQuoteDocument>[]
      : quotes.where((q) => (q.callLogId ?? '').trim() == logId).toList();
  final pool = forLog.isNotEmpty ? forLog : quotes;
  final sent = pool.where((q) => q.isSent).toList();
  final candidates = List<SupportQuoteDocument>.from(
    sent.isNotEmpty ? sent : pool,
  );
  candidates.sort((a, b) {
    final ay = (a.sentYmd ?? a.ymd).compareTo(b.sentYmd ?? b.ymd);
    if (ay != 0) return -ay;
    return (b.createdAt ?? '').compareTo(a.createdAt ?? '');
  });
  return candidates.first;
}

List<String> supportQuotePartNames(SupportQuoteDocument doc) {
  final out = <String>[];
  final seen = <String>{};
  for (final line in doc.lines) {
    final name = line.name.trim();
    if (name.isEmpty || !seen.add(name)) continue;
    out.add(name);
  }
  return out;
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
    final quotes = [...entry.value]..sort((a, b) => b.ymd.compareTo(a.ymd));
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
