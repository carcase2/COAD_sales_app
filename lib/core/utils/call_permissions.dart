import 'package:coad_customer_calls/models/app_user.dart';

bool canAccessSalesCalls(AppUser user) {
  if (user.role == 'admin') return true;
  final p = user.permissions;
  return p.contains('all') || p.contains('sales_calls');
}
