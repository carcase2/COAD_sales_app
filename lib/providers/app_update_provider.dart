import 'package:coad_customer_calls/services/app_update_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// `app_update_policy` 기준 업데이트 여부 — [MainTabScreen]·설정에서 표시.
final appUpdateStatusProvider = FutureProvider<AppUpdateStatus>((ref) async {
  return AppUpdateService.fetchUpdateStatus();
});
