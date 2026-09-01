import 'dart:convert';

import 'package:coad_customer_calls/core/utils/date_seoul.dart';
import 'package:shared_preferences/shared_preferences.dart';

const kSupportUnitPriceKindPart = 'part';
const kSupportUnitPriceKindLabor = 'labor';
const kSupportUnitPriceFilterAll = '전체';
const kSupportUnitPriceFilters = ['전체', 'WMS', 'SPD', 'OHD', '인건비'];
const kSupportUnitPriceUnits = ['SET', 'EA', 'M'];
const kSupportUnitPriceFamilies = ['WMS', 'SPD', 'OHD'];
const kSupportUnitPriceOhdKinds = ['수납형', '산업용', '주택차고문'];

String supportUnitPriceFamily(String productLine) {
  final t = productLine.trim();
  if (t.startsWith('WMS')) return 'WMS';
  if (t.startsWith('SPD')) return 'SPD';
  if (t.startsWith('OHD')) return 'OHD';
  return t.isEmpty ? '미분류' : t;
}

String supportUnitPriceOhdKind(String productLine) {
  final t = productLine.trim();
  if (t.startsWith('OHD-') && t.length > 4) return t.substring(4);
  return '';
}

String encodeSupportUnitPriceProductLine({
  required String family,
  String ohdKind = '',
  bool labor = false,
}) {
  final f = family.trim();
  final kind = ohdKind.trim();
  if (!labor && f == 'OHD' && kind.isNotEmpty) return 'OHD-$kind';
  return f;
}

String normalizeSupportUnitPriceUnit(String raw) {
  switch (raw.trim().toLowerCase()) {
    case 'set':
      return 'SET';
    case 'ea':
      return 'EA';
    case 'm':
    case 'm²':
    case 'm2':
      return 'M';
    default:
      return raw.trim();
  }
}

class SupportUnitPriceItem {
  const SupportUnitPriceItem({
    required this.id,
    required this.name,
    this.spec = '',
    this.price,
    this.competitorPrice,
    this.note = '',
    this.productLine = '',
    this.category = '',
    this.nameEn = '',
    this.unit = '',
    this.kind = kSupportUnitPriceKindPart,
    this.sortOrder = 0,
    this.imageUrl = '',
    this.diagramUrl = '',
    this.updatedAt,
    this.updatedByName = '',
    this.createdByName = '',
  });

  final String id;
  final String name;
  final String spec;
  final int? price;
  final int? competitorPrice;
  final String note;
  final String productLine;
  final String category;
  final String nameEn;
  final String unit;
  final String kind;
  final int sortOrder;
  /// 부품 사진. `assets/...` 또는 https URL.
  final String imageUrl;
  /// 부품 도해. `assets/...` 또는 https URL.
  final String diagramUrl;
  final DateTime? updatedAt;
  final String updatedByName;
  final String createdByName;

  bool get isLabor => kind == kSupportUnitPriceKindLabor;

  String get primaryImageUrl {
    if (imageUrl.trim().isNotEmpty) return imageUrl.trim();
    return diagramUrl.trim();
  }

  List<String> get photoUrls => [
    if (imageUrl.trim().isNotEmpty) imageUrl.trim(),
    if (diagramUrl.trim().isNotEmpty) diagramUrl.trim(),
  ];

  int? get displayCompetitorPrice =>
      competitorPrice ?? parseSupportUnitPriceCompetitorFromNote(note);

  String get displayNote {
    if (competitorPrice != null) return note.trim();
    return stripSupportUnitPriceCompetitorFromNote(note);
  }

