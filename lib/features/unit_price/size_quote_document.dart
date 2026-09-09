import 'package:coad_customer_calls/core/utils/korean_amount_words.dart';
import 'package:coad_customer_calls/core/utils/phone_validation.dart';
import 'package:intl/intl.dart';

const kSizeQuoteKindMain = 'main';
const kSizeQuoteKindAccessory = 'accessory';
const kSizeQuoteKindOther = 'other';

const kSizeQuoteKindOrder = [
  kSizeQuoteKindMain,
  kSizeQuoteKindAccessory,
  kSizeQuoteKindOther,
];

const kSizeQuoteUnits = ['SET', 'EA', '식', '장', 'M'];

const kSizeQuoteMarkupNone = 'none';
const kSizeQuoteMarkupPercent = 'percent';
const kSizeQuoteMarkupAmount = 'amount';

const kSizeQuoteFitLineName = '금액 조정';

String sizeQuoteKindLabel(String kind) {
  switch (kind) {
    case kSizeQuoteKindAccessory:
      return '부자재';
    case kSizeQuoteKindOther:
      return '기타';
    default:
      return '메인';
  }
}

String normalizeSizeQuoteKind(String? raw) {
  switch ((raw ?? '').trim()) {
    case kSizeQuoteKindAccessory:
    case '부자재':
    case 'sub':
      return kSizeQuoteKindAccessory;
    case kSizeQuoteKindOther:
    case '기타':
      return kSizeQuoteKindOther;
    default:
      return kSizeQuoteKindMain;
  }
}

String normalizeSizeQuoteMarkup(String? raw) {
  switch ((raw ?? '').trim()) {
    case kSizeQuoteMarkupPercent:
    case '%':
      return kSizeQuoteMarkupPercent;
    case kSizeQuoteMarkupAmount:
    case '금액':
      return kSizeQuoteMarkupAmount;
    default:
      return kSizeQuoteMarkupNone;
  }
}

int sizeQuoteApplyMarkup({
  required int standardPrice,
  required String markupType,
  required num markupValue,
}) {
  if (standardPrice <= 0) return 0;
  final type = normalizeSizeQuoteMarkup(markupType);
  if (type == kSizeQuoteMarkupPercent && markupValue != 0) {
    final next = (standardPrice * (1 + markupValue / 100)).round();
    return next < 0 ? 0 : next;
  }
  if (type == kSizeQuoteMarkupAmount && markupValue != 0) {
    final next = standardPrice + markupValue.round();
    return next < 0 ? 0 : next;
  }
  return standardPrice;
}

String sizeQuoteMarkupSummary({
  required String markupType,
  required num markupValue,
}) {
  final type = normalizeSizeQuoteMarkup(markupType);
  final won = NumberFormat('#,###');
  if (type == kSizeQuoteMarkupPercent && markupValue != 0) {
    final p = markupValue == markupValue.roundToDouble()
        ? '${markupValue.round()}'
        : markupValue.toStringAsFixed(1);
    return '+$p%';
  }
  if (type == kSizeQuoteMarkupAmount && markupValue != 0) {
    final n = markupValue.round();
    final sign = n >= 0 ? '+' : '';
    return '$sign${won.format(n)}원';
  }
  return '';
}

class SizeQuoteLine {
  const SizeQuoteLine({
    required this.name,
    this.spec = '',
    this.unit = 'EA',
    this.qty = 1,
    this.unitPrice,
    this.note = '',
    this.kind = kSizeQuoteKindMain,
    this.isProduct = false,
  });

