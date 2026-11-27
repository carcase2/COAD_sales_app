/// 계약서 작성 요청 (영업 → 총무). COAD_home `contractRequestModel.ts` 와 같은 규칙.
library;

import 'package:coad_customer_calls/data/business_card_ocr.dart';

const contractSendMethods = ['메일', '직접발송'];
const contractListFilters = ['요청', '완료', '취소', '전체'];
const contractClientTypes = ['기업', '개인'];

/// 계약서 '수급인' 상호. 양식이 이 글자 그대로 찾으므로 value 는 바꾸지 않는다.
const contractContractors = [
  (value: '㈜ 코 아 드', label: '㈜코아드 (본사)'),
  (value: '㈜ 코아드 대전', label: '㈜코아드 대전'),
  (value: '㈜ 코아드 대구', label: '㈜코아드 대구'),
  (value: '㈜ 코아드 전남', label: '㈜코아드 전남'),
];

/// 요청할 때 함께 붙이는 서류 (새 요청은 둘 다 있어야 한다)
const contractAttachmentKinds = [
  (kind: 'business_license', label: '발주처 사업자등록증'),
  (kind: 'business_card', label: '담당자 명함'),
];
const contractMaxFileBytes = 20 * 1024 * 1024;
const contractMaxFilesPerKind = 5;

String contractAttachmentLabel(String kind) =>
    contractAttachmentKinds.where((k) => k.kind == kind).firstOrNull?.label ??
    kind;

/// 첨부가 빠진 서류 이름들
List<String> missingContractAttachments(Map<String, int> counts) => [
  for (final k in contractAttachmentKinds)
    if ((counts[k.kind] ?? 0) <= 0) k.label,
];

class ContractFile {
  const ContractFile({
    required this.id,
    required this.kind,
    required this.name,
    required this.size,
    required this.contentType,
  });

  final String id;
  final String kind;
  final String name;
  final int size;
  final String contentType;

  bool get isImage => contentType.startsWith('image/');

  factory ContractFile.fromJson(Map<String, dynamic> j) => ContractFile(
    id: '${j['id'] ?? ''}',
    kind: '${j['kind'] ?? ''}',
    name: '${j['name'] ?? ''}',
    size: ContractFields._int(j['size']) ?? 0,
    contentType: '${j['content_type'] ?? ''}',
  );
}

