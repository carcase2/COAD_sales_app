/// 계약서 작성 요청 (영업 → 총무). COAD_home `contractRequestModel.ts` 와 같은 규칙.
library;

const contractSendMethods = ['메일', '직접발송'];
const contractListFilters = ['요청', '완료', '취소', '전체'];

class ContractFields {
  ContractFields({
    this.siteName = '',
    this.siteAddress = '',
    this.items = '',
    this.periodStart,
    this.periodEnd,
    this.supplyAmount,
    this.advanceRate,
    this.progressRate,
    this.advancePayWhen = '',
    this.progressPayWhen = '',
    this.advanceBond = false,
    this.performanceBond = false,
    this.defectBond = false,
    this.warranty = '',
    this.sendMethod = '메일',
    this.mailTo = '',
    this.withBankbook = false,
    this.note = '',
  });

  String siteName;
  String siteAddress;
  String items;

  /// yyyy-MM-dd
  String? periodStart;
  String? periodEnd;

  /// 공급가 (원)
  int? supplyAmount;
  int? advanceRate;
  int? progressRate;
  String advancePayWhen;
  String progressPayWhen;
  bool advanceBond;
  bool performanceBond;
  bool defectBond;
  String warranty;
  String sendMethod;
  String mailTo;
  bool withBankbook;
  String note;

  ContractFields copy() => ContractFields(
    siteName: siteName,
    siteAddress: siteAddress,
    items: items,
    periodStart: periodStart,
    periodEnd: periodEnd,
    supplyAmount: supplyAmount,
    advanceRate: advanceRate,
    progressRate: progressRate,
    advancePayWhen: advancePayWhen,
    progressPayWhen: progressPayWhen,
    advanceBond: advanceBond,
    performanceBond: performanceBond,
    defectBond: defectBond,
    warranty: warranty,
    sendMethod: sendMethod,
    mailTo: mailTo,
    withBankbook: withBankbook,
    note: note,
  );

  Map<String, dynamic> toJson() => {
    'site_name': siteName.trim(),
    'site_address': siteAddress.trim(),
    'items': items.trim(),
    'period_start': periodStart,
    'period_end': periodEnd,
    'supply_amount': supplyAmount,
    'advance_rate': advanceRate,
    'progress_rate': progressRate,
    'advance_pay_when': advancePayWhen.trim(),
    'progress_pay_when': progressPayWhen.trim(),
    'advance_bond': advanceBond,
    'performance_bond': performanceBond,
    'defect_bond': defectBond,
    'warranty': warranty.trim(),
    'send_method': sendMethod,
    'mail_to': sendMethod == '메일' ? mailTo.trim() : '',
    'with_bankbook': withBankbook,
    'note': note.trim(),
  };

  static int? _int(dynamic v) {
    if (v == null || v == '') return null;
    if (v is num) return v.toInt();
    return int.tryParse('$v');
  }

  static String? _date(dynamic v) {
    final s = '${v ?? ''}'.trim();
    return s.length >= 10 ? s.substring(0, 10) : null;
  }

  static void fillFromJson(ContractFields f, Map<String, dynamic> j) {
    f
      ..siteName = '${j['site_name'] ?? ''}'
      ..siteAddress = '${j['site_address'] ?? ''}'
      ..items = '${j['items'] ?? ''}'
      ..periodStart = _date(j['period_start'])
      ..periodEnd = _date(j['period_end'])
      ..supplyAmount = _int(j['supply_amount'])
      ..advanceRate = _int(j['advance_rate'])
      ..progressRate = _int(j['progress_rate'])
      ..advancePayWhen = '${j['advance_pay_when'] ?? ''}'
      ..progressPayWhen = '${j['progress_pay_when'] ?? ''}'
      ..advanceBond = j['advance_bond'] == true
      ..performanceBond = j['performance_bond'] == true
      ..defectBond = j['defect_bond'] == true
      ..warranty = '${j['warranty'] ?? ''}'
      ..sendMethod = contractSendMethods.contains(j['send_method'])
          ? '${j['send_method']}'
          : '메일'
      ..mailTo = '${j['mail_to'] ?? ''}'
      ..withBankbook = j['with_bankbook'] == true
      ..note = '${j['note'] ?? ''}';
  }
}

class ContractRequest extends ContractFields {
  ContractRequest({
    required this.id,
    required this.seq,
    required this.requesterUserId,
    required this.requesterName,
    required this.status,
    required this.handledBy,
    required this.handledAt,
    required this.handledNote,
    required this.createdAt,
  });

