import 'package:coad_customer_calls/core/utils/phone_validation.dart';

class BusinessCardResult {
  final String name;
  final String company;
  final String title;
  final String phone;
  final String officePhone;
  final String faxPhone;
  final String email;
  final String address;

  BusinessCardResult({
    required this.name,
    required this.company,
    this.title = '',
    required this.phone,
    this.officePhone = '',
    this.faxPhone = '',
    this.email = '',
    this.address = '',
  });

  bool get hasAnyField =>
      name.isNotEmpty ||
      company.isNotEmpty ||
      phone.isNotEmpty ||
      officePhone.isNotEmpty ||
      faxPhone.isNotEmpty ||
      email.isNotEmpty;

  factory BusinessCardResult.fromJson(Map<String, dynamic> json) {
    final mobile = _firstNonEmpty([
      json['phone'],
      json['mobile_phone'],
      json['mobile'],
    ]);
    return BusinessCardResult(
      name: json['name']?.toString().trim() ?? '',
      company: json['company']?.toString().trim() ?? '',
      title: json['title']?.toString().trim() ?? '',
      phone: mobile,
      officePhone: _firstNonEmpty([
        json['office_phone'],
        json['tel'],
        json['landline'],
      ]),
      faxPhone: _firstNonEmpty([
        json['fax'],
        json['fax_phone'],
      ]),
      email: json['email']?.toString().trim() ?? '',
      address: json['address']?.toString().trim() ?? '',
    );
  }

  static String _firstNonEmpty(List<Object?> values) {
    for (final v in values) {
      final s = v?.toString().trim() ?? '';
      if (s.isNotEmpty) return s;
    }
    return '';
  }
}

final _emailRe = RegExp(
  r'[A-Z0-9._%+\-]+@[A-Z0-9.\-]+\.[A-Z]{2,}',
  caseSensitive: false,
);
final _mobileRe = RegExp(
  r'(?:\+82[\s\-]?)?0?1[016789][\s\-]?\d{3,4}[\s\-]?\d{4}',
);
final _landlineRe = RegExp(r'0\d{1,2}[\s\-]?\d{3,4}[\s\-]?\d{4}');
final _nationalRe = RegExp(r'(?<!\d)1[3-9]\d{2}[\s\-]?\d{4}(?!\d)');
final _titleRe = RegExp(
  r'(대표이사|대표님|대표|회장|사장|전무|상무|이사|본부장|센터장|실장|팀장|부장|과장|대리|주임|매니저|사원|선임|책임|수석|소장)',
);
final _companyHintRe = RegExp(
  r'(주식회사|\(주\)|㈜|㈲|유한회사|\bInc\.?\b|\bLtd\.?\b|\bCo\.|\bCorp)',
  caseSensitive: false,
);
final _hangulNameRe = RegExp(r'^[가-힣]{2,4}$');
final _addrHintRe = RegExp(r'(특별시|광역시|특별자치|도|시|군|구|읍|면|동|로|길)');

/// OCR 원문에서 명함 필드를 뽑는다. 추측보다 패턴 매칭을 우선한다.
BusinessCardResult parseBusinessCardText(String raw) {
  final lines = raw
      .split(RegExp(r'[\r\n]+'))
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();
  final blob = lines.join(' ');

  var email = '';
  final emailMatch = _emailRe.firstMatch(blob);
  if (emailMatch != null) email = emailMatch.group(0)!.trim();

  var mobile = '';
  for (final m in _mobileRe.allMatches(blob)) {
    final d = _normalizePhone(m.group(0)!);
    if (d.startsWith('01') && d.length >= 10) {
      mobile = formatKoreanPhoneHyphenated(d);
      break;
    }
  }

  var office = '';
  for (final m in _landlineRe.allMatches(blob)) {
    final d = _normalizePhone(m.group(0)!);
    if (d.startsWith('01')) continue;
    if (d.length >= 9 && d.length <= 11) {
      office = formatKoreanPhoneHyphenated(d);
      break;
    }
  }
  if (office.isEmpty) {
    for (final m in _nationalRe.allMatches(blob)) {
      final d = _normalizePhone(m.group(0)!);
      if (d.length == 8) {
        office = formatKoreanPhoneHyphenated(d);
        break;
      }
    }
  }

  var title = '';
  var titleIndex = -1;
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    final t = _titleRe.firstMatch(line);
    if (t == null) continue;
    final cleaned = line.replaceAll(RegExp(r'\s+'), ' ').trim();
    title = cleaned.length <= 24 ? cleaned : t.group(0)!;
    titleIndex = i;
    break;
  }

  var company = '';
  for (final line in lines) {
    if (!_companyHintRe.hasMatch(line)) continue;
    if (line.contains('@')) continue;
    company = line.replaceAll(RegExp(r'\s+'), ' ').trim();
    break;
  }

  String hangulOnly(String line) => line.replaceAll(RegExp(r'[^가-힣]'), '');
  final companyHangul = hangulOnly(company);

  bool looksLikePersonName(String line) {
    final hangul = hangulOnly(line);
    if (!_hangulNameRe.hasMatch(hangul)) return false;
    if (_companyHintRe.hasMatch(line)) return false;
    if (companyHangul.isNotEmpty && hangul == companyHangul) return false;
    if (_titleRe.hasMatch(line) && line.length > hangul.length + 1) return false;
    return true;
  }

  var name = '';
  if (titleIndex >= 0) {
    for (final i in [titleIndex - 1, titleIndex + 1]) {
      if (i < 0 || i >= lines.length) continue;
      if (!looksLikePersonName(lines[i])) continue;
      name = hangulOnly(lines[i]);
      break;
    }
  }
  if (name.isEmpty) {
    for (final line in lines) {
      if (!looksLikePersonName(line)) continue;
      name = hangulOnly(line);
      break;
    }
  }

  var address = '';
  for (final line in lines) {
    if (line.contains('@')) continue;
    if (_mobileRe.hasMatch(line) && line.length < 18) continue;
    if (_addrHintRe.hasMatch(line) && line.length >= 8) {
      address = line.replaceAll(RegExp(r'\s+'), ' ').trim();
      break;
    }
  }

  var fax = '';
  for (final line in lines) {
    if (!RegExp(r'(fax|팩스)', caseSensitive: false).hasMatch(line)) continue;
    final digits = _normalizePhone(line);
    if (digits.length >= 8 && digits.length <= 12) {
      fax = formatKoreanPhoneHyphenated(digits);
      break;
    }
  }

  return BusinessCardResult(
    name: name,
    company: company,
    title: title,
    phone: mobile,
    officePhone: office,
    faxPhone: fax,
    email: email,
    address: address,
  );
}

String _normalizePhone(String raw) {
  var d = normalizePhoneDigits(raw);
  if (d.startsWith('82') && d.length >= 11) {
    d = '0${d.substring(2)}';
  }
  return d;
}
