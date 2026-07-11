import 'package:coad_customer_calls/features/general_schedule/general_schedule_slot_logic.dart';
import 'package:coad_customer_calls/models/general_schedule.dart';
import 'package:flutter_test/flutter_test.dart';

GeneralScheduleRecord _record({
  required String id,
  required String site,
  required List<({String date, int slot})> slots,
}) {
  return GeneralScheduleRecord(
    id: id,
    site: site,
    start: '2026-06-01',
    endDate: '2026-06-03',
    slots: slots,
  );
}

void main() {
  test('buildGeneralScheduleGrid — 날짜별 8칸 배치', () {
    final grid = buildGeneralScheduleGrid([
      _record(
        id: 'a',
        site: '현장A',
        slots: [
          (date: '2026-06-01', slot: 0),
          (date: '2026-06-02', slot: 0),
        ],
      ),
    ]);

    expect(grid['2026-06-01']![0]?.site, '현장A');
    expect(grid['2026-06-01']![1], isNull);
    expect(grid['2026-06-02']![0]?.site, '현장A');
    expect(grid['2026-06-01']!.length, kGeneralScheduleSlotsPerDay);
  });

  test('assignSingleTeamSlots — 연속 한 줄 우선', () {
    final grid = buildGeneralScheduleGrid([
      _record(
        id: 'busy',
        site: '점유',
        slots: [(date: '2026-06-01', slot: 0)],
      ),
    ]);

    final result = assignSingleTeamSlots(
      grid: grid,
      startYmd: '2026-06-01',
      endYmd: '2026-06-02',
    );

    expect(result.ok, isTrue);
    expect(result.slotMap['2026-06-01'], 1);
    expect(result.slotMap['2026-06-02'], 1);
  });

  test('assignSingleTeamSlots — 가득 찬 날 실패', () {
    final slots = <({String date, int slot})>[];
    for (var i = 0; i < kGeneralScheduleSlotsPerDay; i++) {
      slots.add((date: '2026-06-01', slot: i));
    }
    final grid = buildGeneralScheduleGrid([
      _record(id: 'full', site: '만석', slots: slots),
    ]);

    final result = assignSingleTeamSlots(
      grid: grid,
      startYmd: '2026-06-01',
      endYmd: '2026-06-01',
    );

    expect(result.ok, isFalse);
    expect(result.errorMessage, contains('같은 칸'));
  });

  test('assignMultiTeamSlots — 같은 날 여러 팀', () {
    final grid = <String, List<GeneralScheduleCell?>>{};

    final result = assignMultiTeamSlots(
      grid: grid,
      startYmd: '2026-06-10',
      endYmd: '2026-06-12',
      teamCount: 2,
      dayCount: 2,
    );

    expect(result.ok, isTrue);
    expect(result.teamSlotMap['2026-06-10']?.length, 2);
    expect(
      result.teamSlotMap['2026-06-10']![0],
      isNot(result.teamSlotMap['2026-06-10']![1]),
    );
  });

  test('firstEmptySlotIndex · isGeneralScheduleDayFull', () {
    final full = List<GeneralScheduleCell?>.filled(
      kGeneralScheduleSlotsPerDay,
      GeneralScheduleCell(
        scheduleId: 'x',
        site: 'X',
        start: '2026-06-01',
        endDate: '2026-06-01',
      ),
    );
    expect(firstEmptySlotIndex(full), isNull);
    expect(
      isGeneralScheduleDayFull({ '2026-06-01': full }, '2026-06-01'),
      isTrue,
    );

    final partial = emptyDaySlots();
    partial[2] = GeneralScheduleCell(
      scheduleId: 'a',
      site: 'A',
      start: '2026-06-02',
      endDate: '2026-06-02',
    );
    expect(firstEmptySlotIndex(partial), 0);
    expect(
      isGeneralScheduleDayFull({ '2026-06-02': partial }, '2026-06-02'),
      isFalse,
    );
  });

  test('occupiedSlotCount', () {
    final grid = buildGeneralScheduleGrid([
      _record(
        id: 'a',
        site: 'A',
        slots: [
          (date: '2026-06-05', slot: 0),
          (date: '2026-06-05', slot: 2),
        ],
      ),
    ]);
    expect(occupiedSlotCount(grid, '2026-06-05'), 2);
    expect(occupiedSlotCount(grid, '2026-06-06'), 0);
  });

  test('inclusiveDayCount', () {
    expect(inclusiveDayCount('2026-06-01', '2026-06-01'), 1);
    expect(inclusiveDayCount('2026-06-01', '2026-06-03'), 3);
  });

  test('assignSingleTeamSlots — 같은 칸 불가 시 기본은 실패(날짜별 분산 안 함)', () {
    // 각 칸(0~7)이 기간 내 하루씩 막혀 연속 같은 칸이 없음 — 날짜별 분산만 가능.
    final grid = buildGeneralScheduleGrid([
      _record(
        id: 'block',
        site: '막음',
        slots: [
          (date: '2026-06-01', slot: 0),
          (date: '2026-06-01', slot: 3),
          (date: '2026-06-01', slot: 6),
          (date: '2026-06-02', slot: 1),
          (date: '2026-06-02', slot: 4),
          (date: '2026-06-02', slot: 7),
          (date: '2026-06-03', slot: 2),
          (date: '2026-06-03', slot: 5),
        ],
      ),
    ]);

    final strict = assignSingleTeamSlots(
      grid: grid,
      startYmd: '2026-06-01',
      endYmd: '2026-06-03',
    );
    expect(strict.ok, isFalse);

    final loose = assignSingleTeamSlots(
      grid: grid,
      startYmd: '2026-06-01',
      endYmd: '2026-06-03',
      allowPerDayFallback: true,
    );
    expect(loose.ok, isTrue);
  });

  test('findEarliestAvailableSlot — 오늘부터 빈 칸 탐색', () {
    final partial = emptyDaySlots();
    partial[0] = GeneralScheduleCell(
      scheduleId: 'a',
      site: 'A',
      start: '2026-06-24',
      endDate: '2026-06-24',
    );
    partial[2] = GeneralScheduleCell(
      scheduleId: 'b',
      site: 'B',
      start: '2026-06-24',
      endDate: '2026-06-24',
    );
    final grid = <String, List<GeneralScheduleCell?>>{
      '2026-06-24': partial,
    };

    final first = findEarliestAvailableSlot(
      grid,
      fromYmd: '2026-06-24',
      fromSlotIndex: 0,
    );
    expect(first?.ymd, '2026-06-24');
    expect(first?.slotIndex, 1);

    final nextDay = findEarliestAvailableSlot(
      grid,
      fromYmd: '2026-06-25',
      fromSlotIndex: 0,
    );
    expect(nextDay?.ymd, '2026-06-25');
    expect(nextDay?.slotIndex, 0);

    final fullDay = List<GeneralScheduleCell?>.filled(
      kGeneralScheduleSlotsPerDay,
      GeneralScheduleCell(
        scheduleId: 'x',
        site: 'X',
        start: '2026-06-24',
        endDate: '2026-06-24',
      ),
    );
    final fullGrid = {'2026-06-24': fullDay};
    final tomorrow = findEarliestAvailableSlot(
      fullGrid,
      fromYmd: '2026-06-24',
      fromSlotIndex: 0,
    );
    expect(tomorrow?.ymd, '2026-06-25');
    expect(tomorrow?.slotIndex, 0);
  });

  test('findPreviousAvailableDaySlot — 이전 날짜 빈 칸 탐색', () {
    final grid = <String, List<GeneralScheduleCell?>>{
      '2026-06-23': List<GeneralScheduleCell?>.filled(
        kGeneralScheduleSlotsPerDay,
        null,
      ),
      '2026-06-24': List<GeneralScheduleCell?>.filled(
        kGeneralScheduleSlotsPerDay,
        GeneralScheduleCell(
          scheduleId: 'x',
          site: 'X',
          start: '2026-06-24',
          endDate: '2026-06-24',
        ),
      ),
    };

    final prev = findPreviousAvailableDaySlot(
      grid,
      current: const EarliestAvailableSlot(
        ymd: '2026-06-25',
        slotIndex: 0,
      ),
      minYmd: '2026-06-23',
    );
    expect(prev?.ymd, '2026-06-23');
    expect(prev?.slotIndex, 0);

    final none = findPreviousAvailableDaySlot(
      grid,
      current: const EarliestAvailableSlot(
        ymd: '2026-06-23',
        slotIndex: 0,
      ),
      minYmd: '2026-06-23',
    );
    expect(none, isNull);
  });

  test('findNextAvailableDaySlot — 다음 날짜 빈 칸 탐색', () {
    final fullDay = List<GeneralScheduleCell?>.filled(
      kGeneralScheduleSlotsPerDay,
      GeneralScheduleCell(
        scheduleId: 'x',
        site: 'X',
        start: '2026-06-24',
        endDate: '2026-06-24',
      ),
    );
    final grid = <String, List<GeneralScheduleCell?>>{
      '2026-06-24': fullDay,
      '2026-06-25': List<GeneralScheduleCell?>.from(fullDay),
      '2026-06-26': List<GeneralScheduleCell?>.filled(
        kGeneralScheduleSlotsPerDay,
        null,
      ),
    };

    final next = findNextAvailableDaySlot(
      grid,
      current: const EarliestAvailableSlot(
        ymd: '2026-06-23',
        slotIndex: 2,
      ),
    );
    expect(next?.ymd, '2026-06-26');
    expect(next?.slotIndex, 2);

    final skipFull = findNextAvailableDaySlot(
      grid,
      current: const EarliestAvailableSlot(
        ymd: '2026-06-24',
        slotIndex: 0,
      ),
    );
    expect(skipFull?.ymd, '2026-06-26');
    expect(skipFull?.slotIndex, 0);
  });

  test('findNextAvailableDaySlot — 금요일 다음은 월요일(주말 제외)', () {
    final empty = List<GeneralScheduleCell?>.filled(
      kGeneralScheduleSlotsPerDay,
      null,
    );
    final grid = <String, List<GeneralScheduleCell?>>{
      '2026-07-03': empty, // Fri
      '2026-07-06': empty, // Mon
    };

    final next = findNextAvailableDaySlot(
      grid,
      current: const EarliestAvailableSlot(
        ymd: '2026-07-03',
        slotIndex: 1,
      ),
      skipWeekends: true,
    );
    expect(next?.ymd, '2026-07-06');
    expect(next?.slotIndex, 1);
  });

  test('findPreviousAvailableDaySlot — 월요일 이전은 금요일(주말 제외)', () {
    final empty = List<GeneralScheduleCell?>.filled(
      kGeneralScheduleSlotsPerDay,
      null,
    );
    final grid = <String, List<GeneralScheduleCell?>>{
      '2026-07-03': empty, // Fri
      '2026-07-06': empty, // Mon
    };

    final prev = findPreviousAvailableDaySlot(
      grid,
      current: const EarliestAvailableSlot(
        ymd: '2026-07-06',
        slotIndex: 2,
      ),
      minYmd: '2026-07-03',
      skipWeekends: true,
    );
    expect(prev?.ymd, '2026-07-03');
    expect(prev?.slotIndex, 2);
  });

  test('findEarliestAvailableSlot — 주말 시작일은 월요일부터 탐색', () {
    final empty = List<GeneralScheduleCell?>.filled(
      kGeneralScheduleSlotsPerDay,
      null,
    );
    final grid = <String, List<GeneralScheduleCell?>>{
      '2026-07-06': empty, // Mon
    };

    final slot = findEarliestAvailableSlot(
      grid,
      fromYmd: '2026-07-04', // Sat
      skipWeekends: true,
    );
    expect(slot?.ymd, '2026-07-06');
    expect(slot?.slotIndex, 0);
  });

  test('assignFixedSlotRow — 지정 칸 배치·충돌', () {
    final grid = buildGeneralScheduleGrid([
      _record(
        id: 'a',
        site: '점유',
        slots: [(date: '2026-06-10', slot: 2)],
      ),
    ]);

    final ok = assignFixedSlotRow(
      grid: grid,
      startYmd: '2026-06-10',
      endYmd: '2026-06-12',
      slotIndex: 1,
    );
    expect(ok.ok, isTrue);
    expect(ok.slotMap['2026-06-10'], 1);
    expect(ok.slotMap['2026-06-11'], 1);

    final fail = assignFixedSlotRow(
      grid: grid,
      startYmd: '2026-06-10',
      endYmd: '2026-06-10',
      slotIndex: 2,
    );
    expect(fail.ok, isFalse);
  });
}