  final String id;
  final int seq;
  final String requesterUserId;
  final String requesterName;

  /// 요청 / 완료 / 취소
  final String status;
  final String handledBy;
  final DateTime? handledAt;
  final String handledNote;
  final DateTime? createdAt;

  String get requestNo => 'C-${seq.toString().padLeft(4, '0')}';

  factory ContractRequest.fromJson(Map<String, dynamic> j) {
    final r = ContractRequest(
      id: '${j['id'] ?? ''}',
      seq: ContractFields._int(j['seq']) ?? 0,
      requesterUserId: '${j['requester_user_id'] ?? ''}',
      requesterName: '${j['requester_name'] ?? ''}',
      status: '${j['status'] ?? '요청'}',
      handledBy: '${j['handled_by'] ?? ''}',
      handledAt: DateTime.tryParse('${j['handled_at'] ?? ''}')?.toLocal(),
      handledNote: '${j['handled_note'] ?? ''}',
      createdAt: DateTime.tryParse('${j['created_at'] ?? ''}')?.toLocal(),
    );
    ContractFields.fillFromJson(r, j);
    return r;
  }

  bool matches(String filter, String query) {
    if (filter != '전체' && status != filter) return false;
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return [siteName, siteAddress, items, requesterName, requestNo, note]
        .join(' ')
        .toLowerCase()
        .contains(q);
  }
}

final _dateRe = RegExp(r'^\d{4}-\d{2}-\d{2}$');
final _emailRe = RegExp(r'^[^\s@,;]+@[^\s@,;]+\.[^\s@,;]+$');

/// 서버와 같은 입력 검사. 문제가 없으면 null.
String? validateContractFields(ContractFields f) {
  final site = f.siteName.trim();
  if (site.isEmpty) return '현장명을 입력해 주세요.';
  if (site.length > 120) return '현장명은 120자까지 입력할 수 있습니다.';
  final s = f.periodStart ?? '';
  final e = f.periodEnd ?? '';
  if ((s.isNotEmpty && !_dateRe.hasMatch(s)) ||
      (e.isNotEmpty && !_dateRe.hasMatch(e))) {
    return '공사기간 날짜 형식을 확인해 주세요.';
  }
  if (s.isNotEmpty && e.isNotEmpty && s.compareTo(e) > 0) {
    return '공사기간 시작일이 종료일보다 늦습니다.';
  }
  if ((f.supplyAmount ?? 0) < 0) return '계약금액(공급가)을 숫자로 입력해 주세요.';
  bool badRate(int? r) => r != null && (r < 0 || r > 100);
  if (badRate(f.advanceRate) || badRate(f.progressRate)) {
    return '선급금·기성금 비율은 0~100 사이 정수로 입력해 주세요.';
  }
  if (f.advanceRate != null &&
      f.progressRate != null &&
      f.advanceRate! + f.progressRate! > 100) {
    return '선급금과 기성금 비율의 합이 100%를 넘습니다.';
  }
  if (!contractSendMethods.contains(f.sendMethod)) {
    return '보내는 방법(메일/직접발송)을 골라 주세요.';
  }
  if (f.sendMethod == '메일') {
    final bad = f.mailTo
        .split(RegExp(r'[,;\s]+'))
        .where((m) => m.isNotEmpty && !_emailRe.hasMatch(m))
        .toList();
    if (bad.isNotEmpty) return '받는 사람 이메일 주소를 확인해 주세요: ${bad.join(', ')}';
  }
  return null;
}

String _comma(int n) => n.toString().replaceAllMapped(
  RegExp(r'(\d)(?=(\d{3})+$)'),
  (m) => '${m[1]},',
);

String formatWon(int? n) {
  if (n == null) return '';
  if (n >= 10000 && n % 10000 == 0) return '${_comma(n ~/ 10000)}만원';
  return '${_comma(n)}원';
}

String _shortDate(String? d) {
  if (d == null || d.length < 10) return '';
  return '${d.substring(2, 4)}/${int.parse(d.substring(5, 7))}/${int.parse(d.substring(8, 10))}';
}

String contractPeriodText(ContractFields r) {
  if (r.periodStart == null && r.periodEnd == null) return '';
  return '${_shortDate(r.periodStart)}-${_shortDate(r.periodEnd)}';
}

