import 'package:coad_customer_calls/core/utils/date_seoul.dart';
import 'package:coad_customer_calls/models/general_schedule.dart';

/// COAD_home 본사일반 달력 — 하루 6칸 (slot 0~5).
const int kGeneralScheduleSlotsPerDay = 6;

const List<int> kGeneralScheduleSlotIndices = [0, 1, 2, 3, 4, 5];

typedef GeneralScheduleDayGrid = Map<String, List<GeneralScheduleCell?>>;

List<GeneralScheduleCell?> emptyDaySlots() =>
    List<GeneralScheduleCell?>.filled(kGeneralScheduleSlotsPerDay, null);

/// 항상 6칸 리스트로 정규화 (짧은 리스트·null 방어).
List<GeneralScheduleCell?> normalizeGeneralScheduleDaySlots(
  List<GeneralScheduleCell?>? raw,
) {
  final out = emptyDaySlots();
  if (raw == null || raw.isEmpty) return out;
  for (var i = 0; i < raw.length && i < kGeneralScheduleSlotsPerDay; i++) {
    out[i] = raw[i];
  }
  return out;
}

/// API 목록 → 날짜별 6칸 그리드 (page.tsx `fetchSchedules`와 동일).
GeneralScheduleDayGrid buildGeneralScheduleGrid(List<GeneralScheduleRecord> rows) {
  final grid = <String, List<GeneralScheduleCell?>>{};
  final teamCountById = <String, int>{};

  for (final item in rows) {
    final perDate = <String, int>{};
    for (final s in item.slots) {
      perDate[s.date] = (perDate[s.date] ?? 0) + 1;
    }
    final maxPerDay = perDate.values.isEmpty
        ? 1
        : perDate.values.reduce((a, b) => a > b ? a : b);
    teamCountById[item.id] = maxPerDay;
  }

  for (final item in rows) {
    final teamCount = teamCountById[item.id] ?? 1;
    for (final slotInfo in item.slots) {
      final dateStr = slotInfo.date;
      grid.putIfAbsent(dateStr, emptyDaySlots);
      final slot = slotInfo.slot;
      if (slot < 0 || slot >= kGeneralScheduleSlotsPerDay) continue;
      grid[dateStr]![slot] = GeneralScheduleCell(
        scheduleId: item.id,
        site: item.site,
        start: item.start,
        endDate: item.endDate,
        userName: item.userName,
        userColor: item.userColor,
        doorTypes: item.doorTypes,
        models: item.models,
        teamCount: teamCount,
      );
    }
  }
  return grid;
}

int occupiedSlotCount(GeneralScheduleDayGrid grid, String ymd) {
  final day = grid[ymd];
  if (day == null) return 0;
  return day.where((c) => c != null).length;
}

bool isGeneralScheduleDayFull(GeneralScheduleDayGrid grid, String ymd) =>
    occupiedSlotCount(grid, ymd) >= kGeneralScheduleSlotsPerDay;

/// 첫 빈 칸 인덱스(0~5). 없으면 null.
int? firstEmptySlotIndex(List<GeneralScheduleCell?> daySlots) {
  for (var i = 0; i < daySlots.length; i++) {
    if (daySlots[i] == null) return i;
  }
  return null;
}

/// 가장 빠른 빈 칸 (날짜·칸). [fromYmd]·[fromSlotIndex]부터 앞으로 탐색.
class EarliestAvailableSlot {
  const EarliestAvailableSlot({required this.ymd, required this.slotIndex});

  final String ymd;
  final int slotIndex;
}

EarliestAvailableSlot? findEarliestAvailableSlot(
  GeneralScheduleDayGrid grid, {
  required String fromYmd,
  int fromSlotIndex = 0,
  int maxDays = 366,
  bool skipWeekends = false,
}) {
  if (skipWeekends) {
    fromYmd = ensureWorkdayForward(fromYmd);
  }
  if (fromSlotIndex < 0) fromSlotIndex = 0;
  if (fromSlotIndex >= kGeneralScheduleSlotsPerDay) {
    fromYmd = skipWeekends ? nextWorkdayYmd(fromYmd) : _addDaysYmd(fromYmd, 1);
    fromSlotIndex = 0;
  }

  var currentYmd = fromYmd;
  var slotStart = fromSlotIndex;

  for (var day = 0; day < maxDays; day++) {
    final slots = grid[currentYmd] ?? emptyDaySlots();
    for (var i = slotStart; i < kGeneralScheduleSlotsPerDay; i++) {
      if (slots[i] == null) {
        return EarliestAvailableSlot(ymd: currentYmd, slotIndex: i);
      }
    }
    slotStart = 0;
    currentYmd = skipWeekends
        ? nextWorkdayYmd(currentYmd)
        : _addDaysYmd(currentYmd, 1);
  }
  return null;
}