class ContractFields {
  ContractFields({
    this.clientType = '기업',
    this.clientName = '',
    this.clientBizNo = '',
    this.clientAddress = '',
    this.clientRep = '',
    this.clientPhone = '',
    this.contractor = '㈜ 코 아 드',
    this.performanceBondRate,
    this.defectBondRate,
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

  /// 발주자 구분: 기업 / 개인
  String clientType;

  /// 기업은 상호, 개인은 성명
  String clientName;
  String clientBizNo;
  String clientAddress;

  /// 기업 대표자
  String clientRep;

  /// 개인 전화번호
  String clientPhone;

  /// 수급인 (코아드 본사·지사)
  String contractor;

  /// 계약이행·하자 보증금 비율(%) — 필요할 때만
  int? performanceBondRate;
  int? defectBondRate;

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

  /// yyyy-MM-dd (날짜로 고른다)
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

  ContractFields copy() {
    final f = ContractFields();
    fillFromJson(f, toJson(trimmed: false));
    return f;
  }

  Map<String, dynamic> toJson({bool trimmed = true}) {
    String t(String s) => trimmed ? s.trim() : s;
    final company = clientType != '개인';
    return {
      'client_type': clientType,
      'client_name': t(clientName),
      'client_biz_no': company ? t(clientBizNo) : '',
      'client_address': t(clientAddress),
      'client_rep': company ? t(clientRep) : '',
      'client_phone': company ? '' : t(clientPhone),
      'contractor': contractor,
      'performance_bond_rate': performanceBond ? performanceBondRate : null,
      'defect_bond_rate': defectBond ? defectBondRate : null,
      'site_name': t(siteName),
      'site_address': t(siteAddress),
      'items': t(items),
      'period_start': periodStart,
      'period_end': periodEnd,
      'supply_amount': supplyAmount,
      'advance_rate': advanceRate,
      'progress_rate': progressRate,
      'advance_pay_when': t(advancePayWhen),
      'progress_pay_when': t(progressPayWhen),
      'advance_bond': advanceBond,
      'performance_bond': performanceBond,
      'defect_bond': defectBond,
      'warranty': t(warranty),
      'send_method': sendMethod,
      'mail_to': sendMethod == '메일' ? t(mailTo) : '',
      'with_bankbook': withBankbook,
      'note': t(note),
    };
  }

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
      ..clientType = j['client_type'] == '개인' ? '개인' : '기업'
      ..clientName = '${j['client_name'] ?? ''}'
      ..clientBizNo = '${j['client_biz_no'] ?? ''}'
      ..clientAddress = '${j['client_address'] ?? ''}'
      ..clientRep = '${j['client_rep'] ?? ''}'
      ..clientPhone = '${j['client_phone'] ?? ''}'
      ..contractor = contractContractors.any((c) => c.value == j['contractor'])
          ? '${j['contractor']}'
          : '㈜ 코 아 드'
      ..performanceBondRate = _int(j['performance_bond_rate'])
      ..defectBondRate = _int(j['defect_bond_rate'])
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
    required this.files,
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
  final List<ContractFile> files;
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
      files: [
        for (final f in (j['files'] as List? ?? const []))
          if (f is Map) ContractFile.fromJson(Map<String, dynamic>.from(f)),
      ],
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
    return [
      siteName,
      siteAddress,
      items,
      requesterName,
      requestNo,
      note,
    ].join(' ').toLowerCase().contains(q);
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
  final advWhen = f.advancePayWhen.trim();
  if (advWhen.isNotEmpty && !_dateRe.hasMatch(advWhen)) {
    return '선급금 지급시기 날짜를 확인해 주세요.';
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
  final company = f.clientType != '개인';
  if (f.clientName.trim().isEmpty) {
    return company ? '발주자 상호를 입력해 주세요.' : '발주자 성명을 입력해 주세요.';
  }
  if (company) {
    final raw = f.clientBizNo.trim();
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (raw.isNotEmpty && digits.length != 10) return '사업자등록번호는 숫자 10자리입니다.';
  }
  if (badRate(f.performanceBondRate) || badRate(f.defectBondRate)) {
    return '보증금 비율은 0~100 사이 정수로 입력해 주세요.';
  }
  return null;
}

/// '1234567890' → '123-45-67890' (10자리가 아니면 그대로)
String formatBizNo(String s) {
  final d = s.replaceAll(RegExp(r'\D'), '');
  return d.length == 10
      ? '${d.substring(0, 3)}-${d.substring(3, 5)}-${d.substring(5)}'
      : s.trim();
}

/// '2026-11-26' → '26.11.26' (단톡방 양식과 같게)
String dotDate(String d) => _dateRe.hasMatch(d)
    ? '${d.substring(2, 4)}.${d.substring(5, 7)}.${d.substring(8, 10)}'
    : d;

/// 시작일을 고르면 종료일이 따라온다. 사람이 따로 고른(새 시작일 이후) 종료일은 둔다.
String? followStart(String? prevStart, String? prevEnd, String? nextStart) {
  if (nextStart == null) return prevEnd;
  if (prevEnd == null ||
      prevEnd == prevStart ||
      prevEnd.compareTo(nextStart) < 0) {
    return nextStart;
  }
  return prevEnd;
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
    '선급금지급시기: ${dotDate(r.advancePayWhen)}',
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
    String ynSource() =>
        kv != null ? value : key.replaceFirst(RegExp(r'^.*여부'), '');

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
      out.periodStart = p.isNotEmpty && p[0].isNotEmpty
          ? parseLooseDate(p[0])
          : null;
      out.periodEnd = p.length > 1 ? parseLooseDate(p[1]) : null;
    } else if (kv != null && key.contains('계약금액')) {
      out.supplyAmount = parseWon(
        value
            .replaceFirst(RegExp(r'^(공급가(액)?|공급가액)\s*'), '')
            .replaceFirst(RegExp(r'\(.*\)$'), ''),
      );
    } else if (key == '선급금지급시기') {
      out.advancePayWhen = parseLooseDate(value) ?? '';
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
      out.warranty =
          (kv != null
                  ? value
                  : line.replaceFirst(RegExp(r'^무상\s*(보증|보수)\s*기간\s*'), ''))
              .trim();
    } else if (RegExp(r'통장\s*사본').hasMatch(line)) {
      out.withBankbook = true;
    } else if (RegExp(r'직접\s*발송|직접\s*전달|인편|등기').hasMatch(line)) {
      out.sendMethod = '직접발송';
    } else if (RegExp(r'메일|이메일').hasMatch(line) && line.contains('@')) {
      out.sendMethod = '메일';
      out.mailTo = RegExp(
        r'[^\s@,;:()]+@[^\s@,;:()]+\.[^\s@,;:()]+',
      ).allMatches(line).map((m) => m[0]!).join(', ');
    } else {
      hits--;
      leftovers.add(original.trim());
    }
  }
  if (leftovers.isNotEmpty) out.note = leftovers.join('\n');
  return hits;
}

/* ---------- 품목: NEW MES 제품 목록(대분류 → 제품) ---------- */

class CatalogCategory {
  const CatalogCategory({
    required this.code,
    required this.name,
    required this.products,
  });
  final String code;
  final String name;
  final List<({String code, String name})> products;

