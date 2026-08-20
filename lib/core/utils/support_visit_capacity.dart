import 'package:coad_customer_calls/core/utils/date_seoul.dart';
import 'package:shared_preferences/shared_preferences.dart';

const kSupportVisitTeamsHqPref = 'support_visit_teams_hq_v1';
const kSupportVisitTeamsBranchPref = 'support_visit_teams_branch_v1';
const kSupportVisitTeamsHqDefault = 2;
const kSupportVisitTeamsBranchDefault = 1;

int supportVisitTeamsHq(SharedPreferences prefs) {
  final n =
      prefs.getInt(kSupportVisitTeamsHqPref) ?? kSupportVisitTeamsHqDefault;
  return n.clamp(1, 9);
}

int supportVisitTeamsBranch(SharedPreferences prefs) {
  final n =
      prefs.getInt(kSupportVisitTeamsBranchPref) ??
      kSupportVisitTeamsBranchDefault;
  return n.clamp(1, 9);
}

/// 본사는 [hqTeams], 지사(대구·대전·전남·기타)는 [branchTeams].
int supportVisitDayCapacity({
  required String branch,
  required int hqTeams,
  required int branchTeams,
}) {
  return branch == '본사' ? hqTeams : branchTeams;
}

bool supportVisitDayOpen({required int booked, required int capacity}) {
  return booked < capacity;
}

/// [fromYmd]부터 자리가 남는 가장 빠른 날. 없으면 null.
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
