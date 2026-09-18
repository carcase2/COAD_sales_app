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

int? overdueInstallOrderPriceFromRaw(dynamic raw) {
  Map<dynamic, dynamic>? map;
  if (raw is Map) {
    map = raw;
  } else if (raw is String && raw.trim().startsWith('{')) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) map = decoded;
    } catch (_) {}
  }
  if (map == null) return null;
  const keys = [
    'order_price',
    'ORDER_PRICE',
    'AMT',
    'TOT_AMT',
    'ORDER_AMT',
    'SO_AMT',
    'order_price_num',
    'LINE_AMT',
  ];
  for (final key in keys) {
    final n = overdueInstallParseMoney(map[key]);
    if (n != null) return n;
  }
  return null;
}

/// MES 수주금액은 부가세 포함. 세금계산서와 같이 합계÷11 = 세액.
({int supply, int tax, int total})? overdueInstallVatSplit(int? total) {
  if (total == null || total <= 0) return null;
  final tax = total ~/ 11;
  return (supply: total - tax, tax: tax, total: total);
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
