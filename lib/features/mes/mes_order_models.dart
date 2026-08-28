import 'package:coad_customer_calls/core/utils/phone_validation.dart';

const mesOrderSteps = ['현장', '제품', '센서', '사진', '금액·수금'];

const mesPhoneKinds = [
  ('mobile', '휴대폰'),
  ('home', '집전화'),
  ('office', '사무실'),
];

const mesMotorOptions = [
  ('L', '좌'),
  ('R', '우'),
];

const mesPayKinds = [
  ('DEPOSIT', '계약금'),
  ('INTERIM', '중도금'),
  ('BALANCE', '잔금'),
  ('OTHER', '기타'),
];

const mesPayTypes = [
  ('1', '세금계산서'),
  ('2', '현금영수증'),
  ('3', '무기명'),
  ('4', '신용카드'),
  ('5', '어음'),
  ('6', '전자결제'),
  ('7', '기타'),
];

const mesContractTypes = [
  ('1', '발주서'),
  ('2', '계약서'),
  ('3', '체크시트'),
  ('4', '사업자등록증/신분증'),
];

const mesPayPercentPresets = [10, 20, 30, 50];

bool mesIsSensor({String? kind, String? code, String? name, String? label}) {
  if ((kind ?? '').toLowerCase() == 'sensor') return true;
  return RegExp(r'센서|sns-|sensor', caseSensitive: false)
      .hasMatch('${code ?? ''} ${name ?? ''} ${label ?? ''}');
}

int mesParseMm(String raw) {
  final digits = raw.replaceAll(RegExp(r'[^\d]'), '');
  if (digits.isEmpty) return 0;
  return int.tryParse(digits) ?? 0;
}

String mesFormatMm(Object? raw) {
  final n = mesParseMm('$raw');
  if (n <= 0) return '';
  return n.toString().replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+$)'),
    (m) => '${m[1]},',
  );
}

int mesWonDigits(String raw) {
  final digits = raw.replaceAll(RegExp(r'[^\d]'), '');
  if (digits.isEmpty) return 0;
  return int.tryParse(digits) ?? 0;
}

String mesFormatWon(int n) {
  if (n <= 0) return '0';
  return n.toString().replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+$)'),
    (m) => '${m[1]},',
  );
}

String mesAmountFromPercent(int contract, int pct) {
  if (contract <= 0 || pct <= 0) return '';
  return '${((contract * pct) / 100).round()}';
}

class MesPhoneRow {
  MesPhoneRow({this.kind = 'mobile', this.phone = ''});
  String kind;
  String phone;
}

String mesComposePhones(List<MesPhoneRow> rows) {
  const labels = {'mobile': '휴대폰', 'home': '집전화', 'office': '사무실'};
  return rows
      .map((r) => (kind: r.kind, phone: formatKoreanPhoneHyphenated(r.phone)))
      .where((r) => r.phone.isNotEmpty)
      .map((r) => '${labels[r.kind] ?? '휴대폰'} ${r.phone}')
      .join(' / ');
}

class MesItemRow {
  MesItemRow({
    this.categoryId = '',
    this.productId = '',
    this.color = '',
    this.qty = '1',
    this.widthMm = '',
    this.heightMm = '',
    this.motor = 'L',
    this.remark = '',
    List<MesOptionRow>? options,
  }) : options = options ?? [];

  String categoryId;
  String productId;
  String color;
  String qty;
  String widthMm;
  String heightMm;
  String motor;
  String remark;
  List<MesOptionRow> options;

  MesItemRow copy() => MesItemRow(
        categoryId: categoryId,
        productId: productId,
        color: color,
        qty: qty,
        widthMm: widthMm,
        heightMm: heightMm,
        motor: motor,
        remark: remark,
        options: [for (final o in options) MesOptionRow(name: o.name, value: o.value)],
      );
}

class MesOptionRow {
  MesOptionRow({required this.name, required this.value});
  String name;
  String value;
}

class MesMatRow {
  MesMatRow({
    required this.materialId,
    required this.qty,
    required this.fromBom,
    required this.label,
  });
  String materialId;
  String qty;
  bool fromBom;
  String label;
}

class MesPayRow {
  MesPayRow({
    this.kind = 'DEPOSIT',
    this.amount = '',
    this.dueDate = '',
    this.payBank = '',
    this.payType = '1',
  });
  String kind;
  String amount;
  String dueDate;
  String payBank;
  String payType;
}

class MesInstallDay {
  MesInstallDay({required this.date, List<int>? slots}) : slots = slots ?? [];
  String date;
  List<int> slots;
}

class MesPhotoRef {
  MesPhotoRef({
    required this.id,
    required this.category,
    this.label,
    this.localPath,
  });
  String id;
  String category;
  String? label;
  String? localPath;
}

int mesOtherPaySum(List<MesPayRow> rows) {
  return rows
      .where((r) => r.kind != 'BALANCE')
      .fold(0, (sum, r) => sum + mesWonDigits(r.amount));
}

List<MesPayRow> mesSyncBalance(List<MesPayRow> rows, int contract) {
  final others = rows.where((r) => r.kind != 'BALANCE').toList();
  final rem = contract <= 0 ? 0 : (contract - mesOtherPaySum(rows)).clamp(0, contract);
  MesPayRow? prev;
  for (final r in rows) {
    if (r.kind == 'BALANCE') {
      prev = r;
      break;
    }
  }
  prev ??= MesPayRow(kind: 'BALANCE', payType: others.isEmpty ? '1' : others.last.payType);
  return [
    ...others,
    MesPayRow(
      kind: 'BALANCE',
      amount: rem > 0 ? '$rem' : '',
      dueDate: prev.dueDate,
      payBank: prev.payBank,
      payType: prev.payType,
    ),
  ];
}