  SupportUnitPriceItem copyWith({
    String? id,
    String? name,
    String? spec,
    int? price,
    int? competitorPrice,
    bool clearCompetitorPrice = false,
    String? note,
    bool clearPrice = false,
    String? productLine,
    String? category,
    String? nameEn,
    String? unit,
    String? kind,
    int? sortOrder,
    String? imageUrl,
    String? diagramUrl,
    DateTime? updatedAt,
    String? updatedByName,
    String? createdByName,
  }) {
    return SupportUnitPriceItem(
      id: id ?? this.id,
      name: name ?? this.name,
      spec: spec ?? this.spec,
      price: clearPrice ? null : (price ?? this.price),
      competitorPrice: clearCompetitorPrice
          ? null
          : (competitorPrice ?? this.competitorPrice),
      note: note ?? this.note,
      productLine: productLine ?? this.productLine,
      category: category ?? this.category,
      nameEn: nameEn ?? this.nameEn,
      unit: unit ?? this.unit,
      kind: kind ?? this.kind,
      sortOrder: sortOrder ?? this.sortOrder,
      imageUrl: imageUrl ?? this.imageUrl,
      diagramUrl: diagramUrl ?? this.diagramUrl,
      updatedAt: updatedAt ?? this.updatedAt,
      updatedByName: updatedByName ?? this.updatedByName,
      createdByName: createdByName ?? this.createdByName,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'spec': spec,
    'price': price,
    'competitor_price': competitorPrice,
    'note': note,
    'product_line': productLine,
    'category': category,
    'name_en': nameEn,
    'unit': unit,
    'kind': kind,
    'sort_order': sortOrder,
    'image_url': imageUrl,
    'diagram_url': diagramUrl,
  };

  factory SupportUnitPriceItem.fromJson(Map<String, dynamic> json) {
    return SupportUnitPriceItem(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      spec: (json['spec'] ?? '').toString(),
      price: parseSupportUnitPriceInt(json['price']),
      competitorPrice: parseSupportUnitPriceInt(json['competitor_price']),
      note: (json['note'] ?? '').toString(),
      productLine: (json['product_line'] ?? '').toString(),
      category: (json['category'] ?? '').toString(),
      nameEn: (json['name_en'] ?? '').toString(),
      unit: (json['unit'] ?? '').toString(),
      kind: (json['kind'] ?? kSupportUnitPriceKindPart).toString(),
      sortOrder: parseSupportUnitPriceInt(json['sort_order']) ?? 0,
      imageUrl: (json['image_url'] ?? '').toString(),
      diagramUrl: (json['diagram_url'] ?? '').toString(),
      updatedAt: parseSupabaseTimestampUtc(json['updated_at']),
      updatedByName: (json['updated_by_name'] ?? '').toString(),
      createdByName: (json['created_by_name'] ?? '').toString(),
    );
  }
}

class SupportUnitPriceChangeLog {
  const SupportUnitPriceChangeLog({
    required this.id,
    required this.action,
    required this.itemName,
    required this.summary,
    required this.userName,
    required this.createdAt,
    this.itemId,
    this.oldName,
    this.oldSpec,
    this.oldPrice,
    this.oldNote,
    this.newName,
    this.newSpec,
    this.newPrice,
    this.newNote,
    this.userId = '',
  });

  final String id;
  final String? itemId;
  final String action;
  final String itemName;
  final String summary;
  final String? oldName;
  final String? oldSpec;
  final int? oldPrice;
  final String? oldNote;
  final String? newName;
  final String? newSpec;
  final int? newPrice;
  final String? newNote;
  final String userId;
  final String userName;
  final DateTime createdAt;

  factory SupportUnitPriceChangeLog.fromJson(Map<String, dynamic> json) {
    return SupportUnitPriceChangeLog(
      id: (json['id'] ?? '').toString(),
      itemId: (json['item_id'] ?? '').toString().trim().isEmpty
          ? null
          : (json['item_id'] ?? '').toString(),
      action: (json['action'] ?? 'update').toString(),
      itemName: (json['item_name'] ?? '').toString(),
      summary: (json['summary'] ?? '').toString(),
      oldName: _nullableJsonString(json['old_name']),
      oldSpec: _nullableJsonString(json['old_spec']),
      oldPrice: parseSupportUnitPriceInt(json['old_price']),
      oldNote: _nullableJsonString(json['old_note']),
      newName: _nullableJsonString(json['new_name']),
      newSpec: _nullableJsonString(json['new_spec']),
      newPrice: parseSupportUnitPriceInt(json['new_price']),
      newNote: _nullableJsonString(json['new_note']),
      userId: (json['user_id'] ?? '').toString(),
      userName: (json['user_name'] ?? '').toString(),
      createdAt:
          parseSupabaseTimestampUtc(json['created_at']) ?? DateTime.now(),
    );
  }
}

String? _nullableJsonString(Object? value) {
  if (value == null) return null;
  return value.toString();
}

int? parseSupportUnitPriceInt(Object? value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.round();
  final text = value.toString().replaceAll(',', '').trim();
  if (text.isEmpty) return null;
  return int.tryParse(text);
}

final _competitorNoteRe = RegExp(r'타사\s*([0-9,]+)\s*원');

int? parseSupportUnitPriceCompetitorFromNote(String note) {
  final match = _competitorNoteRe.firstMatch(note);
  if (match == null) return null;
  return parseSupportUnitPriceInt(match.group(1));
}

String stripSupportUnitPriceCompetitorFromNote(String note) {
  var text = note.replaceAll(_competitorNoteRe, '');
  text = text.replaceAll(RegExp(r'\s*·\s*·\s*'), ' · ');
  text = text.replaceAll(RegExp(r'(^\s*·\s*)|(\s*·\s*$)'), '');
  return text.trim();
}

String formatSupportUnitPriceCompetitor(int? price) {
  if (price == null) return '';
  return '타사 ${formatSupportUnitPriceWon(price)}';
}

class SupportUnitPriceSection {
  const SupportUnitPriceSection({
    required this.id,
    required this.productLine,
    required this.category,
    this.sortOrder = 0,
  });

