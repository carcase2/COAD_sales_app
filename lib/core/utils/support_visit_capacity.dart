import 'package:coad_customer_calls/core/utils/date_seoul.dart';
import 'package:flutter/material.dart';

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

/// 팀별 주간칸 색 (본사일반 담당자 팔레트와 비슷한 구분색).
const kSupportVisitTeamPalette = <Color>[
  Color(0xFF2563EB),
  Color(0xFF059669),
  Color(0xFFD97706),
  Color(0xFF7C3AED),
  Color(0xFFDB2777),
  Color(0xFF0D9488),
  Color(0xFFEA580C),
  Color(0xFF4F46E5),
];

Color supportVisitTeamColor(String teamId, {int? index}) {
  if (index != null) {
    return kSupportVisitTeamPalette[index % kSupportVisitTeamPalette.length];
  }
  final id = teamId.trim();
  if (id.isEmpty) return kSupportVisitTeamPalette.first;
  return kSupportVisitTeamPalette[id.hashCode.abs() % kSupportVisitTeamPalette.length];
}

/// 주간표 왼쪽 시간열 너비.
const kSupportVisitWeekTimeGutterWidth = 46.0;

/// 주간표 날짜 원형 영역 높이 (시간열 상단 맞춤).
const kSupportVisitWeekDateHeaderHeight = 36.0;

/// 주간표 「오늘」 열 테두리.
const kSupportVisitWeekTodayBorder = Color(0xFF2563EB);

Border supportVisitWeekDayColumnBorder({
  required bool isToday,
  required bool showRightDivider,
}) {
  if (isToday) {
    return Border.all(color: kSupportVisitWeekTodayBorder, width: 2);
  }
  return Border(
    right: showRightDivider
        ? const BorderSide(color: Color(0xFF9CA3AF), width: 1.1)
        : BorderSide.none,
  );
}

/// 주간표 표시용 월 라벨. 주가 걸치면 `3–4월`.
String supportVisitWeekMonthLabel(Iterable<String> ymds) {
  final months = <int>{};
  for (final ymd in ymds) {
    final parts = ymd.split('-');
    if (parts.length != 3) continue;
    final m = int.tryParse(parts[1]);
    if (m != null) months.add(m);
  }
  if (months.isEmpty) return '';
  final sorted = months.toList()..sort();
  if (sorted.length == 1) return '${sorted.first}월';
  return '${sorted.first}–${sorted.last}월';
}

/// 주간 달력 왼쪽 시간 라벨 (09:00~17:00).
class SupportVisitWeekTimeGutter extends StatelessWidget {
  const SupportVisitWeekTimeGutter({
    super.key,
    this.monthLabel = '',
  });

