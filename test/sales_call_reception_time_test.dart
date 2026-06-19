import 'package:coad_customer_calls/core/utils/date_seoul.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('sales call reception time', () {
    test('call_date + call_time are KST wall clock (no +9h)', () {
      final seoul = resolveSalesCallReceptionSeoul(
        callDate: '2026-06-18',
        callTime: '15:30:00',
        createdAt: null,
      );
      expect(seoul, isNotNull);
      expect(seoul!.hour, 15);
      expect(seoul.minute, 30);
    });

    test('created_at with Z offset converts to Seoul', () {
      final seoul = resolveSalesCallReceptionSeoul(
        callDate: null,
        callTime: null,
        createdAt: '2026-06-18T06:30:00.000Z',
      );
      expect(seoul, isNotNull);
      expect(seoul!.hour, 15);
      expect(seoul.minute, 30);
    });

    test('call_date only uses created_at for time when present', () {
      final seoul = resolveSalesCallReceptionSeoul(
        callDate: '2026-06-18',
        callTime: null,
        createdAt: '2026-06-18T06:30:00.000Z',
      );
      expect(seoul, isNotNull);
      expect(seoul!.hour, 15);
      expect(seoul.minute, 30);
    });

    test('salesCallReceptionYmdForCall uses call_date calendar day', () {
      final ymd = salesCallReceptionYmdForCall(
        callDate: '2026-06-18',
        callTime: '15:30:00',
        createdAt: null,
      );
      expect(ymd, '2026-06-18');
    });
  });
}
