import 'package:coad_customer_calls/core/utils/admin_permissions.dart';
import 'package:coad_customer_calls/core/utils/call_permissions.dart';
import 'package:coad_customer_calls/core/utils/support_permissions.dart';
import 'package:coad_customer_calls/models/app_user.dart';

/// 자동문의고수 메뉴 접근.
/// 웹 `gosu_calls` 권한 + 영업부·고객지원팀에서도 열 수 있게 한다.
bool canAccessGosuCalls(AppUser? user) {
  if (user == null) return false;
  if (isAppAdmin(user)) return true;
  final group = user.groupName?.trim();
  if (group == '자동문의고수') return true;
  final p = user.permissions;
  if (p.contains('all') || p.contains('gosu_calls')) return true;
  if (canAccessCustomerSupport(user)) return true;
  return canAccessSalesCalls(user);
}
