import 'package:coad_customer_calls/features/general_schedule/general_schedule_slot_logic.dart';
import 'package:coad_customer_calls/features/general_schedule/general_schedule_stats.dart';
import 'package:coad_customer_calls/models/general_schedule.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('computeMonthStats — 일 6칸 기준 합산', () {
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
}