  /// 날짜 원형과 같은 높이의 기존 칸에 표시 (추가 높이 없음).
  final String monthLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final label = monthLabel.trim();
    return SizedBox(
      width: kSupportVisitWeekTimeGutterWidth,
      child: Column(
        children: [
          SizedBox(
            height: kSupportVisitWeekDateHeaderHeight,
            child: label.isEmpty
                ? null
                : Center(
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.clip,
                      style: TextStyle(
                        fontSize: label.length > 3 ? 10 : 11,
                        height: 1,
                        fontWeight: FontWeight.w900,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
          ),
          for (final time in kSupportVisitTimeSlots)
            Expanded(
              child: Center(
                child: Text(
                  normalizeSupportVisitTime(time),
                  style: TextStyle(
                    fontSize: 10,
                    height: 1,
                    fontWeight: FontWeight.w800,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 요일 헤더 왼쪽 빈칸 (시간열과 너비 맞춤).
class SupportVisitWeekTimeGutterHeader extends StatelessWidget {
  const SupportVisitWeekTimeGutterHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox(width: kSupportVisitWeekTimeGutterWidth);
  }
}

/// 주간표 요일 스타일 (월~금).
class SupportVisitWeekdayStyle {
  const SupportVisitWeekdayStyle({
    required this.headerTop,
    required this.headerBottom,
    required this.headerFg,
    required this.headerBorder,
    required this.columnBg,
    required this.dateFg,
  });

  final Color headerTop;
  final Color headerBottom;
  final Color headerFg;
  final Color headerBorder;
  final Color columnBg;
  final Color dateFg;
}

const _kSupportVisitWeekdayNeutral = SupportVisitWeekdayStyle(
  headerTop: Color(0xFFF3F4F6),
  headerBottom: Color(0xFFE5E7EB),
  headerFg: Color(0xFF374151),
  headerBorder: Color(0xFFD1D5DB),
  columnBg: Color(0xFFF9FAFB),
  dateFg: Color(0xFF374151),
);

/// 월간 달력용: 토=파랑, 일=빨강.
const kSupportVisitCalendarSaturday = Color(0xFF2563EB);
const kSupportVisitCalendarSunday = Color(0xFFEF4444);

Color? supportVisitWeekendDayColor(int weekday) => switch (weekday) {
  DateTime.saturday => kSupportVisitCalendarSaturday,
  DateTime.sunday => kSupportVisitCalendarSunday,
  _ => null,
};

/// 주간표 열 수 (월~금). 토·일은 월간 달력에서만 표시.
const kSupportVisitWeekdayColumnCount = 5;

/// 월(0)~금(4). 주간표는 월요일 시작, 주말 열 없음.
const kSupportVisitWeekdayStyles = <SupportVisitWeekdayStyle>[
  _kSupportVisitWeekdayNeutral,
  _kSupportVisitWeekdayNeutral,
  _kSupportVisitWeekdayNeutral,
  _kSupportVisitWeekdayNeutral,
  _kSupportVisitWeekdayNeutral,
];

const kSupportVisitWeekdayLabels = ['월', '화', '수', '목', '금'];

/// 요일 헤더 행 (시간열 빈칸은 밖에서 붙임).
class SupportVisitWeekdayHeaderRow extends StatelessWidget {
  const SupportVisitWeekdayHeaderRow({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < kSupportVisitWeekdayColumnCount; i++)
          Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    kSupportVisitWeekdayStyles[i].headerTop,
                    kSupportVisitWeekdayStyles[i].headerBottom,
                  ],
                ),
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(
                    i == 0 || i == kSupportVisitWeekdayColumnCount - 1 ? 10 : 0,
                  ),
                ),
                border: Border(
                  bottom: BorderSide(
                    color: kSupportVisitWeekdayStyles[i].headerBorder,
                    width: 3,
                  ),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(
                  kSupportVisitWeekdayLabels[i],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: kSupportVisitWeekdayStyles[i].headerFg,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// 주간표 날짜 원형.
class SupportVisitWeekDayBadge extends StatelessWidget {
  const SupportVisitWeekDayBadge({
    super.key,
    required this.dayNum,
    required this.dateFg,
    this.selected = false,
    this.isFull = false,
    this.past = false,
    this.compact = false,
    this.onTap,
  });

  final int dayNum;
  final Color dateFg;
  final bool selected;
  final bool isFull;
  final bool past;
  final bool compact;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final size = compact ? 22.0 : 28.0;
    return SizedBox(
      height: kSupportVisitWeekDateHeaderHeight,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: size,
              height: size,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isFull
                    ? const Color(0xFFFECACA)
                    : selected
                    ? Colors.white
                    : Colors.transparent,
                border: Border.all(
                  color: isFull
                      ? const Color(0xFFF87171)
                      : selected
                      ? const Color(0xFF93C5FD)
                      : Colors.white,
                  width: isFull || selected ? 2 : 1.5,
                ),
              ),
              child: Text(
                '$dayNum',
                style: TextStyle(
                  fontSize: compact ? 11 : 13,
                  height: 1,
                  fontWeight: FontWeight.w800,
                  color: past
                      ? const Color(0xFF9CA3AF)
                      : isFull
                      ? const Color(0xFFB91C1C)
                      : dateFg,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

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

/// 현재 접수 건이 이미 잡아 둔 슬롯이면 true (표시는 예약, 재선택은 허용).
bool isSupportVisitOwnCurrentSlot({
  required String ymd,
  required String teamId,
  required String time,
  String? ownVisitDate,
  String? ownVisitTeamId,
  String? ownVisitTime,
}) {
  final ownYmd = (ownVisitDate ?? '').trim();
  final ownTeam = (ownVisitTeamId ?? '').trim();
  final ownTime = normalizeSupportVisitTime(ownVisitTime);
  if (ownYmd.isEmpty || ownTeam.isEmpty || ownTime.isEmpty) return false;
  return ymd.trim() == ownYmd &&
      teamId.trim() == ownTeam &&
      normalizeSupportVisitTime(time) == ownTime;
}

/// 다른 건이 잡은 슬롯만 막음. 본인 현재 예약은 선택 가능.
bool supportVisitSlotBlockedForPick({
  required SupportVisitDayBookings bookings,
  required String ymd,
  required String teamId,
  required String time,
  String? ownVisitDate,
  String? ownVisitTeamId,
  String? ownVisitTime,
}) {
  if (!bookings.teamTimeTaken(teamId: teamId, time: time)) return false;
  return !isSupportVisitOwnCurrentSlot(
    ymd: ymd,
    teamId: teamId,
    time: time,
    ownVisitDate: ownVisitDate,
    ownVisitTeamId: ownVisitTeamId,
    ownVisitTime: ownVisitTime,
  );
}

List<String> supportVisitFreeTimesForTeam({
  required String teamId,
  required SupportVisitDayBookings bookings,
  String? ymd,
  String? ownVisitDate,
  String? ownVisitTeamId,
  String? ownVisitTime,
}) {
  return kSupportVisitTimeSlots
      .where((t) {
        if (supportVisitTeamTimeFree(
          teamId: teamId,
          time: t,
          bookings: bookings,
        )) {
          return true;
        }
        if ((ymd ?? '').trim().isEmpty) return false;
        return isSupportVisitOwnCurrentSlot(
          ymd: ymd!,
          teamId: teamId,
          time: t,
          ownVisitDate: ownVisitDate,
          ownVisitTeamId: ownVisitTeamId,
          ownVisitTime: ownVisitTime,
        );
      })
      .toList();
}

/// 날짜 선택 가능: 팀 있고, 어떤 팀이든 남는 시간이 하나라도 있음.
bool supportVisitDaySelectable({
  required SupportVisitDayBookings bookings,
  required int activeTeamCount,
  required Iterable<String> activeTeamIds,
  String? ymd,
  String? ownVisitDate,
  String? ownVisitTeamId,
  String? ownVisitTime,
}) {
  if (activeTeamCount <= 0) return false;
  for (final id in activeTeamIds) {
    if (supportVisitFreeTimesForTeam(
      teamId: id,
      bookings: bookings,
      ymd: ymd,
      ownVisitDate: ownVisitDate,
      ownVisitTeamId: ownVisitTeamId,
      ownVisitTime: ownVisitTime,
    ).isNotEmpty) {
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
