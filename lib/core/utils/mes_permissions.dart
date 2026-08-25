import 'package:coad_customer_calls/models/app_user.dart';

bool canAccessMes(AppUser? user) {
  if (user == null) return false;
  if (user.role.trim().toLowerCase() == 'admin') return true;
  final p = user.permissions;
  if (p.contains('all') || p.contains('admin')) return true;
  return p.any((e) => e.startsWith('mes.'));
}

bool canMes(AppUser? user, String key) {
  if (user == null) return false;
  if (canAccessMes(user) &&
      (user.role.trim().toLowerCase() == 'admin' ||
          user.permissions.contains('all') ||
          user.permissions.contains('admin'))) {
    return true;
  }
  return user.permissions.contains(key);
}