  final String id;
  final String productLine;
  final String category;
  final int sortOrder;

  factory SupportUnitPriceSection.fromJson(Map<String, dynamic> json) {
    return SupportUnitPriceSection(
      id: (json['id'] ?? '').toString(),
      productLine: (json['product_line'] ?? '').toString(),
      category: (json['category'] ?? '').toString(),
      sortOrder: parseSupportUnitPriceInt(json['sort_order']) ?? 0,
    );
  }
}

class SupportUnitPriceGroupedSection {
  const SupportUnitPriceGroupedSection({
    required this.productLine,
    required this.category,
    required this.items,
  });

  final String productLine;
  final String category;
  final List<SupportUnitPriceItem> items;
}

String supportUnitPriceLineLabel(String line) {
  final t = line.trim();
  return t.isEmpty ? '미분류' : t;
}

String supportUnitPriceCategoryLabel(String category) {
  final t = category.trim();
  return t.isEmpty ? '기타' : t;
}

/// 목록 2단계 헤더. 인건비는 구분(spec), 부품은 기종·작은분류.
String supportUnitPriceGroupCategory(SupportUnitPriceItem item) {
  if (item.isLabor) {
    final spec = item.spec.trim();
    return spec.isEmpty ? '인건비' : spec;
  }
  final ohd = supportUnitPriceOhdKind(item.productLine);
  final cat = item.category.trim();
  if (ohd.isNotEmpty && cat.isNotEmpty) return '$ohd · $cat';
  if (ohd.isNotEmpty) return ohd;
  return cat.isEmpty ? '기타' : cat;
}

String supportUnitPriceRowTitle(SupportUnitPriceItem item) {
  return item.name.trim();
}

List<String> supportUnitPriceLaborWorkTypes(List<SupportUnitPriceItem> items) {
  final seen = <String>{};
  final out = <String>[];
  for (final item in items) {
    if (!item.isLabor) continue;
    final work = item.name.trim();
    if (work.isEmpty || seen.contains(work)) continue;
    seen.add(work);
    out.add(work);
  }
  out.sort();
  return out;
}

List<String> supportUnitPriceLaborSpecs(
  List<SupportUnitPriceItem> items, {
  String? workType,
}) {
  final seen = <String>{};
  final out = <String>[];
  final work = (workType ?? '').trim();
  for (final item in items) {
    if (!item.isLabor) continue;
    if (work.isNotEmpty && item.name.trim() != work) continue;
    final spec = item.spec.trim();
    if (spec.isEmpty || seen.contains(spec)) continue;
    seen.add(spec);
    out.add(spec);
  }
  out.sort();
  return out;
}

List<SupportUnitPriceGroupedSection> groupSupportUnitPrices(
  List<SupportUnitPriceItem> items,
) {
  final keys = <String>[];
  final map = <String, List<SupportUnitPriceItem>>{};
  for (final item in items) {
    final key = '${item.productLine}\u0001${item.category}';
    if (!map.containsKey(key)) keys.add(key);
    map.putIfAbsent(key, () => []).add(item);
  }
  return [
    for (final key in keys)
      SupportUnitPriceGroupedSection(
        productLine: key.split('\u0001').first,
        category: key.split('\u0001').length > 1 ? key.split('\u0001')[1] : '',
        items: map[key]!,
      ),
  ];
}

List<String> supportUnitPriceDistinctLines({
  required List<SupportUnitPriceItem> items,
  List<SupportUnitPriceSection> sections = const [],
}) {
  final seen = <String>{};
  final out = <String>[];
  void add(String raw) {
    final line = raw.trim();
    if (line.isEmpty || seen.contains(line)) return;
    seen.add(line);
    out.add(line);
  }

  for (final s in sections) {
    add(s.productLine);
  }
  for (final item in items) {
    add(item.productLine);
  }
  const preferred = ['WMS', 'SPD', 'OHD'];
  out.sort((a, b) {
    final ai = preferred.indexWhere((p) => a == p || a.startsWith('$p-'));
    final bi = preferred.indexWhere((p) => b == p || b.startsWith('$p-'));
    final av = ai < 0 ? 99 : ai;
    final bv = bi < 0 ? 99 : bi;
    if (av != bv) return av.compareTo(bv);
    return a.compareTo(b);
  });
  return out;
}

List<String> supportUnitPriceDistinctCategories({
  required List<SupportUnitPriceItem> items,
  List<SupportUnitPriceSection> sections = const [],
  String? productLine,
}) {
  final seen = <String>{};
  final out = <String>[];
  void add(String line, String raw) {
    if (productLine != null &&
        productLine.trim().isNotEmpty &&
        line.trim() != productLine.trim()) {
      return;
    }
    final cat = raw.trim();
    if (cat.isEmpty || seen.contains(cat)) return;
    seen.add(cat);
    out.add(cat);
  }

  for (final s in sections) {
    add(s.productLine, s.category);
  }
  for (final item in items) {
    add(item.productLine, item.category);
  }
  out.sort();
  return out;
}

String supportUnitPriceListSubtitle(SupportUnitPriceItem item) {
  if (item.displayCompetitorPrice == null) return '';
  return formatSupportUnitPriceCompetitor(item.displayCompetitorPrice);
}

String supportUnitPriceInsertLine(SupportUnitPriceItem item) {
  return [
    supportUnitPriceFamily(item.productLine),
    if (item.isLabor) ...[
      if (item.spec.trim().isNotEmpty) item.spec.trim(),
      if (item.name.trim().isNotEmpty) item.name.trim(),
    ] else ...[
      if (item.category.trim().isNotEmpty) item.category.trim(),
      item.name.trim(),
    ],
    if (!item.isLabor && item.unit.trim().isNotEmpty) item.unit.trim(),
    formatSupportUnitPriceWon(item.price),
    if (item.displayCompetitorPrice != null)
      formatSupportUnitPriceCompetitor(item.displayCompetitorPrice),
  ].where((e) => e.trim().isNotEmpty).join(' · ');
}

String formatSupportUnitPriceWon(int? price) {
  if (price == null) return '-';
  final digits = price.abs().toString();
  final buf = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buf.write(',');
    buf.write(digits[i]);
  }
  return '${price < 0 ? '-' : ''}$buf원';
}