  factory CatalogCategory.fromJson(Map<String, dynamic> j) => CatalogCategory(
    code: '${j['code'] ?? ''}',
    name: '${j['name'] ?? ''}',
    products: [
      for (final p in (j['products'] as List? ?? const []))
        if (p is Map) (code: '${p['code'] ?? ''}', name: '${p['name'] ?? ''}'),
    ],
  );
}

/// 품목 글('A 1대, B 2대')에 한 줄을 더한다. 같은 이름이 있으면 수량만 더한다.
String addContractItem(String text, String name, int qty) {
  final parts = text
      .split(RegExp(r'\s*,\s*'))
      .map((p) => p.trim())
      .where((p) => p.isNotEmpty)
      .toList();
  for (var i = 0; i < parts.length; i++) {
    final m = RegExp(r'^(.*?)\s*(\d+)\s*대$').firstMatch(parts[i]);
    if ((m?[1] ?? parts[i]).trim() == name) {
      parts[i] = '$name ${(int.tryParse(m?[2] ?? '') ?? 1) + qty}대';
      return parts.join(', ');
    }
  }
  return [...parts, '$name $qty대'].join(', ');
}

/* ---------- 사업자등록증·명함 자동 인식 ---------- */

class RecognizedDocument {
  const RecognizedDocument(this.j);
  final Map<String, dynamic> j;
  String _s(String k) => '${j[k] ?? ''}'.trim();
  String get docType => _s('doc_type');
  String get companyName => _s('company_name');
  String get bizNo => _s('biz_no');
  String get representative => _s('representative');
  String get address => _s('address');
  String get personName => _s('person_name');
  String get personTitle => _s('person_title');
  String get phone => _s('phone');
  String get mobile => _s('mobile');
  String get email => _s('email');

  /// 명함 담당자를 요청 메모에 남길 한 줄
  String get contactLine {
    if (personName.isEmpty && mobile.isEmpty && email.isEmpty) return '';
    final who = [personName, personTitle].where((s) => s.isNotEmpty).join(' ');
    return '담당자: ${[who, mobile.isNotEmpty ? mobile : phone, email].where((s) => s.isNotEmpty).join(' / ')}';
  }
}

/// 명함 탭과 같은 명함 인식 결과를 계약서 인식 결과 모양으로 바꾼다.
RecognizedDocument contractDocFromBusinessCard(BusinessCardResult c) =>
    RecognizedDocument({
      'doc_type': 'business_card',
      'company_name': c.company,
      'address': c.address,
      'person_name': c.name,
      'person_title': c.departmentAndTitle,
      'phone': c.officePhone,
      'mobile': c.phone,
      'email': c.email,
    });

/// 인식 결과로 칸 하나를 채울 제안. status: fill(빈 칸) / differs(다른 값 있음)
typedef ContractSuggestion = ({
  String key,
  String label,
  String value,
  String status,
});

String _comparable(String s) =>
    s.replaceAll(RegExp(r'[\s()㈜주식회사\-.,]'), '').toLowerCase();

/// COAD_home `suggestionsFor` 와 같은 규칙.
/// 사업자등록증은 상호·번호·대표자·주소, 명함은 (값이 없을 때) 상호·주소와 메일 주소.
List<ContractSuggestion> contractSuggestions(
  RecognizedDocument doc,
  String uploadedAs,
  ContractFields cur,
) {
  final isLicense =
      doc.docType == 'business_license' ||
      (doc.docType == 'other' && uploadedAs == 'business_license');
  const labels = {
    'client_name': '상호',
    'client_biz_no': '사업자등록번호',
    'client_rep': '대표자',
    'client_address': '주소',
    'mail_to': '받는 사람 이메일',
  };
  final picks = isLicense
      ? [
          ('client_name', doc.companyName),
          ('client_biz_no', doc.bizNo),
          ('client_rep', doc.representative),
          ('client_address', doc.address),
        ]
      : [
          ('client_name', doc.companyName),
          ('client_address', doc.address),
          ('mail_to', cur.sendMethod == '메일' ? doc.email : ''),
        ];
  final out = <ContractSuggestion>[];
  for (final (key, value) in picks) {
    if (value.isEmpty) continue;
    final now = contractFieldValue(cur, key).trim();
    if (!isLicense && now.isNotEmpty && key != 'mail_to') continue;
    if (key == 'mail_to' && now.toLowerCase().contains(value.toLowerCase())) {
      continue;
    }
    final status = now.isEmpty
        ? 'fill'
        : (_comparable(now) == _comparable(value) ? 'same' : 'differs');
    if (status == 'same') continue;
    out.add((key: key, label: labels[key]!, value: value, status: status));
  }
  return out;
}

String contractFieldValue(ContractFields f, String key) => switch (key) {
  'client_name' => f.clientName,
  'client_biz_no' => f.clientBizNo,
  'client_rep' => f.clientRep,
  'client_address' => f.clientAddress,
  'mail_to' => f.mailTo,
  _ => '',
};

void setContractField(ContractFields f, String key, String v) {
  switch (key) {
    case 'client_name':
      f.clientName = v;
    case 'client_biz_no':
      f.clientBizNo = v;
    case 'client_rep':
      f.clientRep = v;
    case 'client_address':
      f.clientAddress = v;
    case 'mail_to':
      f.mailTo = v;
  }
}
