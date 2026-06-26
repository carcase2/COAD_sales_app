import 'package:coad_customer_calls/features/general_schedule/general_schedule_notification.dart';
import 'package:coad_customer_calls/features/general_schedule/general_schedule_slot_logic.dart';
import 'package:coad_customer_calls/models/general_schedule.dart';
import 'package:flutter_test/flutter_test.dart';

GeneralScheduleRecord _record({
  required String start,
  String? end,
  List<({String date, int slot})> slots = const [],
}) {
  return GeneralScheduleRecord(
    id: '1',
    site: '현장A',
    start: start,
    endDate: end ?? start,
    userName: '김경덕',
    slots: slots,
  );
}

void main() {
  test('countMonthEmptySlotsAfterToday — 오늘 이후 빈 칸만 집계', () {
    final grid = <String, List<GeneralScheduleCell?>>{
      '2026-06-26': List<GeneralScheduleCell?>.filled(6, null)
        ..[0] = GeneralScheduleCell(
          scheduleId: 'x',
          site: 'A',
          start: '2026-06-26',
          endDate: '2026-06-26',
        ),
      '2026-06-27': emptyDaySlots(),
      '2026-06-28': List<GeneralScheduleCell?>.filled(6, null)
        ..[0] = GeneralScheduleCell(
          scheduleId: 'y',
          site: 'B',
          start: '2026-06-28',
          endDate: '2026-06-28',
        ),
    };

    expect(
      countMonthEmptySlotsAfterToday(
        grid,
        year: 2026,
        month: 6,
        todayYmd: '2026-06-26',
      ),
      // 27일 6칸 + 28일 5칸 + 29~30 각 6칸
      6 + 5 + 6 + 6,
    );
  });

  test('buildGeneralScheduleAlarmContext — 알림 줄 구성', () {
    final grid = buildGeneralScheduleGrid([
      _record(
        start: '2026-06-27',
        slots: [(date: '2026-06-27', slot: 0)],
      ),
    ]);

    final ctx = buildGeneralScheduleAlarmContext(
      grid: grid,
      record: _record(
        start: '2026-06-27',
        slots: [(date: '2026-06-27', slot: 0)],
      ),
      actorName: '김경덕 이사',
      todayYmd: '2026-06-26',
    );

    expect(ctx.enteredBy, '김경덕 이사');
    expect(ctx.enteredDatesSummary, '6월 27일 (토)');
    expect(ctx.monthRemainingSlotsAfterToday, greaterThan(0));
    expect(ctx.earliestEmptySlotYmd, '2026-06-26');
    expect(ctx.alarmLines().first, contains('김경덕 이사'));
    expect(ctx.alarmLines()[1], contains('남은 칸(오늘 이후)'));
  });
}
