import 'package:coad_customer_calls/core/utils/date_seoul.dart';
import 'package:coad_customer_calls/core/utils/gosu_site_rules.dart';
import 'package:coad_customer_calls/models/gosu_site.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 홈 · 허브에 보여 줄 홈페이지 문의 건수.
class GosuSiteCounts {
  const GosuSiteCounts({
    required this.today,
    required this.receiving,
    required this.stale,
    required this.cancelNoReason,
  });

  final int today;
  final int receiving;
  final int stale;
  final int cancelNoReason;

  static const empty = GosuSiteCounts(
    today: 0,
    receiving: 0,
    stale: 0,
    cancelNoReason: 0,
  );
}

/// 고수 사이트 홈페이지 문의(coad-gosu-followup 동기화 결과).
/// 앱은 읽기 + 통화/취소 사유 기록(gosu_site_followups 추가)만 한다.
class GosuSitesRepository {
  GosuSitesRepository();

  final SupabaseClient _client = Supabase.instance.client;

  static const String _board = 'gosu_sites_board';

  /// 보드는 최근 180일 접수만 (통계용 과거 건 제외) — 웹과 같음.
  static const int boardDays = 180;

  String _boardSinceIso() => DateTime.now()
      .toUtc()
      .subtract(const Duration(days: boardDays))
      .toIso8601String();

  List<GosuSite> _sites(List<dynamic> rows) => rows
      .whereType<Map>()
      .map((e) => GosuSite.fromJson(Map<String, dynamic>.from(e)))
      .toList();

  /// 접수중 (최근 180일). 최신 접수가 위.
  Future<List<GosuSite>> fetchReceiving() async {
    final res = await _client
        .from(_board)
        .select()
        .eq('worker_status', kGosuSiteReceiving)
        .gte('received_at', _boardSinceIso())
        .order('received_at', ascending: false)
        .limit(2000);
    return _sites(res);
  }

  /// 하루(한국 날짜)에 들어온 건 — 상태 무관.
  Future<List<GosuSite>> fetchReceivedOn(String ymd) async {
    final res = await _client
        .from(_board)
        .select()
        .gte('received_at', seoulDayStartUtcIso(ymd))
        .lt('received_at', seoulDayEndExclusiveUtcIso(ymd))
        .order('received_at', ascending: false);
    return _sites(res);
  }

  /// 최근 [days]일 안에 접수취소된 건. 취소일이 비면 고수 마지막 수정일로 판단.
  Future<List<GosuSite>> fetchCanceled({int days = 30}) async {
    final since = DateTime.now()
        .toUtc()
        .subtract(Duration(days: days))
        .toIso8601String();
    final res = await _client
        .from(_board)
        .select()
        .eq('worker_status', kGosuSiteCanceled)
        .or(
          'canceled_at.gte.$since,and(canceled_at.is.null,gosu_updated_at.gte.$since)',
        )
        .order('received_at', ascending: false);
    return _sites(res);
  }

  /// 방문예정일이 [fromYmd, toYmdInclusive] 안에 있는 건 (한국 날짜).
  Future<List<GosuSite>> fetchVisitsBetween(
    String fromYmd,
    String toYmdInclusive,
  ) async {
    final res = await _client
        .from(_board)
        .select()
        .gte('onsite_at', seoulDayStartUtcIso(fromYmd))
        .lt('onsite_at', seoulDayEndExclusiveUtcIso(toYmdInclusive))
        .order('onsite_at');
    return _sites(res);
  }

  Future<GosuSite?> fetchSite(String gosuId) async {
    final res = await _client
        .from(_board)
        .select()
        .eq('gosu_id', gosuId)
        .maybeSingle();
    return res == null ? null : GosuSite.fromJson(res);
  }

  Future<List<GosuSiteFollowup>> fetchFollowups(String gosuId) async {
    final res = await _client
        .from('gosu_site_followups')
        .select()
        .eq('gosu_id', gosuId)
        .order('created_at', ascending: false);
    return res
        .whereType<Map>()
        .map((e) => GosuSiteFollowup.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// 취소 사유를 이미 적은 건의 gosu_id.
  Future<Set<String>> fetchCancelReasonIds(Iterable<String> gosuIds) async {
    final ids = gosuIds.toList();
    if (ids.isEmpty) return {};
    final out = <String>{};
    for (var i = 0; i < ids.length; i += 200) {
      final chunk = ids.sublist(i, (i + 200).clamp(0, ids.length));
      final res = await _client
          .from('gosu_site_followups')
          .select('gosu_id')
          .eq('stage', kGosuSiteCancelStage)
          .inFilter('gosu_id', chunk);
      for (final r in res.whereType<Map>()) {
        out.add(r['gosu_id'].toString());
      }
    }
    return out;
  }

  /// 마지막 동기화 시각 (coad-gosu-followup 이 20분마다 / 웹 목록을 열 때 돌린다).
  Future<DateTime?> fetchLastSyncAt() async {
    final res = await _client
        .from('gosu_sync_runs')
        .select('ran_at')
        .eq('ok', true)
        .order('ran_at', ascending: false)
        .limit(1)
        .maybeSingle();
    return res == null ? null : parseSupabaseTimestampUtc(res['ran_at']);
  }

  Future<GosuSiteCounts> fetchCounts() async {
    final results = await Future.wait([
      fetchReceivedOn(todayYmdSeoul()),
      fetchReceiving(),
      fetchCanceled(),
    ]);
    final canceled = results[2];
    final withReason = await fetchCancelReasonIds(
      canceled.map((s) => s.gosuId),
    );
    final now = DateTime.now();
    return GosuSiteCounts(
      today: results[0].length,
      receiving: results[1].length,
      stale: results[1]
          .where((s) => gosuSiteStaleReason(s, now: now) != null)
          .length,
      cancelNoReason: canceled
          .where((s) => !withReason.contains(s.gosuId) && s.gosuMemo == null)
          .length,
    );
  }

  /// 통화 기록 (접수중 건).
  Future<void> insertCall({
    required GosuSite site,
    required int round,
    required String outcome,
    required String content,
    required String author,
    required String nextCallYmd,
    String? visitLabel,
  }) async {
    await _client.from('gosu_site_followups').insert({
      'gosu_id': site.gosuId,
      'stage': site.workerStatus,
      'result': gosuSiteCallResultText(round, outcome),
      'reason': content.trim(),
      'next_action': visitLabel != null
          ? '$kGosuSiteVisitPrefix$visitLabel'
          : '${round + 1}차 통화',
      'next_action_at': nextCallYmd,
      'author': author,
    });
  }

  /// 접수취소 사유 (취소 건).
  Future<void> insertCancelReason({
    required GosuSite site,
    required String reason,
    required String? note,
    required String author,
  }) async {
    final n = note?.trim() ?? '';
    await _client.from('gosu_site_followups').insert({
      'gosu_id': site.gosuId,
      'stage': kGosuSiteCancelStage,
      'result': reason,
      'reason': n.isEmpty ? null : n,
      'author': author,
    });
  }
}
