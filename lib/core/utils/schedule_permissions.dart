import 'package:coad_customer_calls/models/app_user.dart';

/// 본사일반 메뉴 — [AppUser.groupName]이 허용 그룹일 때만 접근.
const kGeneralScheduleAllowedGroupNames = ['본사영업', '관리자'];

bool canAccessGeneralSchedule(AppUser user) {
  final group = user.groupName?.trim();
  if (group == null || group.isEmpty) return false;
  return kGeneralScheduleAllowedGroupNames.contains(group);
}