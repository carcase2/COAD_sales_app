bool isValidKoreanPhone(String input) {
  final digits = input.replaceAll(RegExp(r'\D'), '');
  return digits.length >= 9 && digits.length <= 12;
}

String normalizePhoneDigits(String input) => input.replaceAll(RegExp(r'\D'), '');