  final String name;
  final String spec;
  final String unit;
  final int qty;
  final int? unitPrice;
  final String note;
  final String kind;
  final bool isProduct;

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
    'isProduct': isProduct,
  };

  factory SizeQuoteLine.fromJson(Map<String, dynamic> json) {
    return SizeQuoteLine(
      name: (json['name'] ?? '').toString(),
      spec: (json['spec'] ?? '').toString(),
      unit: (json['unit'] ?? '').toString(),
      qty: int.tryParse('${json['qty'] ?? 1}') ?? 1,
      unitPrice: int.tryParse(
        '${json['unitPrice'] ?? json['unit_price'] ?? ''}',
      ),
      note: (json['note'] ?? '').toString(),
      kind: normalizeSizeQuoteKind(
        (json['kind'] ?? json['category'] ?? '').toString(),
      ),
      isProduct: json['isProduct'] == true || json['is_product'] == true,
    );
  }

  SizeQuoteLine copyWith({
    String? name,
    String? spec,
    String? unit,
    int? qty,
    int? unitPrice,
    bool clearUnitPrice = false,
    String? note,
    String? kind,
    bool? isProduct,
  }) {
    return SizeQuoteLine(
      name: name ?? this.name,
      spec: spec ?? this.spec,
      unit: unit ?? this.unit,
      qty: qty ?? this.qty,
      unitPrice: clearUnitPrice ? null : (unitPrice ?? this.unitPrice),
      note: note ?? this.note,
      kind: kind ?? this.kind,
      isProduct: isProduct ?? this.isProduct,
    );
  }
}

