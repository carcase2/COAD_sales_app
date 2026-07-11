import 'package:coad_customer_calls/core/utils/phone_validation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('isValidKoreanPhone', () {
    test('자릿수 범위', () {
      expect(isValidKoreanPhone('0101234567'), isTrue); // 10
      expect(isValidKoreanPhone('010-1234-5678'), isTrue); // 11
      expect(isValidKoreanPhone('02-123-4567'), isTrue); // 9
      expect(isValidKoreanPhone('12345678'), isFalse); // 8
      expect(isValidKoreanPhone('01012345678901'), isFalse); // 13
    });
  });

  group('formatKoreanPhoneHyphenated', () {
    test('휴대폰 하이픈', () {
      expect(formatKoreanPhoneHyphenated('01056606005'), '010-5660-6005');
      expect(formatKoreanPhoneHyphenated('010'), '010');
      expect(formatKoreanPhoneHyphenated('0105'), '010-5');
    });
  });

  group('matchesPhoneSearch', () {
    test('숫자·하이픈 혼합 매칭', () {
      expect(matchesPhoneSearch('01056606005', '010-5660-6005'), isTrue);
      expect(matchesPhoneSearch('010-5660', '01056606005'), isTrue);
      expect(matchesPhoneSearch('0109999', '010-5660-6005'), isFalse);
      expect(matchesPhoneSearch('010', null), isFalse);
    });
  });

  group('termMatchesSalesCallSearch', () {
    test('이름·문의내용 부분 일치', () {
      expect(
        termMatchesSalesCallSearch(
          '코아드',
          customerName: '코아드 현장',
          customerPhone: null,
          inquiryContent: '문의',
          regionLabel: '강남',
          productCategoryName: null,
        ),
        isTrue,
      );
    });

    test('전화번호 검색 우선', () {
      expect(
        termMatchesSalesCallSearch(
          '0105660',
          customerName: '홍길동',
          customerPhone: '010-5660-6005',
          inquiryContent: '',
          regionLabel: null,
          productCategoryName: null,
        ),
        isTrue,
      );
    });
  });
}