String _ox(bool b) => b ? 'O' : 'x';

/// 단톡방 등에 그대로 붙여 넣을 수 있는 기존 양식 글.
String contractRequestText(ContractFields r) {
  final lines = <String>[
    '[계약서 작성 요청]',
    '',
    '*현장명: ${r.siteName}',
    '*공사장소: ${r.siteAddress}',
    '*품목/ 수량: ${r.items}',
    '*공사기간: ${contractPeriodText(r)}',
    '*계약금액: 공급가 ${formatWon(r.supplyAmount)}',
    '*선급금 ${r.advanceRate ?? ''}%',
    '*기성금 ${r.progressRate ?? ''}%',
    '선급금지급시기: ${r.advancePayWhen}',
    '기성금지급시기: ${r.progressPayWhen}',
    '*선급금 증권 여부${_ox(r.advanceBond)}',
    '*계약이행보증금 여부${_ox(r.performanceBond)}',
    '*하자보증금 여부${_ox(r.defectBond)}',
    '*무상보증기간 ${r.warranty}',
    '*보내는 방법: ${r.sendMethod}${r.sendMethod == '메일' && r.mailTo.isNotEmpty ? ' (${r.mailTo})' : ''}',
  ];
  if (r.withBankbook) lines.add('*통장사본 함께 보내기');
  if (r.note.isNotEmpty) lines.addAll(['', r.note]);
  return lines.join('\n');
}

/* ---------- 기존 단톡방 양식 글을 붙여 넣으면 칸을 채운다 ---------- */

/// '26/12/1', '26.11.26', '2026-12-01' → '2026-12-01'
String? parseLooseDate(String s) {
  final m = RegExp(
    r'^(\d{2}|\d{4})\s*[./-]\s*(\d{1,2})\s*[./-]\s*(\d{1,2})$',
  ).firstMatch(s.trim());
  if (m == null) return null;
  final y = m[1]!.length == 2 ? 2000 + int.parse(m[1]!) : int.parse(m[1]!);
  final mo = int.parse(m[2]!);
  final d = int.parse(m[3]!);
  if (mo < 1 || mo > 12 || d < 1 || d > 31) return null;
  return '$y-${mo.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')}';
}

/// '550만원', '5,500,000원', '1억 2천만원' → 원 단위
int? parseWon(String s) {
  final t = s.replaceAll(RegExp(r'[,\s]'), '').replaceAll(RegExp(r'원$'), '');
  if (t.isEmpty) return null;
  if (RegExp(r'^\d+$').hasMatch(t)) return int.parse(t);
  if (!RegExp(r'^[\d.억천백십만]+$').hasMatch(t)) return null;

  double? small(String x) {
    if (x.isEmpty) return 0;
    double sum = 0;
    var rest = x;
    for (final (unit, mul) in const [('천', 1000), ('백', 100), ('십', 10)]) {
      final m = RegExp('^(\\d+(?:\\.\\d+)?)?$unit').firstMatch(rest);
      if (m != null) {
        sum += double.parse(m[1] ?? '1') * mul;
        rest = rest.substring(m[0]!.length);
      }
    }
    if (rest.isNotEmpty && !RegExp(r'^\d+(?:\.\d+)?$').hasMatch(rest)) {
      return null;
    }
    return sum + (rest.isEmpty ? 0 : double.parse(rest));
  }

  final hasEok = t.contains('억');
  final parts = hasEok ? t.split('억') : ['', t];
  final eok = parts[0].isNotEmpty ? small(parts[0]) : 0.0;
  final after = parts.length > 1 ? parts[1] : '';
  double? below;
  if (after.endsWith('만')) {
    final man = small(after.substring(0, after.length - 1));
    below = man == null ? null : man * 10000;
  } else if (after.contains('만')) {
    final i = after.indexOf('만');
    final man = small(after.substring(0, i));
    final won = small(after.substring(i + 1));
    below = man == null || won == null ? null : man * 10000 + won;
  } else {
    below = small(after);
  }
  if (eok == null || below == null) return null;
  final total = eok * 100000000 + below;
  return total > 0 ? total.round() : null;
}

bool? _parseYesNo(String s) {
  final t = s.replaceAll(RegExp(r'[:\s]'), '').toLowerCase();
  if (RegExp(r'^(o|ㅇ|유|있음|yes|y|필요)$').hasMatch(t)) return true;
  if (RegExp(r'^(x|ㄴ|무|없음|no|n|불필요|-)$').hasMatch(t)) return false;
  return null;
}

