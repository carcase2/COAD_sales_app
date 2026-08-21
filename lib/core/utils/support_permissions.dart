import 'package:coad_customer_calls/core/utils/admin_permissions.dart';
import 'package:coad_customer_calls/models/app_user.dart';

/// 고객지원팀(AS) 메뉴 접근.
/// 웹 COAD_home `support` 탭과 맞춤 — 레거시(권한 배열 비어 있음)는 열지 않음.
bool canAccessCustomerSupport(AppUser? user) {
  if (user == null) return false;
  if (isAppAdmin(user)) return true;
  final group = user.groupName?.trim();
  if (group == '고객지원' || group == '고객지원팀') return true;
  final p = user.permissions;
  return p.contains('all') || p.contains('support');
}
