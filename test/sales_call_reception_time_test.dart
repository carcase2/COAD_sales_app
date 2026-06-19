import 'package:coad_customer_calls/core/utils/date_seoul.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('sales call reception time (UTC → Seoul)', () {
    test('naive call_date + call_time from DB adds 9 hours', () {
      final seoul = resolveSalesCallReceptionSeoul(
        callDate: '2026-06-18',
        callTime: '06:30:00',
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

    test('formatSalesCallReceptionDateTime uses resolved Seoul time', () {
      final seoul = resolveSalesCallReceptionSeoul(
        callDate: '2026-06-18',
        callTime: '06:30:00',
        createdAt: null,
      );
      expect(seoul?.year, 2026);
      expect(seoul?.month, 6);
      expect(seoul?.day, 18);
      expect(seoul?.hour, 15);
      expect(seoul?.minute, 30);
    });

    test('salesCallReceptionYmdForCall uses Seoul calendar date', () {
      final ymd = salesCallReceptionYmdForCall(
        callDate: '2026-06-18',
        callTime: '06:30:00',
        createdAt: null,
      );
      expect(ymd, '2026-06-18');
    });
  });
}
