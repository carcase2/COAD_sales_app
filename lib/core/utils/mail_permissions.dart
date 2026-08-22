import 'package:coad_customer_calls/core/utils/admin_permissions.dart';
import 'package:coad_customer_calls/models/app_user.dart';

/// 메일 발송 탭 접근 — COAD_home `mail` 권한과 동일.
bool canAccessMail(AppUser? user) {
  if (user == null) return false;
  if (isAppAdmin(user)) return true;
  final p = user.permissions;
  return p.contains('all') || p.contains('mail');
}

/// 담당자 목록에 넣을 그룹 — `mail` 또는 `all`.
bool groupHasMailPermission(Iterable<String> permissions) {
  return permissions.contains('all') || permissions.contains('mail');
}
