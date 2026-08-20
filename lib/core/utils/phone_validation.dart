/// 검색창에 번호를 넣은 것으로 보고 서버 검색을 바로 열지 여부.
bool looksLikePhoneQuery(String input) =>
    normalizePhoneDigits(input).length >= 8;

bool isValidKoreanPhone(String input) {
  final digits = input.replaceAll(RegExp(r'\D'), '');
  return digits.length >= 9 && digits.length <= 12;
}

String normalizePhoneDigits(String input) => input.replaceAll(RegExp(r'\D'), '');

/// `010-5660-6005` ↔ `01056606005` 등 표기 차이를 검색에 반영.
/// 15xx·16xx·18xx 전국대표번호(8자리)는 4-4 (`1899-7081`).
String formatKoreanPhoneHyphenated(String digitsOnly) {
  final d = normalizePhoneDigits(digitsOnly);
  if (d.length <= 3) return d;

  // 1588-1234, 1899-7081 등. 010… 입력 중(8자리)과 구분.
  if (d.length == 8 && d.startsWith('1') && !d.startsWith('01')) {
    return '${d.substring(0, 4)}-${d.substring(4)}';
  }

  if (d.startsWith('02') && d.length >= 9) {
    final split = d.length == 9 ? 5 : 6;
    return '${d.substring(0, 2)}-${d.substring(2, split)}-${d.substring(split)}';
  }

  if (d.length <= 7) {
    return '${d.substring(0, 3)}-${d.substring(3)}';
  }
  if (d.length <= 11) {
    return '${d.substring(0, 3)}-${d.substring(3, 7)}-${d.substring(7)}';
  }
  return '${d.substring(0, 3)}-${d.substring(3, 7)}-${d.substring(7, 11)}';
}

List<String> phoneSearchPatterns(String input) {
  final trimmed = input.trim();
  if (trimmed.isEmpty) return const [];

  final patterns = <String>{trimmed};
  final digits = normalizePhoneDigits(trimmed);
  if (digits.isNotEmpty) patterns.add(digits);
  if (digits.length >= 9) {
    patterns.add(formatKoreanPhoneHyphenated(digits));
  }
  return patterns.toList();
}

bool matchesPhoneSearch(String query, String? storedPhone) {
  if (storedPhone == null || storedPhone.isEmpty) return false;
  final storedLower = storedPhone.toLowerCase();
  final storedDigits = normalizePhoneDigits(storedPhone);

  for (final pattern in phoneSearchPatterns(query)) {
    if (pattern.contains('-')) {
      if (storedLower.contains(pattern.toLowerCase())) return true;
    } else {
      if (storedDigits.contains(pattern)) return true;
    }
  }
  return false;
}

bool termMatchesSalesCallSearch(String term, {
  required String? customerName,
  required String? customerPhone,
  required String? inquiryContent,
  required String? regionLabel,
  required String? productCategoryName,
  String? extra,
}) {
  final t = term.toLowerCase();
  if (normalizePhoneDigits(term).length >= 4) {
    if (matchesPhoneSearch(term, customerPhone)) return true;
  }

  final blob = [
    customerName,
    customerPhone,
    inquiryContent,
    regionLabel,
    productCategoryName,
    extra,
  ].whereType<String>().join(' ').toLowerCase();

  return blob.contains(t);
}
