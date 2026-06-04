import 'package:coad_customer_calls/services/app_update_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Supabase 정책 + Play 스토어 기준 업데이트 여부 — 홈·설정·앱바 표시.
final appUpdateStatusProvider = FutureProvider<AppUpdateStatus>((ref) async {
  ref.keepAlive();
  return AppUpdateService.fetchUpdateStatus();
});
