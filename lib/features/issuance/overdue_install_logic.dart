import 'dart:convert';

const kOverdueInstallJapanPlantCd = '2002';
const kOverdueInstallMissingAssignee = '(담당자 없음)';

bool overdueInstallLooksLikeEmployeeId(String value) {
  final s = value.trim();
  return s.isNotEmpty && RegExp(r'^\d+$').hasMatch(s);
}

/// 우리 담당자: 앱 users 이름과 맞는 등록자(`reg_usr`)를 우선한다.
String overdueInstallAssigneeKey({
  required String managerNm,
  required String regUsr,
  Iterable<String> ourNames = const [],
}) {
  final reg = regUsr.trim();
  final manager = managerNm.trim();
  final ours = {
    for (final n in ourNames)
      if (n.trim().isNotEmpty) n.trim(),
  };
  if (ours.isNotEmpty) {
    if (ours.contains(reg)) return reg;
    if (ours.contains(manager)) return manager;
  }
  if (reg.isNotEmpty && !overdueInstallLooksLikeEmployeeId(reg)) return reg;
  if (manager.isNotEmpty && !overdueInstallLooksLikeEmployeeId(manager)) {
    return manager;
  }
  if (reg.isNotEmpty) return reg;
  if (manager.isNotEmpty) return manager;
  return kOverdueInstallMissingAssignee;
}

bool overdueInstallIsMine(String assigneeKey, String? userName) {
  final name = (userName ?? '').trim();
  if (name.isEmpty) return false;
  return assigneeKey == name;
}

bool overdueInstallIsJapanPlant(String plantCd) =>
    plantCd.trim() == kOverdueInstallJapanPlantCd;

bool overdueInstallIsOverdue(String instalDt, String todayYmd) {
  final d = instalDt.trim();
  if (d.length < 10 || todayYmd.length < 10) return false;
  return d.substring(0, 10).compareTo(todayYmd.substring(0, 10)) < 0;
}

bool overdueInstallParseDone(dynamic raw) {
  if (raw is bool) return raw;
  if (raw is num) return raw != 0;
  final s = raw?.toString().trim().toLowerCase() ?? '';
  return s == '1' || s == 'true' || s == 't';
}

String overdueInstallYmd(DateTime d) {
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '${d.year}-$m-$day';
}

({String from, String to}) overdueInstallLookbackRange(String todayYmd) {
  final today = DateTime.parse(todayYmd.substring(0, 10));
  final yesterday = today.subtract(const Duration(days: 1));
  return (
    from: overdueInstallYmd(DateTime(today.year - 2, today.month, today.day)),
    to: overdueInstallYmd(yesterday),
  );
}

DateTime overdueInstallMondayOf(DateTime day) {
  return DateTime(
    day.year,
    day.month,
    day.day,
  ).subtract(Duration(days: day.weekday - DateTime.monday));
}

bool overdueInstallInMonth(String ymd, DateTime month) {
  final key = '${month.year}-${month.month.toString().padLeft(2, '0')}';
  return ymd.startsWith(key);
}

bool overdueInstallInWeek(String ymd, DateTime focused) {
  final start = overdueInstallMondayOf(focused);
  final end = start.add(const Duration(days: 6));
  return ymd.compareTo(overdueInstallYmd(start)) >= 0 &&
      ymd.compareTo(overdueInstallYmd(end)) <= 0;
}

int? overdueInstallParseMoney(dynamic raw) {
  if (raw == null) return null;
  if (raw is num) {
    if (raw <= 0) return null;
    return raw.round();
  }
  final s = raw
      .toString()
      .replaceAll(',', '')
      .replaceAll('원', '')
      .replaceAll('₩', '')
      .trim();
  if (s.isEmpty || s == '-') return null;
  final n = double.tryParse(s);
  if (n == null || n <= 0) return null;
  return n.round();
}

Map<dynamic, dynamic>? overdueInstallAsMap(dynamic raw) {
  if (raw is Map) return raw;
  if (raw is String && raw.trim().startsWith('{')) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) return decoded;
    } catch (_) {}
  }
  return null;
}

int? overdueInstallMoneyFromRaw(dynamic raw, List<String> keys) {
  final map = overdueInstallAsMap(raw);
  if (map == null) return null;
  for (final key in keys) {
    final n = overdueInstallParseMoney(map[key]);
    if (n != null) return n;
  }
  return null;
}

int? overdueInstallOrderPriceFromRaw(dynamic raw) {
  return overdueInstallMoneyFromRaw(raw, const [
    'order_price',
    'ORDER_PRICE',
    'AMT',
    'TOT_AMT',
    'ORDER_AMT',
    'SO_AMT',
    'order_price_num',
    'LINE_AMT',
  ]);
}

