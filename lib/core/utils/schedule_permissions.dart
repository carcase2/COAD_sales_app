import 'package:coad_customer_calls/models/app_user.dart';

/// 본사일반 메뉴 — [AppUser.groupName]이 허용 그룹일 때만 접근.
const kGeneralScheduleAllowedGroupNames = ['본사영업', '관리자'];

/// 본사일반 화면·메뉴에 표시하는 테스트 안내.
const kGeneralScheduleTestLabel = 'test중';

bool canAccessGeneralSchedule(AppUser user) {
  final group = user.groupName?.trim();
  if (group == null || group.isEmpty) return false;
  return kGeneralScheduleAllowedGroupNames.contains(group);
}