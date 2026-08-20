import 'package:coad_customer_calls/core/widgets/search_highlight_text.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('부분 문자열 하이라이트', () {
    expect(searchHighlightRanges('홍길동 (코아드)', '코아드'), [(5, 8)]);
    expect(searchTextMatches('대구 달서구', '달서'), isTrue);
  });

  test('전화번호 하이픈 달라도 하이라이트', () {
    expect(
      searchHighlightRanges('1899-7081', '18997081'),
      [(0, 9)],
    );
    expect(searchTextMatches('010-5660-6005', '0105660'), isTrue);
  });
}