class SizeQuoteEditEvent {
  const SizeQuoteEditEvent({
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

  factory SizeQuoteEditEvent.fromJson(Map<String, dynamic> json) {
    return SizeQuoteEditEvent(
      at: (json['at'] ?? '').toString(),
      by: (json['by'] ?? '').toString(),
      summary: (json['summary'] ?? '').toString(),
    );
  }
}

class SizeQuotePromoImage {
  const SizeQuotePromoImage({
    required this.id,
    required this.modelId,
    this.title = '',
    required this.storagePath,
    this.sortOrder = 0,
    this.createdBy,
    this.createdAt,
  });

  final String id;
  final String modelId;
  final String title;
  final String storagePath;
  final int sortOrder;
  final String? createdBy;
  final String? createdAt;

  factory SizeQuotePromoImage.fromJson(Map<String, dynamic> json) {
    return SizeQuotePromoImage(
      id: '${json['id'] ?? ''}',
      modelId: '${json['model_id'] ?? json['modelId'] ?? ''}',
      title: '${json['title'] ?? ''}',
      storagePath: '${json['storage_path'] ?? json['storagePath'] ?? ''}',
      sortOrder: (json['sort_order'] as num?)?.toInt() ??
          int.tryParse('${json['sortOrder'] ?? 0}') ??
          0,
      createdBy: (json['created_by'] ?? json['createdBy'])?.toString(),
      createdAt: (json['created_at'] ?? json['createdAt'])?.toString(),
    );
  }

  SizeQuotePromoImage copyWith({
    String? title,
    String? storagePath,
    int? sortOrder,
  }) {
    return SizeQuotePromoImage(
      id: id,
      modelId: modelId,
      title: title ?? this.title,
      storagePath: storagePath ?? this.storagePath,
      sortOrder: sortOrder ?? this.sortOrder,
      createdBy: createdBy,
      createdAt: createdAt,
    );
  }
}

/// 사이즈 표준단가에서 작성하는 영업 견적서.
class SizeQuoteDocument {
  const SizeQuoteDocument({
    required this.id,
    required this.customerName,
    this.phone = '',
    this.email = '',
    this.site = '',
    this.address = '',
    this.workName = '',
    this.quoteNo = '',
    required this.ymd,
    this.categoryId,
    this.categoryName = '',
    this.modelId,
    this.modelName = '',
    this.widthMm = 0,
    this.heightMm = 0,
    this.quantity = 1,
    this.standardPrice = 0,
    this.markupType = kSizeQuoteMarkupNone,
    this.markupValue = 0,
    this.lines = const [],
    this.promoImageIds = const [],
    this.note = '',
    this.createdBy,
    this.createdAt,
    this.updatedBy,
    this.updatedAt,
    this.sentYmd,
    this.emailSentYmd,
    this.negoAmount = 0,
    this.negoPercent = 0,
    this.targetTotal,
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
  final String? categoryId;
  final String categoryName;
  final String? modelId;
  final String modelName;
  final int widthMm;
  final int heightMm;
  final int quantity;
  final int standardPrice;
  final String markupType;
  final num markupValue;
  final List<SizeQuoteLine> lines;
  final List<String> promoImageIds;
  final String note;
  final String? createdBy;
  final String? createdAt;
  final String? updatedBy;
  final String? updatedAt;
  final String? sentYmd;
  final String? emailSentYmd;
  final int negoAmount;
  final double negoPercent;
  final int? targetTotal;
  final List<SizeQuoteEditEvent> editHistory;
  final String? pdfPath;
  final String? pdfUploadedAt;
  final String? pdfUploadedBy;

  static const editHistoryLimit = 40;

  int get sellingUnitPrice => sizeQuoteApplyMarkup(
    standardPrice: standardPrice,
    markupType: markupType,
    markupValue: markupValue,
  );

  String get sizeLabel {
    if (widthMm <= 0 || heightMm <= 0) return '';
    return '$widthMm×$heightMm';
  }

  bool get hasCloudPdf => (pdfPath ?? '').trim().isNotEmpty;

  int get listTotal => lines.fold(0, (sum, e) => sum + e.amount);

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

  int get total => listTotal - negoOff;

  int? get remainingToTarget {
    final target = targetTotal;
    if (target == null || target <= 0) return null;
    return target - total;
  }

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

  String get markupSummary => sizeQuoteMarkupSummary(
    markupType: markupType,
    markupValue: markupValue,
  );

  bool get isSent => (sentYmd ?? '').trim().isNotEmpty;
  bool get isEmailSent => (emailSentYmd ?? '').trim().isNotEmpty;

  bool get wasEdited =>
      (updatedAt ?? '').trim().isNotEmpty &&
      (updatedAt!.trim() != (createdAt ?? '').trim() ||
          ((updatedBy ?? '').trim().isNotEmpty &&
              (updatedBy!.trim() != (createdBy ?? '').trim())));

  List<SizeQuoteLine> linesOfKind(String kind) =>
      lines.where((e) => e.kind == kind).toList();

  SizeQuoteLine? get productLine {
    for (final line in lines) {
      if (line.isProduct) return line;
    }
    return null;
  }

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
    'categoryId': categoryId,
    'categoryName': categoryName,
    'modelId': modelId,
    'modelName': modelName,
    'widthMm': widthMm,
    'heightMm': heightMm,
    'quantity': quantity,
    'standardPrice': standardPrice,
    'markupType': markupType,
    'markupValue': markupValue,
    'lines': lines.map((e) => e.toJson()).toList(),
    'promoImageIds': promoImageIds,
    'note': note,
    'createdBy': createdBy,
    'createdAt': createdAt,
    'updatedBy': updatedBy,
    'updatedAt': updatedAt,
    'sentYmd': sentYmd,
    'emailSentYmd': emailSentYmd,
    'negoAmount': negoAmount,
    'negoPercent': negoPercent,
    'targetTotal': targetTotal,
    'editHistory': editHistory.map((e) => e.toJson()).toList(),
    'pdfPath': pdfPath,
    'pdfUploadedAt': pdfUploadedAt,
    'pdfUploadedBy': pdfUploadedBy,
  };

  factory SizeQuoteDocument.fromJson(Map<String, dynamic> json) {
    final rawLines = json['lines'];
    final rawHistory = json['editHistory'] ?? json['edit_history'];
    final rawPromo = json['promoImageIds'] ?? json['promo_image_ids'];
    String? ymdOf(Object? raw) {
      if (raw == null) return null;
      final s = raw.toString().split('T').first.split(' ').first.trim();
      return s.isEmpty ? null : s;
    }

    return SizeQuoteDocument(
      id: (json['id'] ?? '').toString(),
      customerName: (json['customerName'] ?? json['customer_name'] ?? '')
          .toString(),
      phone: (json['phone'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      site: (json['site'] ?? json['site_name'] ?? '').toString(),
      address: (json['address'] ?? '').toString(),
      workName: (json['workName'] ?? json['work_name'] ?? '').toString(),
      quoteNo: (json['quoteNo'] ?? json['quote_no'] ?? '').toString(),
      ymd: ymdOf(json['ymd'] ?? json['quote_date']) ?? '',
      categoryId: () {
        final raw = json['categoryId'] ?? json['category_id'];
        if (raw == null) return null;
        final s = raw.toString().trim();
        return s.isEmpty ? null : s;
      }(),
      categoryName: (json['categoryName'] ?? json['category_name'] ?? '')
          .toString(),
      modelId: () {
        final raw = json['modelId'] ?? json['model_id'];
        if (raw == null) return null;
        final s = raw.toString().trim();
        return s.isEmpty ? null : s;
      }(),
      modelName: (json['modelName'] ?? json['model_name'] ?? '').toString(),
      widthMm: int.tryParse('${json['widthMm'] ?? json['width_mm'] ?? 0}') ?? 0,
      heightMm:
          int.tryParse('${json['heightMm'] ?? json['height_mm'] ?? 0}') ?? 0,
      quantity: int.tryParse('${json['quantity'] ?? json['qty'] ?? 1}') ?? 1,
      standardPrice:
          int.tryParse(
            '${json['standardPrice'] ?? json['standard_price'] ?? 0}',
          ) ??
          0,
      markupType: normalizeSizeQuoteMarkup(
        (json['markupType'] ?? json['markup_type'] ?? '').toString(),
      ),
      markupValue:
          num.tryParse(
            '${json['markupValue'] ?? json['markup_value'] ?? 0}',
          ) ??
          0,
      lines: rawLines is List
          ? rawLines
                .whereType<Map>()
                .map(
                  (e) => SizeQuoteLine.fromJson(Map<String, dynamic>.from(e)),
                )
                .toList()
          : const [],
      promoImageIds: rawPromo is List
          ? rawPromo.map((e) => e.toString()).where((e) => e.isNotEmpty).toList()
          : const [],
      note: (json['note'] ?? '').toString(),
      createdBy: (json['createdBy'] ?? json['created_by'])?.toString(),
      createdAt: (json['createdAt'] ?? json['created_at'])?.toString(),
      updatedBy: (json['updatedBy'] ?? json['updated_by'])?.toString(),
      updatedAt: (json['updatedAt'] ?? json['updated_at'])?.toString(),
      sentYmd: ymdOf(json['sentYmd'] ?? json['sent_ymd']),
      emailSentYmd: ymdOf(json['emailSentYmd'] ?? json['email_sent_ymd']),
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
      targetTotal: () {
        final raw = json['targetTotal'] ?? json['target_total'];
        if (raw == null || '$raw'.trim().isEmpty) return null;
        return int.tryParse('$raw');
      }(),
      editHistory: rawHistory is List
          ? rawHistory
                .whereType<Map>()
                .map(
                  (e) => SizeQuoteEditEvent.fromJson(
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

  SizeQuoteDocument copyWith({
    String? customerName,
    String? phone,
    String? email,
    String? site,
    String? address,
    String? workName,
    String? quoteNo,
    String? ymd,
    String? categoryId,
    String? categoryName,
    String? modelId,
    String? modelName,
    int? widthMm,
    int? heightMm,
    int? quantity,
    int? standardPrice,
    String? markupType,
    num? markupValue,
    List<SizeQuoteLine>? lines,
    List<String>? promoImageIds,
    String? note,
    String? createdBy,
    String? createdAt,
    String? updatedBy,
    String? updatedAt,
    String? sentYmd,
    bool clearSentYmd = false,
    String? emailSentYmd,
    bool clearEmailSentYmd = false,
    int? negoAmount,
    double? negoPercent,
    int? targetTotal,
    bool clearTargetTotal = false,
    List<SizeQuoteEditEvent>? editHistory,
    String? pdfPath,
    String? pdfUploadedAt,
    String? pdfUploadedBy,
  }) {
    return SizeQuoteDocument(
      id: id,
      customerName: customerName ?? this.customerName,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      site: site ?? this.site,
      address: address ?? this.address,
      workName: workName ?? this.workName,
      quoteNo: quoteNo ?? this.quoteNo,
      ymd: ymd ?? this.ymd,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      modelId: modelId ?? this.modelId,
      modelName: modelName ?? this.modelName,
      widthMm: widthMm ?? this.widthMm,
      heightMm: heightMm ?? this.heightMm,
      quantity: quantity ?? this.quantity,
      standardPrice: standardPrice ?? this.standardPrice,
      markupType: markupType ?? this.markupType,
      markupValue: markupValue ?? this.markupValue,
      lines: lines ?? this.lines,
      promoImageIds: promoImageIds ?? this.promoImageIds,
      note: note ?? this.note,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedBy: updatedBy ?? this.updatedBy,
      updatedAt: updatedAt ?? this.updatedAt,
      sentYmd: clearSentYmd ? null : (sentYmd ?? this.sentYmd),
      emailSentYmd: clearEmailSentYmd
          ? null
          : (emailSentYmd ?? this.emailSentYmd),
      negoAmount: negoAmount ?? this.negoAmount,
      negoPercent: negoPercent ?? this.negoPercent,
      targetTotal: clearTargetTotal ? null : (targetTotal ?? this.targetTotal),
      editHistory: editHistory ?? this.editHistory,
      pdfPath: pdfPath ?? this.pdfPath,
      pdfUploadedAt: pdfUploadedAt ?? this.pdfUploadedAt,
      pdfUploadedBy: pdfUploadedBy ?? this.pdfUploadedBy,
    );
  }
}

class SizeQuoteSeed {
  const SizeQuoteSeed({
    required this.categoryId,
    required this.categoryName,
    required this.modelId,
    required this.modelName,
    required this.widthMm,
    required this.heightMm,
    required this.standardPrice,
  });

  final String categoryId;
  final String categoryName;
  final String modelId;
  final String modelName;
  final int widthMm;
  final int heightMm;
  final int standardPrice;
}

SizeQuoteLine sizeQuoteProductLine({
  required SizeQuoteSeed seed,
  int quantity = 1,
  String markupType = kSizeQuoteMarkupNone,
  num markupValue = 0,
}) {
  final selling = sizeQuoteApplyMarkup(
    standardPrice: seed.standardPrice,
    markupType: markupType,
    markupValue: markupValue,
  );
  final won = NumberFormat('#,###');
  final markup = sizeQuoteMarkupSummary(
    markupType: markupType,
    markupValue: markupValue,
  );
  return SizeQuoteLine(
    name: seed.modelName,
    spec: '${seed.widthMm}×${seed.heightMm}',
    unit: 'SET',
    qty: quantity <= 0 ? 1 : quantity,
    unitPrice: selling,
    kind: kSizeQuoteKindMain,
    isProduct: true,
    note: [
      '표준단가 ${won.format(seed.standardPrice)}원',
      if (markup.isNotEmpty) markup,
    ].join(' '),
  );
}

SizeQuoteDocument sizeQuoteFromSeed({
  required SizeQuoteSeed seed,
  required String ymd,
  String? createdBy,
  String id = '',
}) {
  return SizeQuoteDocument(
    id: id,
    customerName: '',
    ymd: ymd,
    categoryId: seed.categoryId,
    categoryName: seed.categoryName,
    modelId: seed.modelId,
    modelName: seed.modelName,
    widthMm: seed.widthMm,
    heightMm: seed.heightMm,
    quantity: 1,
    standardPrice: seed.standardPrice,
    workName: '${seed.modelName} 설치 공사',
    createdBy: createdBy,
    lines: [sizeQuoteProductLine(seed: seed)],
  );
}

/// 제품 라인의 판매단가·수량·규격을 표준단가+마진과 맞춘다.
List<SizeQuoteLine> sizeQuoteSyncProductLine({
  required List<SizeQuoteLine> lines,
  required SizeQuoteSeed seed,
  required int quantity,
  required String markupType,
  required num markupValue,
}) {
  final product = sizeQuoteProductLine(
    seed: seed,
    quantity: quantity,
    markupType: markupType,
    markupValue: markupValue,
  );
  final next = <SizeQuoteLine>[];
  var replaced = false;
  for (final line in lines) {
    if (line.isProduct && !replaced) {
      next.add(product);
      replaced = true;
    } else {
      next.add(line);
    }
  }
  if (!replaced) next.insert(0, product);
  return next;
}

int sizeQuoteAdjustmentForTarget({
  required int listTotalWithoutFit,
  required int targetTotal,
  required int negoAmount,
  required double negoPercent,
}) {
  if (targetTotal <= 0) return 0;
  if (negoPercent > 0) {
    final factor = 1 - (negoPercent / 100);
    if (factor <= 0) return 0;
    return (targetTotal / factor).round() - listTotalWithoutFit;
  }
  final off = negoAmount < 0 ? 0 : negoAmount;
  return targetTotal + off - listTotalWithoutFit;
}

bool _isFitLine(SizeQuoteLine line) =>
    line.kind == kSizeQuoteKindOther &&
    (line.name.trim() == kSizeQuoteFitLineName ||
        line.note.trim() == 'fit');

List<SizeQuoteLine> sizeQuoteLinesWithoutFit(List<SizeQuoteLine> lines) =>
    lines.where((e) => !_isFitLine(e)).toList();

/// 목표 총액에 맞추기 위해 기타 「금액 조정」 라인을 넣거나 고친다.
SizeQuoteDocument sizeQuoteFitToTarget(SizeQuoteDocument doc, int targetTotal) {
  if (targetTotal <= 0) {
    return doc.copyWith(
      clearTargetTotal: true,
      lines: sizeQuoteLinesWithoutFit(doc.lines),
    );
  }
  final baseLines = sizeQuoteLinesWithoutFit(doc.lines);
  final baseTotal = baseLines.fold(0, (sum, e) => sum + e.amount);
  final adj = sizeQuoteAdjustmentForTarget(
    listTotalWithoutFit: baseTotal,
    targetTotal: targetTotal,
    negoAmount: doc.negoAmount,
    negoPercent: doc.negoPercent,
  );
  if (adj == 0) {
    return doc.copyWith(targetTotal: targetTotal, lines: baseLines);
  }
  return doc.copyWith(
    targetTotal: targetTotal,
    lines: [
      ...baseLines,
      SizeQuoteLine(
        name: kSizeQuoteFitLineName,
        spec: '목표 ${NumberFormat('#,###').format(targetTotal)}원',
        unit: '식',
        qty: 1,
        unitPrice: adj,
        kind: kSizeQuoteKindOther,
        note: 'fit',
      ),
    ],
  );
}

int sizeQuoteSizeDistanceMm({
  required int widthMm,
  required int heightMm,
  required int otherWidthMm,
  required int otherHeightMm,
}) {
  return (widthMm - otherWidthMm).abs() + (heightMm - otherHeightMm).abs();
}

bool sizeQuoteIsSimilarSize({
  required int widthMm,
  required int heightMm,
  required int otherWidthMm,
  required int otherHeightMm,
  int toleranceMm = 500,
}) {
  if (widthMm <= 0 || heightMm <= 0) return false;
  if (otherWidthMm <= 0 || otherHeightMm <= 0) return false;
  return (widthMm - otherWidthMm).abs() <= toleranceMm &&
      (heightMm - otherHeightMm).abs() <= toleranceMm;
}

List<SizeQuoteDocument> sizeQuoteSimilarOf({
  required List<SizeQuoteDocument> all,
  required String modelId,
  required int widthMm,
  required int heightMm,
  String? excludeId,
  int toleranceMm = 500,
  int limit = 20,
}) {
  final id = modelId.trim();
  if (id.isEmpty || widthMm <= 0 || heightMm <= 0) return const [];
  final rows = all
      .where((e) {
        if ((excludeId ?? '').isNotEmpty && e.id == excludeId) return false;
        if ((e.modelId ?? '').trim() != id) return false;
        return sizeQuoteIsSimilarSize(
          widthMm: widthMm,
          heightMm: heightMm,
          otherWidthMm: e.widthMm,
          otherHeightMm: e.heightMm,
          toleranceMm: toleranceMm,
        );
      })
      .toList();
  rows.sort((a, b) {
    final da = sizeQuoteSizeDistanceMm(
      widthMm: widthMm,
      heightMm: heightMm,
      otherWidthMm: a.widthMm,
      otherHeightMm: a.heightMm,
    );
    final db = sizeQuoteSizeDistanceMm(
      widthMm: widthMm,
      heightMm: heightMm,
      otherWidthMm: b.widthMm,
      otherHeightMm: b.heightMm,
    );
    final byDist = da.compareTo(db);
    if (byDist != 0) return byDist;
    return b.ymd.compareTo(a.ymd);
  });
  if (rows.length <= limit) return rows;
  return rows.take(limit).toList();
}

bool sizeQuoteMatches(SizeQuoteDocument doc, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return true;
  final digits = normalizePhoneDigits(query);
  if (digits.length >= 4 && normalizePhoneDigits(doc.phone).contains(digits)) {
    return true;
  }
  final compactDate = q.replaceAll(RegExp(r'[^0-9]'), '');
  final ymdDigits = doc.ymd.replaceAll(RegExp(r'[^0-9]'), '');
  if (compactDate.length >= 4 && ymdDigits.contains(compactDate)) {
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
    doc.emailSentYmd ?? '',
    doc.modelName,
    doc.categoryName,
    doc.sizeLabel,
    doc.createdBy ?? '',
    '${doc.total}',
    if (doc.isSent) '발송',
    if (doc.isEmailSent) '메일',
    if (doc.hasCloudPdf) 'pdf',
    ...doc.lines.map(
      (e) =>
          '${e.name} ${e.spec} ${e.unit} ${e.note} ${sizeQuoteKindLabel(e.kind)}',
    ),
  ].join(' ').toLowerCase();
  return blob.contains(q);
}

String sizeQuoteFileStem(SizeQuoteDocument doc) {
  final raw = doc.site.trim().isNotEmpty
      ? doc.site.trim()
      : (doc.customerName.trim().isEmpty ? '고객' : doc.customerName.trim());
  final safe = raw.replaceAll(RegExp(r'[\\/:*?"<>|\s]+'), '_');
  final model = doc.modelName.trim().replaceAll(RegExp(r'[\\/:*?"<>|\s]+'), '_');
  final day = doc.ymd.trim().isEmpty ? '' : '_${doc.ymd.trim()}';
  final modelPart = model.isEmpty ? '' : '_$model';
  return '견적서_$safe$modelPart$day';
}

String sizeQuoteEmailSubject(SizeQuoteDocument doc) {
  final who = doc.site.trim().isNotEmpty
      ? doc.site.trim()
      : (doc.customerName.trim().isEmpty ? '고객' : doc.customerName.trim());
  return '[COAD 견적서] $who ${doc.modelName} ${doc.ymd}'.trim();
}

String sizeQuoteEmailBody(
  SizeQuoteDocument doc, {
  required String totalLabel,
}) {
  final name = doc.customerName.trim().isEmpty ? '고객' : doc.customerName.trim();
  return [
    '$name 고객님 견적서입니다.',
    if (doc.site.trim().isNotEmpty) '현장: ${doc.site.trim()}',
    if (doc.modelName.trim().isNotEmpty)
      '모델: ${doc.modelName.trim()}${doc.sizeLabel.isEmpty ? '' : ' · ${doc.sizeLabel}'}',
    if (doc.quoteNo.trim().isNotEmpty) '견적번호: ${doc.quoteNo.trim()}',
    '견적일: ${doc.ymd}',
    '합계: $totalLabel',
    '첨부된 견적서를 확인해 주세요.',
  ].join('\n');
}

String sizeQuoteKoreanTotalLabel(int amount) {
  final won = NumberFormat('#,###');
  if (amount <= 0) return '일금 영원정 (0원, VAT. 별도)';
  final words = koreanWonInWords(amount).replaceFirst(RegExp(r'원$'), '');
  return '일금 $words원정 (${won.format(amount)}원, VAT. 별도)';
}

String sizeQuoteSnapshotSummary(SizeQuoteDocument doc) {
  final won = NumberFormat('#,###');
  return [
    if (doc.modelName.trim().isNotEmpty) doc.modelName.trim(),
    if (doc.sizeLabel.isNotEmpty) doc.sizeLabel,
    '품목 ${doc.lines.length}건',
    '합계 ${doc.total <= 0 ? '0' : won.format(doc.total)}원',
    if (doc.hasNego) '네고 ${doc.negoSummary}',
    if (doc.isEmailSent) '메일발송',
    if (doc.isSent) '발송완료',
  ].join(' · ');
}

String sizeQuoteEditDiffSummary(
  SizeQuoteDocument before,
  SizeQuoteDocument after,
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
  if (before.markupType != after.markupType ||
      before.markupValue != after.markupValue) {
    changes.add(
      after.markupSummary.isEmpty
          ? '표준가 그대로'
          : '마진 ${after.markupSummary}',
    );
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
  if ((before.emailSentYmd ?? '') != (after.emailSentYmd ?? '')) {
    changes.add(after.isEmailSent ? '메일 발송' : '메일 미발송');
  }
  if (before.note.trim() != after.note.trim()) {
    changes.add('비고 변경');
  }
  if (changes.isEmpty) {
    changes.add('내용 저장 · ${sizeQuoteSnapshotSummary(after)}');
  }
  return changes.join(' · ');
}

String _sizeQuoteShortWhen(String? iso) {
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

String sizeQuoteAuditLine(SizeQuoteDocument doc) {
  final createdBy = (doc.createdBy ?? '').trim();
  final updatedBy = (doc.updatedBy ?? '').trim();
  final createdAt = _sizeQuoteShortWhen(doc.createdAt);
  final updatedAt = _sizeQuoteShortWhen(doc.updatedAt);
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
  final sent = (doc.sentYmd ?? '').trim();
  final email = (doc.emailSentYmd ?? '').trim();
  return [
    if (created.isNotEmpty) created,
    if (updated.isNotEmpty) updated,
    if (sent.isNotEmpty) '발송 $sent',
    if (email.isNotEmpty) '메일 $email',
    if (doc.hasCloudPdf) '클라우드 PDF',
  ].join(' · ');
}

List<SizeQuoteEditEvent> sizeQuoteAppendEditHistory({
  required List<SizeQuoteEditEvent> previous,
  required String at,
  required String by,
  required String summary,
}) {
  final next = [
    ...previous,
    SizeQuoteEditEvent(
      at: at,
      by: by.trim().isEmpty ? '미상' : by.trim(),
      summary: summary,
    ),
  ];
  if (next.length <= SizeQuoteDocument.editHistoryLimit) return next;
  return next.sublist(next.length - SizeQuoteDocument.editHistoryLimit);
}

class SizeQuoteSiteGroup {
  const SizeQuoteSiteGroup({
    required this.key,
    required this.title,
    required this.items,
  });

  final String key;
  final String title;
  final List<SizeQuoteDocument> items;
}

List<SizeQuoteSiteGroup> sizeQuoteSiteGroups(List<SizeQuoteDocument> items) {
  final map = <String, List<SizeQuoteDocument>>{};
  for (final doc in items) {
    final site = doc.site.trim();
    final key = site.isNotEmpty
        ? site.toLowerCase()
        : (doc.customerName.trim().isEmpty
              ? '(현장 없음)'
              : doc.customerName.trim().toLowerCase());
    map.putIfAbsent(key, () => []).add(doc);
  }
  final groups = map.entries.map((e) {
    final first = e.value.first;
    final title = first.site.trim().isNotEmpty
        ? first.site.trim()
        : (first.customerName.trim().isEmpty ? '(현장 없음)' : first.customerName.trim());
    return SizeQuoteSiteGroup(key: e.key, title: title, items: e.value);
  }).toList();
  groups.sort((a, b) {
    final ay = a.items.isEmpty ? '' : a.items.first.ymd;
    final by = b.items.isEmpty ? '' : b.items.first.ymd;
    return by.compareTo(ay);
  });
  return groups;
}
