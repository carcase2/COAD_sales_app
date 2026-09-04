import 'package:coad_customer_calls/core/utils/date_seoul.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('KST 달력일 경계를 UTC Z로 보낸다', () {
    // 2026-09-05 00:00 KST = 2026-09-04 15:00 UTC
    expect(seoulDayStartUtcIso('2026-09-05'), '2026-09-04T15:00:00.000Z');
    expect(seoulDayEndExclusiveUtcIso('2026-09-04'), '2026-09-04T15:00:00.000Z');
    expect(seoulDayEndExclusiveUtcIso('2026-09-05'), '2026-09-05T15:00:00.000Z');
  });

  test('KST 오전은 전일 UTC 자정이 아니라 당일 KST 구간에 들어간다', () {
    // 2026-09-05 07:11 KST = 2026-09-04 22:11 UTC
    final at = DateTime.parse('2026-09-04T22:11:00.000Z');
    final dayStart = DateTime.parse(seoulDayStartUtcIso('2026-09-05'));
    final dayEnd = DateTime.parse(seoulDayEndExclusiveUtcIso('2026-09-05'));
    final prevStart = DateTime.parse(seoulDayStartUtcIso('2026-09-04'));
    final prevEnd = DateTime.parse(seoulDayEndExclusiveUtcIso('2026-09-04'));

    expect(!at.isBefore(dayStart) && at.isBefore(dayEnd), isTrue);
    expect(!at.isBefore(prevStart) && at.isBefore(prevEnd), isFalse);
  });
}