/// MES 수주금액은 부가세 포함. 세금계산서와 같이 합계÷11 = 세액.
({int supply, int tax, int total})? overdueInstallVatSplit(int? total) {
  if (total == null || total <= 0) return null;
  final tax = total ~/ 11;
  return (supply: total - tax, tax: tax, total: total);
}

/// 나 → 건수 많은 순 → 이름.
List<String> overdueInstallAssigneeOrder(
  Map<String, int> counts,
  String? userName,
) {
  final keys = counts.keys.toList();
  keys.sort((a, b) {
    final aMine = overdueInstallIsMine(a, userName);
    final bMine = overdueInstallIsMine(b, userName);
    if (aMine != bMine) return aMine ? -1 : 1;
    final byCount = (counts[b] ?? 0).compareTo(counts[a] ?? 0);
    if (byCount != 0) return byCount;
    return a.compareTo(b);
  });
  return keys;
}

List<(String, List<T>)> overdueInstallGroupByAssignee<T>(
  List<T> rows, {
  required String Function(T row) assigneeOf,
  required String Function(T row) dateOf,
  String? userName,
}) {
  final by = <String, List<T>>{};
  for (final row in rows) {
    (by[assigneeOf(row)] ??= []).add(row);
  }
  for (final list in by.values) {
    list.sort((a, b) => dateOf(a).compareTo(dateOf(b)));
  }
  final keys = overdueInstallAssigneeOrder({
    for (final e in by.entries) e.key: e.value.length,
  }, userName);
  return [for (final k in keys) (k, by[k]!)];
}

enum OverdueInstallArchiveKind { installAfter, contract, checksheet, other }

OverdueInstallArchiveKind overdueInstallArchiveKind({
  required String typeCode,
  required String stage,
  required String r2Key,
  required String originalName,
}) {
  final blob = '$typeCode|$stage|$r2Key|$originalName'.toUpperCase();
  if (blob.contains('TP4') ||
      blob.contains('계약완료') ||
      blob.contains('계약완') ||
      blob.contains('05_계약') ||
      blob.contains('/05_')) {
    return OverdueInstallArchiveKind.contract;
  }
  if (blob.contains('시공전') ||
      blob.contains('TP2') ||
      blob.contains('TP6') ||
      blob.contains('01_시공전') ||
      blob.contains('02_시공전')) {
    return OverdueInstallArchiveKind.other;
  }
  if (blob.contains('TP3') || blob.contains('시공후')) {
    return OverdueInstallArchiveKind.installAfter;
  }
  if (blob.contains('TP1') || blob.contains('체크시트')) {
    return OverdueInstallArchiveKind.checksheet;
  }
  return OverdueInstallArchiveKind.other;
}

String? overdueInstallItemNameFromCode(String itemCd) {
  final s = itemCd.trim();
  if (s.isEmpty) return null;
  if (s.contains('스피드')) return '스피드도어';
  if (s.contains('오버헤드') || s.contains('오버 헤드')) return '오버헤드도어';
  if (s.contains('차고')) return '차고문';
  if (s.contains('셔터')) return '셔터';
  return null;
}

String? overdueInstallBranchFromPlant({
  required String plantCd,
  required String plantNm,
}) {
  const byCode = <String, String>{
    '1000': '본사',
    '1001': '대전',
    '1002': '대구',
    '1006': '전남',
  };
  final code = plantCd.trim();
  if (byCode.containsKey(code)) return byCode[code];
  final nm = plantNm.trim();
  if (nm.contains('본사')) return '본사';
  if (nm.contains('대전')) return '대전';
  if (nm.contains('대구')) return '대구';
  if (nm.contains('전남')) return '전남';
  return null;
}

int? overdueInstallSuggestedAmount({int? remain, int? orderPrice}) {
  if (remain != null && remain > 0) return remain;
  if (orderPrice != null && orderPrice > 0) return orderPrice;
  return null;
}

String overdueInstallSuggestedItemType({int? remain}) {
  if (remain != null && remain > 0) return '잔금';
  return '선급금';
}

enum OverdueInstallRequestFilter { all, notRequested, requested }

bool overdueInstallMatchesRequestFilter({
  required int taxRequestCount,
  required OverdueInstallRequestFilter filter,
}) {
  return switch (filter) {
    OverdueInstallRequestFilter.all => true,
    OverdueInstallRequestFilter.notRequested => taxRequestCount <= 0,
    OverdueInstallRequestFilter.requested => taxRequestCount > 0,
  };
}

String overdueInstallRequestBadge({required int taxRequestCount}) {
  if (taxRequestCount <= 0) return '미요청';
  return '요청 ${taxRequestCount}건';
}

List<String> overdueInstallUniqueNames(Iterable<String> names) {
  final seen = <String>{};
  final out = <String>[];
  for (final name in names) {
    final n = name.trim();
    if (n.isEmpty) continue;
    if (seen.add(n)) out.add(n);
  }
  return out;
}
