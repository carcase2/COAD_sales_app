import 'package:coad_customer_calls/core/utils/date_seoul.dart';
import 'package:coad_customer_calls/models/sales_call_draft.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

void main() {
  setUpAll(() {
    tzdata.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Seoul'));
  });

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

    test('UTC wall-clock call_time + created_at → prefer created_at (9h bug)', () {
      // DB UTC now() → call_time 06:30, created_at 06:30Z (= 15:30 KST)
      final seoul = resolveSalesCallReceptionSeoul(
        callDate: '2026-06-18',
        callTime: '06:30:00',
        createdAt: '2026-06-18T06:30:00.000Z',
      );
      expect(seoul, isNotNull);
      expect(seoul!.hour, 15);
      expect(seoul.minute, 30);
    });

    test('matching KST call_time is kept when created_at agrees', () {
      final seoul = resolveSalesCallReceptionSeoul(
        callDate: '2026-06-18',
        callTime: '15:30:00',
        createdAt: '2026-06-18T06:30:00.000Z',
      );
      expect(seoul, isNotNull);
      expect(seoul!.hour, 15);
      expect(seoul.minute, 30);
    });

    test('elapsed label is minutes not 9 hours for corrected reception', () {
      final seoul = resolveSalesCallReceptionSeoul(
        callDate: '2026-06-18',
        callTime: '06:30:00',
        createdAt: '2026-06-18T06:30:00.000Z',
      );
      final label = elapsedLabelSinceReceptionSeoul(
        seoul,
        now: tz.TZDateTime(tz.local, 2026, 6, 18, 15, 35),
      );
      expect(label, '5분 경과');
    });

    test('draft insert includes Seoul call_date and call_time', () {
      final json = const SalesCallDraft(
        customerName: '테스트',
        customerPhone: '010',
        inquiryContent: '문의',
        regionId: '1',
        regionSido: '서울',
        regionName: '강남',
        assignedTo: '담당',
        callDateYmd: '2026-07-13',
        callTimeHms: '18:05:00',
      ).toInsertJson();
      expect(json['call_date'], '2026-07-13');
      expect(json['call_time'], '18:05:00');
    });
  });
}
