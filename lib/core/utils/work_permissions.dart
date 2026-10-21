import 'package:coad_customer_calls/models/app_user.dart';

/// 업무관리 메뉴·알림. 그룹이 연구소 또는 관리자인 계정만.
bool canAccessWorkTasks(AppUser? user) {
  if (user == null) return false;
  final group = user.groupName?.trim();
  return group == '연구소' || group == '관리자';
}
