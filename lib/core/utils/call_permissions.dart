import 'package:coad_customer_calls/models/app_user.dart';

bool canAccessSalesCalls(AppUser user) {
  if (user.role == 'admin') return true;
  final p = user.permissions;
  // 레거시 계정/데이터에는 permissions가 비어 있을 수 있어 기본 접근 허용.
  if (p.isEmpty) return true;
  return p.contains('all') || p.contains('sales_calls');
}
