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

  /// 체크시트: open | search | view | download
  static Future<void> recordChecksheet({
    required String userId,
    required String userName,
    required String action,
  }) {
    final a = action.trim().toLowerCase();
    final kind = switch (a) {
      'open' || 'checksheet' => 'checksheet',
      'search' || 'checksheet_search' => 'checksheet_search',
      'view' || 'checksheet_view' => 'checksheet_view',
      'download' || 'checksheet_download' => 'checksheet_download',
      _ => a.startsWith('checksheet') ? a : 'checksheet_$a',
    };
    return _record(userId: userId, userName: userName, kind: kind);
  }

  /// 시공 사진: 일별 집계 + 검색 한 건씩 기록.
  static Future<void> recordInstallAfter({
    required String userId,
    required String userName,
    required String action,
    String? modelCode,
    String? modelLabel,
    String? query,
    int? resultCount,
    String? siteName,
  }) async {
    final a = action.trim().toLowerCase();
    final kind = switch (a) {
      'open' || 'install_after' => 'install_after',
      'search' || 'install_after_search' => 'install_after_search',
      'view' || 'install_after_view' => 'install_after_view',
      'download' || 'install_after_download' => 'install_after_download',
      _ => a.startsWith('install_after') ? a : 'install_after_$a',
    };
    await _record(userId: userId, userName: userName, kind: kind);
    if (userId.trim().isEmpty) return;
    try {
      await _client.rpc<void>(
        'record_install_after_search',
        params: {
          'p_user_id': userId,
          'p_user_name': userName,
          'p_action': switch (a) {
            'open' || 'install_after' => 'open',
            'view' || 'install_after_view' => 'view',
            'download' || 'install_after_download' => 'download',
            _ => 'search',
          },
          'p_model_code': modelCode,
          'p_model_label': modelLabel,
          'p_query': query,
          'p_result_count': resultCount,
          'p_site_name': siteName,
        },
      );
    } catch (_) {}
  }

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
