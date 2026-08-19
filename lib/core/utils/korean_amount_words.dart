/// 숫자 금액을 한글 표기로 변환 (예: 200000 → 이십만원).
String koreanWonInWords(int amount) {
  if (amount == 0) return '';
  final sign = amount < 0 ? '마이너스 ' : '';
  amount = amount.abs();

  const digits = ['', '일', '이', '삼', '사', '오', '육', '칠', '팔', '구'];
  const smallUnits = ['', '십', '백', '천'];
  const bigUnits = ['', '만', '억', '조'];

  String under10000(int n) {
    if (n == 0) return '';
    final buffer = StringBuffer();
    for (var i = 3; i >= 0; i--) {
      final place = [1000, 100, 10, 1][3 - i];
      final digit = (n ~/ place) % 10;
      if (digit == 0) continue;
      if (digit == 1 && i > 0) {
        buffer.write(smallUnits[i]);
      } else {
        buffer.write(digits[digit]);
        buffer.write(smallUnits[i]);
      }
    }
    return buffer.toString();
  }

  final chunks = <int>[];
  var n = amount;
  while (n > 0) {
    chunks.add(n % 10000);
    n ~/= 10000;
  }

  final buffer = StringBuffer();
  for (var i = chunks.length - 1; i >= 0; i--) {
    final chunk = chunks[i];
    if (chunk == 0) continue;
    if (chunk == 1 && i > 0) {
      buffer.write(bigUnits[i]);
      continue;
    }
    buffer
      ..write(under10000(chunk))
      ..write(bigUnits[i]);
  }

  return '$sign$buffer원';
}
