import 'package:coad_customer_calls/core/utils/date_seoul.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 앱 사용량을 Supabase에 조용히 기록한다. 실패해도 UX에 영향 없음.
class UsageService {
  UsageService._();

  static final SupabaseClient _client = Supabase.instance.client;

  static Future<void> recordAppOpen({
    required String userId,
    required String userName,
  }) =>
      _record(userId: userId, userName: userName, kind: 'app_open');

  static Future<void> recordTab({
    required String userId,
    required String userName,
    required String tabKey,
  }) =>
      _record(userId: userId, userName: userName, kind: tabKey);

  static Future<void> _record({
    required String userId,
    required String userName,
    required String kind,
  }) async {
    if (userId.trim().isEmpty || kind.trim().isEmpty) return;
    try {
      await _client.rpc<void>(
        'record_app_usage',
        params: {
          'p_user_id': userId,
          'p_user_name': userName,
          'p_usage_date': todayYmdSeoul(),
          'p_kind': kind,
        },
      );
    } catch (_) {
      // 네트워크·마이그레이션 미적용 등 — 무시
    }
  }
}
