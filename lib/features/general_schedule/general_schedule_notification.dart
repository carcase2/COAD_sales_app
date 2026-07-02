import 'package:coad_customer_calls/core/utils/date_seoul.dart';
import 'package:coad_customer_calls/core/utils/schedule_permissions.dart';
import 'package:coad_customer_calls/features/general_schedule/general_schedule_slot_logic.dart';
import 'package:coad_customer_calls/models/general_schedule.dart';

/// 텔레그램·FCM 본사일반 알림용 — 현장·입력자·월 잔여 칸·가장 빠른 빈 칸.
class GeneralScheduleAlarmContext {
  const GeneralScheduleAlarmContext({
    required this.site,
    required this.enteredBy,
    required this.enteredDatesSummary,
    required this.monthLabel,
    required this.monthRemainingSlotsAfterToday,
    this.earliestEmptySlotYmd,
    this.earliestEmptySlotNumber,
  });

  final String site;
  final String enteredBy;
  final String enteredDatesSummary;
  final String monthLabel;
  final int monthRemainingSlotsAfterToday;
  final String? earliestEmptySlotYmd;
  final int? earliestEmptySlotNumber;

  Map<String, dynamic> toPayload() => {
        'site': site,
        'entered_by': enteredBy,
        'entered_dates_summary': enteredDatesSummary,
        'month_label': monthLabel,
        'month_remaining_slots_after_today': monthRemainingSlotsAfterToday,
        if (earliestEmptySlotYmd != null)
          'earliest_empty_slot_date': earliestEmptySlotYmd,
        if (earliestEmptySlotNumber != null)
          'earliest_empty_slot_number': earliestEmptySlotNumber,
        'alarm_lines': alarmLines(),
        'alarm_text': alarmLines().join('\n'),
        'notify_audience': {
          'group_names': kGeneralScheduleAllowedGroupNames,
          'include_admin_role': true,
        },
      };

  List<String> alarmLines() {
    final lines = <String>[
      if (site.trim().isNotEmpty) '현장: ${site.trim()}',
      '입력: $enteredBy · $enteredDatesSummary',
      '$monthLabel 남은 칸(오늘 이후): $monthRemainingSlotsAfterToday칸',
    ];
    if (earliestEmptySlotYmd != null && earliestEmptySlotNumber != null) {
      lines.add(
        '가장 빠른 빈 칸: ${formatYmdFlowLabelKo(earliestEmptySlotYmd!)} '
        '(${earliestEmptySlotNumber}칸)',
      );
    } else {
      lines.add('가장 빠른 빈 칸: 없음');
    }
    return lines;
  }
}

GeneralScheduleAlarmContext buildGeneralScheduleAlarmContext({
  required GeneralScheduleDayGrid grid,
  required GeneralScheduleRecord record,
  required String actorName,
  required String todayYmd,
}) {
  final startParts = record.start.split('-');
  final year = int.parse(startParts[0]);
  final month = int.parse(startParts[1]);

  final earliest = findEarliestAvailableSlot(
    grid,
    fromYmd: todayYmd,
    skipWeekends: true,
  );

  return GeneralScheduleAlarmContext(
    site: record.site.trim(),
    enteredBy: actorName.trim().isEmpty
        ? (record.userName?.trim().isNotEmpty == true
            ? record.userName!.trim()
            : '미지정')
        : actorName.trim(),
    enteredDatesSummary: formatGeneralScheduleEnteredDatesSummary(record),
    monthLabel: '$year년 $month월',
    monthRemainingSlotsAfterToday: countMonthEmptySlotsAfterToday(
      grid,
      year: year,
      month: month,
      todayYmd: todayYmd,
    ),
    earliestEmptySlotYmd: earliest?.ymd,
    earliestEmptySlotNumber: earliest == null ? null : earliest.slotIndex + 1,
  );
}

/// 일정이 차지하는 날짜 요약 (슬롯 기준, 없으면 start~end).
String formatGeneralScheduleEnteredDatesSummary(GeneralScheduleRecord record) {
  final dates = record.slots.map((s) => s.date).toSet().toList()..sort();
  if (dates.isEmpty) {
    if (record.start == record.endDate) {
      return formatYmdFlowLabelKo(record.start);
    }
    return '${formatYmdFlowLabelKo(record.start)} ~ '
        '${formatYmdFlowLabelKo(record.endDate)}';
  }
  if (dates.length == 1) {
    return formatYmdFlowLabelKo(dates.first);
  }
  return '${formatYmdFlowLabelKo(dates.first)} ~ '
      '${formatYmdFlowLabelKo(dates.last)} (${dates.length}일)';
}

/// 해당 월에서 [todayYmd] **다음 날**부터 말일까지 빈 칸 수.
int countMonthEmptySlotsAfterToday(
  GeneralScheduleDayGrid grid, {
  required int year,
  required int month,
  required String todayYmd,
}) {
  final daysInMonth = DateTime(year, month + 1, 0).day;
  var total = 0;
  for (var day = 1; day <= daysInMonth; day++) {
    final ymd =
        '$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
    if (ymd.compareTo(todayYmd) <= 0) continue;
    final slots = grid[ymd] ?? emptyDaySlots();
    total += slots.where((c) => c == null).length;
  }
  return total;
}

Map<String, dynamic> mergeGeneralScheduleTelegramPayload({
  required Map<String, dynamic> base,
  required GeneralScheduleAlarmContext alarm,
}) => {
      ...base,
      ...alarm.toPayload(),
    };
