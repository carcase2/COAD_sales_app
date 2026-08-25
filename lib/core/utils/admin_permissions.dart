import 'package:coad_customer_calls/models/app_user.dart';

/// 앱 사용량 등 관리자 전용 기능 접근 여부.
bool isAppAdmin(AppUser? user) {
  if (user == null) return false;
  if (user.role.trim().toLowerCase() == 'admin') return true;
  if (isAdminGroup(user)) return true;
  return user.permissions.contains('all');
}

/// 부서(그룹) 이름이 관리자인 계정만.
bool isAdminGroup(AppUser? user) {
  if (user == null) return false;
  return user.groupName?.trim() == '관리자';
}