/// 85,000원 → 90,000원이면 `5,000원 인상`.
String describeSupportUnitPriceDelta(int? oldPrice, int? newPrice) {
  if (oldPrice == newPrice) return '차이 없음';
  final delta = (newPrice ?? 0) - (oldPrice ?? 0);
  if (delta == 0) return '차이 없음';
  final amount = formatSupportUnitPriceWon(delta.abs());
  return delta > 0 ? '$amount 인상' : '$amount 인하';
}

String formatSupportUnitPriceFromTo(int? oldPrice, int? newPrice) {
  final from = formatSupportUnitPriceWon(oldPrice);
  final to = formatSupportUnitPriceWon(newPrice);
  if (oldPrice == newPrice) return from;
  final delta = describeSupportUnitPriceDelta(oldPrice, newPrice);
  if (delta == '차이 없음') return '$from → $to';
  return '$from → $to ($delta)';
}

String describeSupportUnitPriceSaveConfirm({
  required String name,
  required bool isNew,
  int? oldPrice,
  int? newPrice,
}) {
  final label = name.trim().isEmpty ? '이 단가' : name.trim();
  if (isNew) {
    return '$label을(를) ${formatSupportUnitPriceWon(newPrice)}으로 추가할까요?';
  }
  if (oldPrice == newPrice) {
    return '$label을(를) 저장할까요?';
  }
  return '$label 단가를 ${formatSupportUnitPriceWon(oldPrice)}에서 ${formatSupportUnitPriceWon(newPrice)}으로\n${describeSupportUnitPriceDelta(oldPrice, newPrice)}하여 저장할까요?';
}

String supportUnitPriceActionLabel(String action) {
  return switch (action) {
    'create' => '추가',
    'delete' => '삭제',
    _ => '수정',
  };
}