/// [current] 이전 날짜(당일 제외)부터 거꾸로 탐색해 첫 빈 칸.
/// 같은 칸 번호가 비어 있으면 우선 선택.
EarliestAvailableSlot? findPreviousAvailableDaySlot(
  GeneralScheduleDayGrid grid, {
  required EarliestAvailableSlot current,
  required String minYmd,
  bool skipWeekends = false,
}) {
  var searchYmd = skipWeekends
      ? previousWorkdayYmd(current.ymd)
      : _addDaysYmd(current.ymd, -1);
  while (searchYmd.compareTo(minYmd) >= 0) {
    final slots = grid[searchYmd] ?? emptyDaySlots();
    if (slots[current.slotIndex] == null) {
      return EarliestAvailableSlot(
        ymd: searchYmd,
        slotIndex: current.slotIndex,
      );
    }
    for (var i = kGeneralScheduleSlotsPerDay - 1; i >= 0; i--) {
      if (slots[i] == null) {
        return EarliestAvailableSlot(ymd: searchYmd, slotIndex: i);
      }
    }
    searchYmd = skipWeekends
        ? previousWorkdayYmd(searchYmd)
        : _addDaysYmd(searchYmd, -1);
  }
  return null;
}

/// [current] 다음 날짜(당일 제외)부터 첫 빈 칸. 같은 칸 번호 우선.
EarliestAvailableSlot? findNextAvailableDaySlot(
  GeneralScheduleDayGrid grid, {
  required EarliestAvailableSlot current,
  int maxDays = 366,
  bool skipWeekends = false,
}) {
  var searchYmd = skipWeekends
      ? nextWorkdayYmd(current.ymd)
      : _addDaysYmd(current.ymd, 1);
  for (var day = 0; day < maxDays; day++) {
    final slots = grid[searchYmd] ?? emptyDaySlots();
    if (slots[current.slotIndex] == null) {
      return EarliestAvailableSlot(
        ymd: searchYmd,
        slotIndex: current.slotIndex,
      );
    }
    final idx = firstEmptySlotIndex(slots);
    if (idx != null) {
      return EarliestAvailableSlot(ymd: searchYmd, slotIndex: idx);
    }
    searchYmd = skipWeekends
        ? nextWorkdayYmd(searchYmd)
        : _addDaysYmd(searchYmd, 1);
  }
  return null;
}

String _addDaysYmd(String ymd, int days) =>
    _ymd(DateTime.parse(ymd).add(Duration(days: days)));

/// 지정 칸(0~5)에 기간 전체 배치 — 빈 칸 탭 등록·칸 고정 시 사용.
SlotAssignmentResult assignFixedSlotRow({
  required GeneralScheduleDayGrid grid,
  required String startYmd,
  required String endYmd,
  required int slotIndex,
  String? editingScheduleId,
}) {
  if (slotIndex < 0 || slotIndex >= kGeneralScheduleSlotsPerDay) {
    return SlotAssignmentResult.failure('유효하지 않은 칸입니다.');
  }

  final slotMap = <String, int>{};
  var current = DateTime.parse(startYmd);
  final end = DateTime.parse(endYmd);

  while (!current.isAfter(end)) {
    final dateStr = _ymd(current);
    final day = grid[dateStr] ?? emptyDaySlots();
    final occupant = day[slotIndex];
    if (occupant != null &&
        (editingScheduleId == null ||
            occupant.scheduleId != editingScheduleId)) {
      return SlotAssignmentResult.failure(
        '$dateStr · ${slotIndex + 1}칸이 이미 사용 중입니다.',
      );
    }
    slotMap[dateStr] = slotIndex;
    current = current.add(const Duration(days: 1));
  }
  return SlotAssignmentResult.success(slotMap);
}

