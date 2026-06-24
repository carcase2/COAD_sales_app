import 'package:coad_customer_calls/core/utils/date_seoul.dart';
import 'package:coad_customer_calls/features/general_schedule/general_schedule_slot_logic.dart';
import 'package:coad_customer_calls/models/general_schedule.dart';
import 'package:flutter/material.dart';

/// 월간 본사일반 칸 통계 (COAD_home `monthStats` — 일 6칸 기준).
class GeneralScheduleMonthStats {
  const GeneralScheduleMonthStats({
    required this.year,
    required this.month,
    required this.daysInMonth,
    required this.totalSlots,
    required this.usedSlots,
    required this.byUser,
  });

  final int year;
  final int month;
  final int daysInMonth;
  final int totalSlots;
  final int usedSlots;
  final List<GeneralScheduleUserSlotCount> byUser;

  int get emptySlots => totalSlots - usedSlots;

  double get occupancyRate =>
      totalSlots == 0 ? 0 : usedSlots / totalSlots;
}

class GeneralScheduleUserSlotCount {
  const GeneralScheduleUserSlotCount({
    required this.name,
    required this.count,
    this.color,
  });

  final String name;
  final int count;
  final String? color;
}

class GeneralScheduleDayStats {
  const GeneralScheduleDayStats({
    required this.totalSlots,
    required this.usedSlots,
  });

  final int totalSlots;
  final int usedSlots;

  int get emptySlots => totalSlots - usedSlots;
}

GeneralScheduleMonthStats computeMonthStats(
  GeneralScheduleDayGrid grid,
  int year,
  int month,
) {
  final daysInMonth = DateTime(year, month + 1, 0).day;
  var usedSlots = 0;
  final userCounts = <String, int>{};
  final userColors = <String, String?>{};

  for (var day = 1; day <= daysInMonth; day++) {
    final ymd =
        '$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
    final slots = grid[ymd] ?? emptyDaySlots();
    for (final cell in slots) {
      if (cell == null) continue;
      usedSlots++;
      final name = cell.userName?.trim().isNotEmpty == true
          ? cell.userName!.trim()
          : '미지정';
      userCounts[name] = (userCounts[name] ?? 0) + 1;
      final rawColor = cell.userColor?.trim();
      if (userColors[name] == null &&
          rawColor != null &&
          rawColor.isNotEmpty) {
        userColors[name] = rawColor;
      }
    }
  }

  final byUser = userCounts.entries
      .map(
        (e) => GeneralScheduleUserSlotCount(
          name: e.key,
          count: e.value,
          color: userColors[e.key],
        ),
      )
      .toList()
    ..sort((a, b) => b.count.compareTo(a.count));

  return GeneralScheduleMonthStats(
    year: year,
    month: month,
    daysInMonth: daysInMonth,
    totalSlots: daysInMonth * kGeneralScheduleSlotsPerDay,
    usedSlots: usedSlots,
    byUser: byUser,
  );
}

GeneralScheduleDayStats computeDayStats(
  GeneralScheduleDayGrid grid,
  String ymd,
) {
  final used = occupiedSlotCount(grid, ymd);
  return GeneralScheduleDayStats(
    totalSlots: kGeneralScheduleSlotsPerDay,
    usedSlots: used,
  );
}

/// 토=파랑, 일=빨강 (선택·오늘 강조 시 null → 기본 스타일 유지).
Color? generalScheduleWeekdayColor(int weekday, {bool muted = false}) {
  final color = switch (weekday) {
    DateTime.saturday => const Color(0xFF1565C0),
    DateTime.sunday => const Color(0xFFC62828),
    _ => null,
  };
  if (color == null) return null;
  return muted ? color.withValues(alpha: 0.75) : color;
}

String formatGeneralScheduleMonthTitle(int year, int month) => '$year년 $month월';

/// 리스트 카드용 공사 기간 — 2일 이상이면 `6/10 ~ 6/12 (2일)` 형태.
String formatGeneralSchedulePeriodLabel({
  required String startYmd,
  required String endYmd,
}) {
  final days = inclusiveDayCount(startYmd, endYmd);
  if (days <= 1) return '';
  return '${formatWeekRangeFlowLabel(startYmd, endYmd)} ($days일)';
}

/// 슬롯 카드·상세용 도어 타입·수량 요약.
String formatGeneralScheduleDoorSummary(GeneralScheduleCell cell) {
  if (cell.models.isNotEmpty) {
    return cell.models
        .map((m) => m.quantity > 0 ? '${m.name}×${m.quantity}' : m.name)
        .join(' · ');
  }
  if (cell.doorTypes.isNotEmpty) {
    return cell.doorTypes.join(' · ');
  }
  return '';
}

/// API `user.color` (#RRGGBB 또는 RRGGBB).
Color? parseGeneralScheduleUserColor(String? raw, {Color? fallback}) {
  if (raw == null || raw.isEmpty) return fallback;
  var s = raw.trim();
  if (s.startsWith('#')) s = s.substring(1);
  if (s.length == 6) {
    final v = int.tryParse(s, radix: 16);
    if (v != null) return Color(0xFF000000 | v);
  }
  return fallback;
}