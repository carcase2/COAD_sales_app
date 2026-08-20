import 'package:coad_customer_calls/data/business_card_detect.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('longestRunAbove — 가장 긴 연속 구간', () {
    expect(longestRunAbove([0, 1, 8, 9, 8, 0, 7, 0], 7), (2, 4));
    expect(longestRunAbove([3, 3, 3], 5), isNull);
    expect(longestRunAbove([9, 9, 0, 8, 8, 8, 8], 8), (3, 6));
  });
}
