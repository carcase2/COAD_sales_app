import 'package:coad_customer_calls/models/app_user.dart';

bool canAccessMes(AppUser? user) {
  if (user == null) return false;
  if (user.role.trim().toLowerCase() == 'admin') return true;
  final p = user.permissions;
  if (p.contains('all') || p.contains('admin')) return true;
  return p.any((e) => e.startsWith('mes.') || e.startsWith('mes_'));
}

const _mesAliases = <String, List<String>>{
  'mes.orders.view': ['mes_sales', 'mes_sales_view'],
  'mes.orders.create': ['mes_sales'],
  'mes.manufacturing.view': ['mes_manufacture'],
  'mes.installation.view': ['mes_install', 'construction_completion'],
  'mes.payments.view': ['mes_payment'],
  'mes.calendar': ['mes_dashboard'],
};

bool canMes(AppUser? user, String key) {
  if (user == null) return false;
  if (canAccessMes(user) &&
      (user.role.trim().toLowerCase() == 'admin' ||
          user.permissions.contains('all') ||
          user.permissions.contains('admin'))) {
    return true;
  }
  if (user.permissions.contains(key)) return true;
  final aliases = _mesAliases[key];
  if (aliases == null) return false;
  return aliases.any(user.permissions.contains);
}