bool supportUnitPriceMatches(SupportUnitPriceItem item, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return true;
  final blob = [
    item.name,
    item.nameEn,
    item.spec,
    item.note,
    item.productLine,
    item.category,
    item.unit,
    item.isLabor ? '인건비' : '부품',
    if (item.price != null) '${item.price}',
    if (item.price != null) formatSupportUnitPriceWon(item.price),
    if (item.displayCompetitorPrice != null)
      formatSupportUnitPriceCompetitor(item.displayCompetitorPrice),
    item.displayNote,
    item.updatedByName,
  ].join(' ').toLowerCase();
  return blob.contains(q);
}

bool supportUnitPriceInFilter(SupportUnitPriceItem item, String filter) {
  switch (filter) {
    case '인건비':
      return item.isLabor;
    case 'WMS':
      return item.productLine.startsWith('WMS');
    case 'SPD':
      return item.productLine.startsWith('SPD');
    case 'OHD':
      return item.productLine.startsWith('OHD');
    default:
      return true;
  }
}

String supportUnitPriceSectionOf(SupportUnitPriceItem item) {
  return [
    supportUnitPriceFamily(item.productLine),
    supportUnitPriceGroupCategory(item),
  ].join(' · ');
}

String supportUnitPriceSubtitle(SupportUnitPriceItem item) {
  return [
    if (item.productLine.trim().isNotEmpty) item.productLine.trim(),
    if (item.category.trim().isNotEmpty) item.category.trim(),
    if (item.nameEn.trim().isNotEmpty) item.nameEn.trim(),
    if (item.unit.trim().isNotEmpty) item.unit.trim(),
    if (item.spec.trim().isNotEmpty) item.spec.trim(),
    if (item.note.trim().isNotEmpty) item.note.trim(),
  ].join(' · ');
}

String supportUnitPriceDetailLine(SupportUnitPriceItem item) {
  return [
    if (item.nameEn.trim().isNotEmpty) item.nameEn.trim(),
    if (item.unit.trim().isNotEmpty) item.unit.trim(),
    if (item.spec.trim().isNotEmpty) item.spec.trim(),
    if (item.note.trim().isNotEmpty) item.note.trim(),
  ].join(' · ');
}

int _familyRank(String family) {
  final i = kSupportUnitPriceFamilies.indexOf(family);
  return i < 0 ? 99 : i;
}

int compareSupportUnitPriceItems(
  SupportUnitPriceItem a,
  SupportUnitPriceItem b,
) {
  final byFamily = _familyRank(supportUnitPriceFamily(a.productLine)).compareTo(
    _familyRank(supportUnitPriceFamily(b.productLine)),
  );
  if (byFamily != 0) return byFamily;
  final byKind = (a.isLabor ? 1 : 0).compareTo(b.isLabor ? 1 : 0);
  if (byKind != 0) return byKind;
  final byDiv = supportUnitPriceGroupCategory(
    a,
  ).compareTo(supportUnitPriceGroupCategory(b));
  if (byDiv != 0) return byDiv;
  final byOrder = a.sortOrder.compareTo(b.sortOrder);
  if (byOrder != 0) return byOrder;
  return a.name.compareTo(b.name);
}

bool supportUnitPriceChangeLogMatches(
  SupportUnitPriceChangeLog log,
  String query,
) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return true;
  final blob = [
    log.itemName,
    log.summary,
    log.userName,
    supportUnitPriceActionLabel(log.action),
    log.oldName,
    log.oldSpec,
    log.oldNote,
    log.newName,
    log.newSpec,
    log.newNote,
    if (log.oldPrice != null) '${log.oldPrice}',
    if (log.newPrice != null) '${log.newPrice}',
    if (log.oldPrice != null) formatSupportUnitPriceWon(log.oldPrice),
    if (log.newPrice != null) formatSupportUnitPriceWon(log.newPrice),
    if (log.action == 'update' && log.oldPrice != log.newPrice)
      describeSupportUnitPriceDelta(log.oldPrice, log.newPrice),
  ].join(' ').toLowerCase();
  return blob.contains(q);
}

String supportUnitPriceChangeLogTitle(SupportUnitPriceChangeLog log) {
  final name = log.itemName.trim();
  if (name.isNotEmpty) return name;
  final fallback = (log.newName ?? log.oldName ?? '').trim();
  if (fallback.isNotEmpty) return fallback;
  return supportUnitPriceActionLabel(log.action);
}