class MesCatOptionDef {
  MesCatOptionDef({
    required this.categoryId,
    required this.name,
    this.fieldType = 'TEXT',
    this.required = false,
    this.defaultValue,
    this.choices = const [],
    this.isActive = true,
  });

  final String categoryId;
  final String name;
  final String fieldType;
  final bool required;
  final String? defaultValue;
  final List<String> choices;
  final bool isActive;

  String get fallback {
    if (fieldType == 'CHECK') return 'N';
    final fromCol = (defaultValue ?? '').trim();
    if (fromCol.isNotEmpty) return fromCol;
    if (fieldType == 'NUMBER' && choices.isNotEmpty) return choices.first.trim();
    return '';
  }
}

List<MesOptionRow> mesMergeOptions(List<MesCatOptionDef> defs, List<MesOptionRow> existing) {
  final byName = {for (final o in existing) o.name: o.value};
  final named = defs.map((d) => d.name).toSet();
  return [
    ...defs.map((d) => MesOptionRow(name: d.name, value: byName[d.name] ?? d.fallback)),
    ...existing.where((o) => !named.contains(o.name)),
  ];
}

bool mesCanNextSite({required String siteMode, required String siteName}) {
  return siteMode != 'search' && siteName.trim().isNotEmpty;
}

bool mesCanNextItems(List<MesItemRow> items, {required bool Function(String categoryId) hasRequiredOptions}) {
  if (items.isEmpty) return false;
  for (final it in items) {
    if (it.productId.isEmpty || mesParseMm(it.widthMm) <= 0 || mesParseMm(it.heightMm) <= 0) {
      return false;
    }
    final qty = int.tryParse(it.qty) ?? 0;
    if (qty <= 0 || it.motor.isEmpty) return false;
    if (!hasRequiredOptions(it.categoryId)) return false;
  }
  return true;
}

Map<String, dynamic> mesBuildOrderPayload({
  required bool draft,
  String? draftId,
  required String customerId,
  required String siteId,
  required String siteName,
  required String siteAddress,
  required String siteAddressDetail,
  required String locationType,
  required String managerName,
  required List<MesPhoneRow> phones,
  required String branchCode,
  required String salesUserId,
  required List<MesInstallDay> installDays,
  required int contractAmount,
  required bool vatIncluded,
  required List<String> contractTypes,
  required String mfgNote,
  required String installNote,
  required String remark,
  required List<MesItemRow> items,
  required List<MesMatRow> materials,
  required List<MesPayRow> payments,
  required List<MesPhotoRef> photos,
  bool confirmShortage = false,
}) {
  final dates = installDays.map((d) => d.date).where((d) => d.isNotEmpty).toList()..sort();
  final slots = <int>{};
  for (final d in installDays) {
    slots.addAll(d.slots);
  }
  return {
    'draft': draft,
    if (draftId != null && draftId.isNotEmpty) 'draftId': draftId,
    'customer': {
      if (customerId.isNotEmpty) 'id': customerId,
      'name': siteName,
    },
    'site': {
      if (siteId.isNotEmpty) 'id': siteId,
      'name': siteName,
      'address': siteAddress,
      'addressDetail': siteAddressDetail,
      'locationType': locationType,
      'managerName': managerName,
      'managerPhone': mesComposePhones(phones),
    },
    'branchCode': branchCode,
    'salesUserId': salesUserId,
    'requestedInstallDate': dates.isEmpty ? null : dates.first,
    'requestedInstallDates': dates,
    'installCrewSlot': slots.isEmpty ? null : slots.first,
    'installCrewSlots': slots.toList()..sort(),
    'installPlan': [
      for (final d in installDays)
        if (d.date.isNotEmpty) {'date': d.date, 'slots': d.slots},
    ],
    'contractAmount': contractAmount,
    'vatIncluded': vatIncluded,
    'contractTypes': contractTypes,
    'mfgNote': mfgNote,
    'installNote': installNote,
    'remark': remark,
    'items': [
      for (final it in items)
        {
          'productId': it.productId,
          'qty': int.tryParse(it.qty) ?? 0,
          'widthMm': mesParseMm(it.widthMm),
          'heightMm': mesParseMm(it.heightMm),
          'motor': it.motor,
          'color': it.color.isEmpty ? null : it.color,
          'remark': it.remark,
          'options': [
            for (final o in it.options)
              if (o.name.isNotEmpty && o.value.isNotEmpty) {'name': o.name, 'value': o.value},
          ],
        },
    ],
    'materials': [
      for (final m in materials)
        {
          'materialId': m.materialId,
          'qty': int.tryParse(m.qty) ?? 0,
          'fromBom': m.fromBom,
        },
    ],
    'payments': [
      for (final p in payments)
        if (mesWonDigits(p.amount) > 0 && p.dueDate.isNotEmpty)
          {
            'kind': p.kind,
            'amount': mesWonDigits(p.amount),
            'dueDate': p.dueDate,
            'payBank': p.payBank.isEmpty ? null : p.payBank,
            'payType': p.payType,
          },
    ],
    'photos': [
      for (final p in photos)
        if (!p.id.startsWith('pending:'))
          {'id': p.id, 'category': p.category, if (p.label != null) 'label': p.label},
    ],
    'confirmShortage': confirmShortage,
  };
}
