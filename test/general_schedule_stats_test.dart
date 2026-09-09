import 'package:coad_customer_calls/core/utils/date_seoul.dart';
import 'package:coad_customer_calls/features/general_schedule/general_schedule_slot_logic.dart';
import 'package:coad_customer_calls/features/general_schedule/general_schedule_stats.dart';
import 'package:coad_customer_calls/models/general_schedule.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('computeMonthStats — 일 8칸 기준 합산', () {
    final grid = buildGeneralScheduleGrid([]);
    // 2026-06 has 30 days
    final stats = computeMonthStats(grid, 2026, 6);
    expect(stats.daysInMonth, 30);
    expect(stats.totalSlots, 30 * kGeneralScheduleSlotsPerDay);
    expect(stats.usedSlots, 0);
    expect(stats.emptySlots, stats.totalSlots);
  });

  test('computeMonthStats — 담당자별 색상 집계', () {
    final grid = buildGeneralScheduleGrid([
      GeneralScheduleRecord(
        id: 'a',
        site: 'A',
        start: '2026-06-10',
        endDate: '2026-06-10',
        userName: '김철수',
        userColor: '#FF5722',
        slots: [(date: '2026-06-10', slot: 0)],
      ),
      GeneralScheduleRecord(
        id: 'b',
        site: 'B',
        start: '2026-06-11',
        endDate: '2026-06-11',
        userName: '이영희',
        userColor: '1565C0',
        slots: [(date: '2026-06-11', slot: 1)],
      ),
    ]);

    final stats = computeMonthStats(grid, 2026, 6);
    final kim = stats.byUser.firstWhere((u) => u.name == '김철수');
    final lee = stats.byUser.firstWhere((u) => u.name == '이영희');

    expect(kim.color, '#FF5722');
    expect(lee.color, '1565C0');
    expect(
      parseGeneralScheduleUserColor(kim.color),
      const Color(0xFFFF5722),
    );
  });

  test('formatGeneralSchedulePeriodLabel', () {
    expect(
      formatGeneralSchedulePeriodLabel(
        startYmd: '2026-06-10',
        endYmd: '2026-06-10',
      ),
      '',
    );
    expect(
      formatGeneralSchedulePeriodLabel(
        startYmd: '2026-06-10',
        endYmd: '2026-06-12',
      ),
      '6/10 ~ 6/12 (3일)',
    );
  });

  test('formatGeneralScheduleDoorSummary', () {
    const withModels = GeneralScheduleCell(
      scheduleId: 'a',
      site: 'A',
      start: '2026-06-01',
      endDate: '2026-06-01',
      models: [
        ScheduleModelEntry(name: 'ABS', quantity: 3),
        ScheduleModelEntry(name: 'AUTO', quantity: 1),
      ],
    );
    expect(
      formatGeneralScheduleDoorSummary(withModels),
      'ABS×3 · AUTO×1',
    );

    const codesOnly = GeneralScheduleCell(
      scheduleId: 'b',
      site: 'B',
      start: '2026-06-02',
      endDate: '2026-06-02',
      doorTypes: ['ABS', 'AUTO'],
    );
    expect(formatGeneralScheduleDoorSummary(codesOnly), 'ABS · AUTO');
  });

  test('computeDayStats', () {
    final grid = <String, List<GeneralScheduleCell?>>{
      '2026-06-15': [
        null,
        GeneralScheduleCell(
          scheduleId: 'a',
          site: 'A',
          start: '2026-06-15',
          endDate: '2026-06-15',
        ),
        null,
        null,
        null,
        null,
        null,
        null,
      ],
    };
    final day = computeDayStats(grid, '2026-06-15');
    expect(day.usedSlots, 1);
    expect(day.emptySlots, 7);
  });

  test('normalizeGeneralScheduleDoorTypeKey — OS/HO/HS 정규화', () {
    expect(normalizeGeneralScheduleDoorTypeKey(['O', 'S']), 'SO');
    expect(normalizeGeneralScheduleDoorTypeKey(['H', 'O']), 'OH');
    expect(normalizeGeneralScheduleDoorTypeKey(['H', 'S']), 'SH');
    expect(normalizeGeneralScheduleDoorTypeKey(['H', 'O', 'S']), 'HOS');
    expect(normalizeGeneralScheduleDoorTypeKey(['S']), 'S');
  });

  test('generalScheduleBarColor — 담당자별·도어타입별', () {
    const cell = GeneralScheduleCell(
      scheduleId: 'a',
      site: '넥센타이',
      start: '2026-07-28',
      endDate: '2026-08-01',
      userName: '김경덕',
      userColor: '#F59E0B',
      doorTypes: ['S', 'O'],
    );
    expect(
      generalScheduleBarColor(
        cell: cell,
        mode: GeneralScheduleColorMode.assignee,
        fallback: const Color(0xFF2563EB),
        orderedAssignees: const ['김경덕', '이상수'],
      ),
      const Color(0xFFF59E0B),
    );
    expect(
      generalScheduleBarColor(
        cell: cell,
        mode: GeneralScheduleColorMode.doorType,
        fallback: const Color(0xFF2563EB),
      ),
      kGeneralScheduleDoorTypeColors['SO'],
    );
  });

  test('generalScheduleAssigneeAccent — DB 색을 우선하고 달이 바뀌어도 유지', () {
    final fromDb = generalScheduleAssigneeAccent(
      name: '김경덕',
      userColor: '#1D4ED8',
      orderedAssignees: const ['김경덕', '이상수'],
    );
    expect(fromDb, const Color(0xFF1D4ED8));
    expect(
      generalScheduleAssigneeAccent(
        name: '김경덕',
        userColor: '#1D4ED8',
        orderedAssignees: const ['이상수', '홍길동', '김경덕'],
      ),
      fromDb,
    );

    final hashed = generalScheduleAssigneeAccent(
      name: '김경덕',
      orderedAssignees: const ['김경덕', '이상수'],
    );
    final hashedLater = generalScheduleAssigneeAccent(
      name: '김경덕',
      orderedAssignees: const ['이상수', '홍길동', '김경덕'],
    );
    expect(hashed, hashedLater);
    expect(hashed, isNot(generalScheduleAssigneeAccent(name: '이상수')));
    expect(hashed, isNot(fromDb));
  });

  test('seoulSundayWeekRangeContaining — 일~토', () {
    final range = seoulSundayWeekRangeContaining('2026-07-28');
    expect(range.$1, '2026-07-26');
    expect(range.$2, '2026-08-01');
    expect(
      seoulSundayWeekDays('2026-07-29'),
      [
        '2026-07-26',
        '2026-07-27',
        '2026-07-28',
        '2026-07-29',
        '2026-07-30',
        '2026-07-31',
        '2026-08-01',
      ],
    );
    expect(
      formatMonthDayRangeKo(range.$1, range.$2),
      '7월 26일 - 8월 1일',
    );
  });
}