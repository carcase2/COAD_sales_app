import 'package:coad_customer_calls/core/utils/korean_amount_words.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('koreanWonInWords', () {
    test('일반 금액', () {
      expect(koreanWonInWords(200000), '이십만원');
      expect(koreanWonInWords(10000), '만원');
      expect(koreanWonInWords(1000), '천원');
      expect(koreanWonInWords(1234567), '백이십삼만사천오백육십칠원');
    });

    test('0은 빈 문자열, 음수는 마이너스', () {
      expect(koreanWonInWords(0), '');
      expect(koreanWonInWords(-30000), '마이너스 삼만원');
    });
  });
}