String supportUnitPriceChangeLogPriceLine(SupportUnitPriceChangeLog log) {
  switch (log.action) {
    case 'create':
      return '추가 · ${formatSupportUnitPriceWon(log.newPrice)}';
    case 'delete':
      return '삭제 · ${formatSupportUnitPriceWon(log.oldPrice)}';
    default:
      if (log.oldPrice != log.newPrice) {
        return formatSupportUnitPriceFromTo(log.oldPrice, log.newPrice);
      }
      return '단가 ${formatSupportUnitPriceWon(log.newPrice ?? log.oldPrice)}';
  }
}

String describeSupportUnitPriceChange({
  required String action,
  String? oldName,
  String? oldSpec,
  int? oldPrice,
  String? oldNote,
  String? newName,
  String? newSpec,
  int? newPrice,
  String? newNote,
  String? oldUnit,
  String? newUnit,
  int? oldCompetitorPrice,
  int? newCompetitorPrice,
  String? oldProductLine,
  String? newProductLine,
  String? oldCategory,
  String? newCategory,
}) {
  final name = (newName ?? oldName ?? '').trim();
  if (action == 'create') {
    return [
      if ((newProductLine ?? '').trim().isNotEmpty) newProductLine!.trim(),
      if ((newCategory ?? '').trim().isNotEmpty) newCategory!.trim(),
      if (name.isNotEmpty) name,
      '추가',
      if ((newUnit ?? '').trim().isNotEmpty) newUnit!.trim(),
      if ((newSpec ?? '').trim().isNotEmpty) newSpec!.trim(),
      formatSupportUnitPriceWon(newPrice),
      if (newCompetitorPrice != null)
        formatSupportUnitPriceCompetitor(newCompetitorPrice),
    ].join(' · ');
  }
  if (action == 'delete') {
    return [
      if (name.isNotEmpty) name,
      '삭제',
      if ((oldSpec ?? '').trim().isNotEmpty) oldSpec!.trim(),
      formatSupportUnitPriceWon(oldPrice),
    ].join(' · ');
  }
  final diffs = <String>[];
  if ((oldProductLine ?? '').trim() != (newProductLine ?? '').trim()) {
    diffs.add(
      '큰분류 ${supportUnitPriceLineLabel(oldProductLine ?? '')} → ${supportUnitPriceLineLabel(newProductLine ?? '')}',
    );
  }
  if ((oldCategory ?? '').trim() != (newCategory ?? '').trim()) {
    diffs.add(
      '작은분류 ${supportUnitPriceCategoryLabel(oldCategory ?? '')} → ${supportUnitPriceCategoryLabel(newCategory ?? '')}',
    );
  }
  if ((oldName ?? '').trim() != (newName ?? '').trim()) {
    diffs.add(
      '품명 ${(oldName ?? '').trim().isEmpty ? '-' : oldName!.trim()} → ${(newName ?? '').trim().isEmpty ? '-' : newName!.trim()}',
    );
  }
  if ((oldUnit ?? '').trim() != (newUnit ?? '').trim()) {
    diffs.add(
      '단위 ${(oldUnit ?? '').trim().isEmpty ? '-' : oldUnit!.trim()} → ${(newUnit ?? '').trim().isEmpty ? '-' : newUnit!.trim()}',
    );
  }
  if ((oldSpec ?? '').trim() != (newSpec ?? '').trim()) {
    diffs.add(
      '규격 ${(oldSpec ?? '').trim().isEmpty ? '-' : oldSpec!.trim()} → ${(newSpec ?? '').trim().isEmpty ? '-' : newSpec!.trim()}',
    );
  }
  if (oldPrice != newPrice) {
    diffs.add('단가 ${formatSupportUnitPriceFromTo(oldPrice, newPrice)}');
  }
  if (oldCompetitorPrice != newCompetitorPrice) {
    diffs.add(
      '타사 ${formatSupportUnitPriceFromTo(oldCompetitorPrice, newCompetitorPrice)}',
    );
  }
  if ((oldNote ?? '').trim() != (newNote ?? '').trim()) {
    diffs.add(
      '비고 ${(oldNote ?? '').trim().isEmpty ? '-' : oldNote!.trim()} → ${(newNote ?? '').trim().isEmpty ? '-' : newNote!.trim()}',
    );
  }
  if (diffs.isEmpty) {
    return [if (name.isNotEmpty) name, '변경 없음'].join(' · ');
  }
  return [if (name.isNotEmpty) name, ...diffs].join(' · ');
}

const _prefsKey = 'support_as_unit_prices_v1';
const kSupportUnitPriceMigratedPrefKey = 'support_as_unit_prices_migrated_v1';

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
