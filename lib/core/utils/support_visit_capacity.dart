import 'package:coad_customer_calls/core/utils/date_seoul.dart';

/// 웹 A/S 방문 일정과 동일한 시간대.
const kSupportVisitTimeSlots = [
  '09:00',
  '10:00',
  '11:00',
  '12:00',
  '13:00',
  '14:00',
  '15:00',
  '16:00',
  '17:00',
];

/// DB `time` / `09:00:00` → `09:00`.
String normalizeSupportVisitTime(String? raw) {
  final t = (raw ?? '').trim();
  if (t.isEmpty) return '';
  if (t.length >= 5 && t[2] == ':') return t.substring(0, 5);
  return t;
}

/// 날짜별 예약: 팀별 이미 잡힌 시간 + 총 건수.
class SupportVisitDayBookings {
  const SupportVisitDayBookings({
    this.timesByTeamId = const {},
    this.totalCount = 0,
  });

  /// teamId → {'09:00', '14:00', ...}
  final Map<String, Set<String>> timesByTeamId;
  final int totalCount;

  Set<String> timesForTeam(String teamId) {
    final id = teamId.trim();
    if (id.isEmpty) return const {};
    return timesByTeamId[id] ?? const {};
  }

  bool teamTimeTaken({required String teamId, required String time}) {
    final slot = normalizeSupportVisitTime(time);
    if (slot.isEmpty) return false;
    return timesForTeam(teamId).contains(slot);
  }

  int visitsForTeam(String teamId) => timesForTeam(teamId).length;
}

int supportVisitCapacityFromTeams(int activeTeamCount) =>
    activeTeamCount < 0 ? 0 : activeTeamCount;

/// 하루 최대 슬롯 수(표시용) = 팀 수 × 시간대 수.
int supportVisitDaySlotCapacity(int activeTeamCount) {
  if (activeTeamCount <= 0) return 0;
  return activeTeamCount * kSupportVisitTimeSlots.length;
}

bool supportVisitDayOpen({required int booked, required int capacity}) {
  if (capacity <= 0) return false;
  return booked < capacity;
}

/// 해당 팀·시간에 자리가 있으면 true.
bool supportVisitTeamTimeFree({
  required String teamId,
  required String time,
  required SupportVisitDayBookings bookings,
}) {
  final id = teamId.trim();
  final slot = normalizeSupportVisitTime(time);
  if (id.isEmpty || slot.isEmpty) return false;
  if (!kSupportVisitTimeSlots.contains(slot)) return false;
  return !bookings.teamTimeTaken(teamId: id, time: slot);
}

List<String> supportVisitFreeTimesForTeam({
  required String teamId,
  required SupportVisitDayBookings bookings,
}) {
  return kSupportVisitTimeSlots
      .where(
        (t) => supportVisitTeamTimeFree(
          teamId: teamId,
          time: t,
          bookings: bookings,
        ),
      )
      .toList();
}

/// 날짜 선택 가능: 팀 있고, 어떤 팀이든 남는 시간이 하나라도 있음.
bool supportVisitDaySelectable({
  required SupportVisitDayBookings bookings,
  required int activeTeamCount,
  required Iterable<String> activeTeamIds,
}) {
  if (activeTeamCount <= 0) return false;
  for (final id in activeTeamIds) {
    if (supportVisitFreeTimesForTeam(teamId: id, bookings: bookings)
        .isNotEmpty) {
      return true;
    }
  }
  return false;
}

String? earliestOpenVisitYmd({
  required String fromYmd,
  required Map<String, int> bookedByYmd,
  required int capacity,
  int maxDays = 90,
}) {
  var ymd = fromYmd;
  for (var i = 0; i < maxDays; i++) {
    final booked = bookedByYmd[ymd] ?? 0;
    if (supportVisitDayOpen(booked: booked, capacity: capacity)) return ymd;
    ymd = addDaysToYmd(ymd, 1);
  }
  return null;
}

String? earliestOpenVisitYmdWithTeams({
  required String fromYmd,
  required Map<String, SupportVisitDayBookings> bookingsByYmd,
  required int activeTeamCount,
  required Iterable<String> activeTeamIds,
  int maxDays = 90,
}) {
  if (activeTeamCount <= 0) return null;
  var ymd = fromYmd;
  for (var i = 0; i < maxDays; i++) {
    final day = bookingsByYmd[ymd] ?? const SupportVisitDayBookings();
    if (supportVisitDaySelectable(
      bookings: day,
      activeTeamCount: activeTeamCount,
      activeTeamIds: activeTeamIds,
    )) {
      return ymd;
    }
    ymd = addDaysToYmd(ymd, 1);
  }
  return null;
}

@Deprecated('Use support_as_visit_teams on server')
const kSupportVisitTeamsHqPref = 'support_visit_teams_hq_v1';
@Deprecated('Use support_as_visit_teams on server')
const kSupportVisitTeamsBranchPref = 'support_visit_teams_branch_v1';
const kSupportVisitTeamsHqDefault = 2;
const kSupportVisitTeamsBranchDefault = 1;

@Deprecated('Use supportVisitCapacityFromTeams')
int supportVisitDayCapacity({
  required String branch,
  required int hqTeams,
  required int branchTeams,
}) {
  return branch == '본사' ? hqTeams : branchTeams;
}