/// 단일 팀 일정 slot 배치 — 기간 전체 **같은 칸** 우선 (COAD_home 웹과 동일).
///
/// [allowPerDayFallback]이 false(기본)이면 날짜마다 다른 칸으로 쪼개지 않고 실패한다.
SlotAssignmentResult assignSingleTeamSlots({
  required GeneralScheduleDayGrid grid,
  required String startYmd,
  required String endYmd,
  String? editingScheduleId,
  bool allowPerDayFallback = false,
}) {
  final slotMap = <String, int>{};
  final start = DateTime.parse(startYmd);
  final end = DateTime.parse(endYmd);

  for (final slot in kGeneralScheduleSlotIndices) {
    var canUse = true;
    var current = start;
    while (!current.isAfter(end)) {
      final dateStr = _ymd(current);
      final day = List<GeneralScheduleCell?>.from(
        grid[dateStr] ?? emptyDaySlots(),
      );
      final occupant = day[slot];
      if (occupant != null &&
          (editingScheduleId == null || occupant.scheduleId != editingScheduleId)) {
        canUse = false;
        break;
      }
      current = current.add(const Duration(days: 1));
    }
    if (canUse) {
      current = start;
      while (!current.isAfter(end)) {
        slotMap[_ymd(current)] = slot;
        current = current.add(const Duration(days: 1));
      }
      return SlotAssignmentResult.success(slotMap);
    }
  }

  if (!allowPerDayFallback) {
    final days = inclusiveDayCount(startYmd, endYmd);
    final dayLabel = days > 1 ? '$days일 ' : '';
    return SlotAssignmentResult.failure(
      '${dayLabel}기간 전체에 같은 칸으로 연속 배치할 수 없습니다.',
    );
  }

  var cursor = start;
  while (!cursor.isAfter(end)) {
    final dateStr = _ymd(cursor);
    final day = List<GeneralScheduleCell?>.from(
      grid[dateStr] ?? emptyDaySlots(),
    );
    int? picked;
    for (final slot in kGeneralScheduleSlotIndices) {
      final occupant = day[slot];
      if (occupant == null ||
          (editingScheduleId != null &&
              occupant.scheduleId == editingScheduleId)) {
        picked = slot;
        break;
      }
    }
    if (picked == null) {
      return SlotAssignmentResult.failure(
        '$dateStr 날짜에 빈 칸이 없습니다.',
      );
    }
    slotMap[dateStr] = picked;
    cursor = cursor.add(const Duration(days: 1));
  }
  return SlotAssignmentResult.success(slotMap);
}

/// 다중 팀 — 날짜마다 teamCount개의 서로 다른 slot (page.tsx teamSlotMap).
SlotAssignmentResult assignMultiTeamSlots({
  required GeneralScheduleDayGrid grid,
  required String startYmd,
  required String endYmd,
  required int teamCount,
  required int dayCount,
  String? editingScheduleId,
  Map<String, List<int>>? existingSlotsByDate,
}) {
  final slotMap = <String, int>{};
  final teamSlotMap = <String, List<int>>{};
  final start = DateTime.parse(startYmd);
  final rangeEnd = start.add(Duration(days: dayCount - 1));
  final end = DateTime.parse(endYmd);
  final teamEnd = rangeEnd.isBefore(end) ? rangeEnd : end;

  var current = start;
  while (!current.isAfter(teamEnd)) {
    final dateStr = _ymd(current);
    final day = List<GeneralScheduleCell?>.from(
      grid[dateStr] ?? emptyDaySlots(),
    );
    final existing = existingSlotsByDate?[dateStr];
    final dateSlots = <int>[];

    for (var teamIndex = 0; teamIndex < teamCount; teamIndex++) {
      if (editingScheduleId != null &&
          existing != null &&
          teamIndex < existing.length) {
        final existingSlot = existing[teamIndex];
        final occupant = day[existingSlot];
        if (occupant == null || occupant.scheduleId == editingScheduleId) {
          dateSlots.add(existingSlot);
          continue;
        }
      }

      int? found;
      for (final slot in kGeneralScheduleSlotIndices) {
        if (dateSlots.contains(slot)) continue;
        final occupant = day[slot];
        if (occupant == null ||
            (editingScheduleId != null &&
                occupant.scheduleId == editingScheduleId)) {
          found = slot;
          break;
        }
      }
      if (found == null) {
        return SlotAssignmentResult.failure(
          '$dateStr 날짜에 팀 ${teamIndex + 1}에 사용 가능한 칸이 없습니다.',
        );
      }
      dateSlots.add(found);
    }

    teamSlotMap[dateStr] = dateSlots;
    if (dateSlots.isNotEmpty) {
      slotMap[dateStr] = dateSlots.first;
    }
    current = current.add(const Duration(days: 1));
  }

  return SlotAssignmentResult.success(
    slotMap,
    teamSlotMap: teamSlotMap,
  );
}

class SlotAssignmentResult {
  const SlotAssignmentResult._({
    required this.ok,
    this.slotMap = const {},
    this.teamSlotMap = const {},
    this.errorMessage,
  });

  factory SlotAssignmentResult.success(
    Map<String, int> slotMap, {
    Map<String, List<int>> teamSlotMap = const {},
  }) =>
      SlotAssignmentResult._(
        ok: true,
        slotMap: slotMap,
        teamSlotMap: teamSlotMap,
      );

  factory SlotAssignmentResult.failure(String message) =>
      SlotAssignmentResult._(ok: false, errorMessage: message);

  final bool ok;
  final Map<String, int> slotMap;
  final Map<String, List<int>> teamSlotMap;
  final String? errorMessage;
}

String _ymd(DateTime d) {
  final y = d.year;
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '$y-$m-$day';
}

int inclusiveDayCount(String startYmd, String endYmd) {
  final start = DateTime.parse(startYmd);
  final end = DateTime.parse(endYmd);
  return end.difference(start).inDays + 1;
}