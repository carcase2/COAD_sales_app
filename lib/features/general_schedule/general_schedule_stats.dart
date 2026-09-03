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

/// 담당자별 달력 색 — 서로 잘 구분되도록 채도·명도를 맞춘 고정 팔레트.
/// (DB `users.color`가 비슷하거나 비어 있어도 칸·필터 칩이 섞이지 않게 한다.)
const List<Color> kGeneralScheduleAssigneePalette = <Color>[
  Color(0xFF1D4ED8), // blue
  Color(0xFFDC2626), // red
  Color(0xFF059669), // emerald
  Color(0xFFD97706), // amber
  Color(0xFF7C3AED), // violet
  Color(0xFFDB2777), // pink
  Color(0xFF0F766E), // teal
  Color(0xFFEA580C), // orange
  Color(0xFF4F46E5), // indigo
  Color(0xFF65A30D), // lime
  Color(0xFF0891B2), // cyan
  Color(0xFFBE123C), // rose
];

const Color kGeneralScheduleAssigneeUnset = Color(0xFF6B7280);

int _stableAssigneePaletteIndex(String name) {
  // FNV-1a 변형 — 이름만으로도 팔레트에 고르게 분산.
  var hash = 2166136261;
  for (final unit in name.codeUnits) {
    hash ^= unit;
    hash = (hash * 16777619) & 0x7fffffff;
  }
  return hash;
}

/// 담당자 표시색. [orderedAssignees]가 있으면 가나다·등록 순으로 팔레트를 나눠
/// 같은 달력 안의 담당자가 최대한 다른 색을 쓰게 한다.
Color generalScheduleAssigneeAccent({
  required String name,
  String? userColor,
  List<String>? orderedAssignees,
  Color? fallback,
}) {
  final n = name.trim();
  if (n.isEmpty || n == '미지정' || n == '전체') {
    return fallback ?? kGeneralScheduleAssigneeUnset;
  }

  final ordered = (orderedAssignees ?? const <String>[])
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty && e != '전체' && e != '미지정')
      .toList();
  // 중복 이름 제거·순서 유지
  final unique = <String>[];
  final seen = <String>{};
  for (final e in ordered) {
    if (seen.add(e)) unique.add(e);
  }

  final index = unique.isEmpty
      ? _stableAssigneePaletteIndex(n)
      : (() {
          final i = unique.indexOf(n);
          return i >= 0 ? i : _stableAssigneePaletteIndex(n);
        })();

  return kGeneralScheduleAssigneePalette[
      index % kGeneralScheduleAssigneePalette.length];
}

/// 주간 달력 칸 색 — 담당자별 / 도어타입별 (COAD_home Calendar.tsx).
enum GeneralScheduleColorMode { assignee, doorType }

const Color kGeneralScheduleDoorTypeFallback = Color(0xFF6B7280);

const Map<String, Color> kGeneralScheduleDoorTypeColors = {
  'S': Color(0xFF3B82F6),
  'O': Color(0xFF10B981),
  'H': Color(0xFFF59E0B),
  'SO': Color(0xFF8B5CF6),
  'SH': Color(0xFFEF4444),
  'OH': Color(0xFF14B8A6),
  'HOS': Color(0xFF6366F1),
  'VISIT': Color(0xFFEF4444),
};

/// COAD_home `normalizeDoorTypes` — 코드 정렬 후 OS→SO 등 정규화.
String normalizeGeneralScheduleDoorTypeKey(Iterable<String> doorTypes) {
  final codes = doorTypes
      .map((e) => e.trim().toUpperCase())
      .where((e) => e.isNotEmpty)
      .toList()
    ..sort();
  if (codes.isEmpty) return '';
  final joined = codes.join();
  return switch (joined) {
    'OS' => 'SO',
    'HO' => 'OH',
    'HS' => 'SH',
    _ => joined,
  };
}

Color generalScheduleDoorTypeBarColor(GeneralScheduleCell cell) {
  for (final model in cell.models) {
    final fromModel = parseGeneralScheduleUserColor(model.color);
    if (fromModel != null) return fromModel;
  }
  final key = normalizeGeneralScheduleDoorTypeKey(cell.doorTypes);
  if (key.isEmpty) return kGeneralScheduleDoorTypeFallback;
  return kGeneralScheduleDoorTypeColors[key] ?? kGeneralScheduleDoorTypeFallback;
}

Color generalScheduleBarColor({
  required GeneralScheduleCell cell,
  required GeneralScheduleColorMode mode,
  required Color fallback,
  List<String>? orderedAssignees,
}) {
  if (mode == GeneralScheduleColorMode.assignee) {
    final name = (cell.userName ?? '').trim();
    return generalScheduleAssigneeAccent(
      name: name.isEmpty ? '미지정' : name,
      userColor: cell.userColor,
      orderedAssignees: orderedAssignees,
      fallback: fallback,
    );
  }
  return generalScheduleDoorTypeBarColor(cell);
}