/// 단톡방 '[계약서 작성 요청]' 글에서 아는 칸만 채운다. 읽은 칸 수를 돌려준다.
/// 못 읽은 줄은 메모로 남긴다.
int applyContractRequestText(ContractFields out, String raw) {
  var hits = 0;
  final leftovers = <String>[];
  for (final original in raw.split(RegExp(r'\r?\n'))) {
    final line = original.trim().replaceFirst(RegExp(r'^[*•·\-\s]+'), '');
    if (line.isEmpty ||
        RegExp(r'^\[?계약서\s*작성\s*요청\]?$').hasMatch(line) ||
        RegExp(r'^계약서\s*작성\s*요청\s*드립니다\.?$').hasMatch(line)) {
      continue;
    }
    final kv = RegExp(r'^([^:：]+?)\s*[:：]\s*(.*)$').firstMatch(line);
    final key = (kv != null ? kv[1]! : line).replaceAll(RegExp(r'\s'), '');
    final value = kv != null ? kv[2]!.trim() : '';
    final compact = line.replaceAll(RegExp(r'\s'), '');
    String ynSource() => kv != null ? value : key.replaceFirst(RegExp(r'^.*여부'), '');

    hits++;
    if (kv != null && RegExp(r'^현장명?$').hasMatch(key)) {
      out.siteName = value;
    } else if (kv != null &&
        RegExp(r'공사(장소|위치|주소)|^현장주소$|^주소$').hasMatch(key)) {
      out.siteAddress = value;
    } else if (kv != null && key.contains('품목')) {
      out.items = value;
    } else if (kv != null && key.contains('공사기간')) {
      final p = value.split(RegExp(r'\s*[-~]\s*(?=\d{2,4}\s*[./-])'));
      out.periodStart = p.isNotEmpty && p[0].isNotEmpty ? parseLooseDate(p[0]) : null;
      out.periodEnd = p.length > 1 ? parseLooseDate(p[1]) : null;
    } else if (kv != null && key.contains('계약금액')) {
      out.supplyAmount = parseWon(
        value
            .replaceFirst(RegExp(r'^(공급가(액)?|공급가액)\s*'), '')
            .replaceFirst(RegExp(r'\(.*\)$'), ''),
      );
    } else if (key == '선급금지급시기') {
      out.advancePayWhen = value;
    } else if (key == '기성금지급시기') {
      out.progressPayWhen = value;
    } else if (RegExp(r'^선급금\d+%$').hasMatch(key)) {
      out.advanceRate = int.parse(RegExp(r'\d+').firstMatch(key)![0]!);
    } else if (RegExp(r'^기성금\d+%$').hasMatch(key)) {
      out.progressRate = int.parse(RegExp(r'\d+').firstMatch(key)![0]!);
    } else if (RegExp(r'선급금(증권|보증)').hasMatch(key)) {
      final yn = _parseYesNo(ynSource());
      if (yn != null) out.advanceBond = yn;
    } else if (RegExp(r'계약이행(보증|증권)').hasMatch(key)) {
      final yn = _parseYesNo(ynSource());
      if (yn != null) out.performanceBond = yn;
    } else if (RegExp(r'하자(보증|증권)').hasMatch(key)) {
      final yn = _parseYesNo(ynSource());
      if (yn != null) out.defectBond = yn;
    } else if (RegExp(r'^무상(보증|보수)기간').hasMatch(compact)) {
      out.warranty = (kv != null
              ? value
              : line.replaceFirst(RegExp(r'^무상\s*(보증|보수)\s*기간\s*'), ''))
          .trim();
    } else if (RegExp(r'통장\s*사본').hasMatch(line)) {
      out.withBankbook = true;
    } else if (RegExp(r'직접\s*발송|직접\s*전달|인편|등기').hasMatch(line)) {
      out.sendMethod = '직접발송';
    } else if (RegExp(r'메일|이메일').hasMatch(line) && line.contains('@')) {
      out.sendMethod = '메일';
      out.mailTo = RegExp(r'[^\s@,;:()]+@[^\s@,;:()]+\.[^\s@,;:()]+')
          .allMatches(line)
          .map((m) => m[0]!)
          .join(', ');
    } else {
      hits--;
      leftovers.add(original.trim());
    }
  }
  if (leftovers.isNotEmpty) out.note = leftovers.join('\n');
  return hits;
}
