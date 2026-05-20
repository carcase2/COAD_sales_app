import 'dart:io';
import 'package:coad_customer_calls/core/network/api_exception.dart';
import 'package:coad_customer_calls/data/app_dependencies.dart';
import 'package:coad_customer_calls/data/local/database_helper.dart';
import 'package:coad_customer_calls/core/utils/date_seoul.dart';
import 'package:coad_customer_calls/models/master_data.dart';
import 'package:coad_customer_calls/models/region.dart';
import 'package:coad_customer_calls/models/sales_call.dart';
import 'package:coad_customer_calls/models/sales_call_draft.dart';
import 'package:coad_customer_calls/models/temp_manager_override.dart';
import 'package:coad_customer_calls/models/today_stats.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// **1층: 메타데이터·URL** — 웹 `supabaseClient`와 동일한 **메인** Supabase 프로젝트
class SalesCallsRepository {
  SalesCallsRepository(AppDependencies deps);

  final SupabaseClient _client = Supabase.instance.client;
  final DatabaseHelper _db = DatabaseHelper.instance;
  static const String _regionSelect =
      'id,sido,region,manager,branch_type';
  static const String _callHistorySelect =
      'id,sales_call_id,call_stage,consultation_content,created_at,created_by';

  Future<MasterDataBundle> fetchMasterData() async {
    final cached = await _db.getMasterData('master_bundle');
    if (cached != null) {
      _syncMasterDataInBackground();
      return MasterDataBundle.fromJson(cached);
    }

    try {
      final data = await _fetchMasterDataFromRemote();
      await _db.saveMasterData('master_bundle', data);
      return MasterDataBundle.fromJson(data);
    } catch (e) {
      throw ApiException('마스터 데이터를 불러오는데 실패했습니다: $e');
    }
  }

  Future<Map<String, dynamic>> _fetchMasterDataFromRemote() async {
    final pc = await _client.from('product_categories').select();
    final im = await _client.from('inquiry_methods').select();
    final regionsRaw = await fetchRegions();
    final regions = regionsRaw.map((e) => e.toMasterRowJson()).toList();

    return {
      'product_categories': pc,
      'inquiry_methods': im,
      'regions': regions,
    };
  }

  void _syncMasterDataInBackground() async {
    try {
      final data = await _fetchMasterDataFromRemote();
      await _db.saveMasterData('master_bundle', data);
    } catch (_) {}
  }

  Future<List<Region>> fetchRegions() async {
    final res = await _client
        .from('regions')
        .select('id,sido,region,manager,branch_type,user_id');
    return res
        .whereType<Map>()
        .map((e) => Region.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<List<TempManagerOverride>> fetchTempOverrides() async {
    final res = await _client
        .from('temp_manager_overrides')
        .select(
          'id,region_name,original_manager,temp_manager,start_date,end_date,memo,is_active,created_at,updated_at',
        )
        .order('updated_at', ascending: false);
    return res
        .whereType<Map>()
        .map((e) => TempManagerOverride.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  static List<Region> buildEffectiveRegions(
    List<Region> regions,
    List<TempManagerOverride> overrides,
    DateTime nowKst,
  ) {
    final todayYmd = ymdSeoulFromDateTime(nowKst);

    bool isOverrideActive(TempManagerOverride o) {
      if (!o.isActive) return false;
      return isYmdWithinInclusiveRange(
        todayYmd,
        startYmd: o.startDate,
        endYmd: o.endDate,
      );
    }

    return regions.map((r) {
      final original = r.manager.trim();
      final regionName = r.region.trim();
      TempManagerOverride? matched;
      for (final o in overrides) {
        if (!isOverrideActive(o)) continue;
        if (o.regionName != regionName) continue;
        if (o.originalManager != original) continue;
        matched = o;
        break;
      }
      if (matched == null) {
        return r.copyWith(
          originalManager: original,
          effectiveManager: original,
          isManagerOverridden: false,
        );
      }
      return r.copyWith(
        originalManager: original,
        effectiveManager: matched.tempManager,
        isManagerOverridden: true,
      );
    }).toList();
  }

  /// 로컬 DB에서 캐시된 목록 조회
  /// [incompleteOnly]: 미통화는 `status_id=1`이 아니라 **isMissed**(초기 단계·단순문의 제외)와
  /// `fetchCalls(uncalledOnly: true)`·홈 `fetchTodayStats`와 동일 기준이어야 함.
  Future<List<SalesCall>> fetchCachedCalls({String? date, bool? incompleteOnly}) async {
    final res = await _db.getSalesCalls(
      date: date,
      statusId: null,
      limit: 200,
    );
    var parsed = parseSalesCallList(res);
    if (incompleteOnly == true) {
      parsed = parsed.where((c) => c.isMissed).toList();
    }
    return parsed;
  }

  /// [followDate] `yyyy-MM-dd` — `next_scheduled_date`가 해당 날짜인 건만 (날짜 팔로우).
  /// [followRangeStart]·[followRangeEndInclusive] — 팔로우 날짜 **구간**(양끝 포함, `next_scheduled_date` 기준).
  /// [dateRangeStart]·[dateRangeEndInclusive] — 접수일 `call_date` **구간**(양끝 포함).
  /// [date]가 함께 넘어오면 [followDate]가 우선이며, 접수일(`call_date`) 필터는 적용하지 않음.
  Future<List<SalesCall>> fetchCalls({
    String? date,
    String? followDate,
    String? followRangeStart,
    String? followRangeEndInclusive,
    String? dateRangeStart,
    String? dateRangeEndInclusive,
    String? fromDate,
    int? limit,
    int? offset,
    bool includeCallHistory = true,
    bool? incompleteOnly,
    bool? uncalledOnly,
    bool? completedOnly,
    bool excludeSimpleInquiries = false,
    bool calendarFull = false,
  }) async {
    try {
      String selectStr = '''
        *,
        product_categories(name),
        inquiry_methods(name),
        call_statuses(name),
        regions($_regionSelect)
      ''';
      
      if (includeCallHistory) {
        selectStr += ', call_history($_callHistorySelect)';
      }

      PostgrestFilterBuilder<List<Map<String, dynamic>>> queryBuilder = _client.from('sales_calls').select(selectStr);

      if (followDate != null) {
        final endExclusive = _ymdPlusOneDay(followDate);
        queryBuilder = queryBuilder
            .gte('next_scheduled_date', followDate)
            .lt('next_scheduled_date', endExclusive);
      } else if (followRangeStart != null && followRangeEndInclusive != null) {
        final endExclusive = _ymdPlusOneDay(followRangeEndInclusive);
        queryBuilder = queryBuilder
            .gte('next_scheduled_date', followRangeStart)
            .lt('next_scheduled_date', endExclusive);
      } else if (date != null) {
        queryBuilder = queryBuilder
            .gte('call_date', '$date 00:00:00')
            .lte('call_date', '$date 23:59:59');
      } else if (dateRangeStart != null && dateRangeEndInclusive != null) {
        queryBuilder = queryBuilder
            .gte('call_date', '$dateRangeStart 00:00:00')
            .lte('call_date', '$dateRangeEndInclusive 23:59:59');
      }
      if (fromDate != null) {
        queryBuilder = queryBuilder.gte('call_date', '$fromDate 00:00:00');
      }
      if (incompleteOnly == true) {
        // 미종료: 수주(3), 미수주(2), 단순문의(4)가 아닌 모든 상태
        queryBuilder = queryBuilder.not('status_id', 'in', '(2,3,4)');
      }
      if (uncalledOnly == true) {
        // 미통화: 단순문의 제외하고 단계가 초기인 건
        queryBuilder = queryBuilder.neq('status_id', 4);
      }
      PostgrestTransformBuilder<List<Map<String, dynamic>>> transformBuilder = queryBuilder.order('created_at', ascending: false);

      if (limit != null) {
        int rTop = (offset ?? 0) + limit - 1;
        transformBuilder = transformBuilder.range(offset ?? 0, rTop);
      }

      final res = await transformBuilder;
      
      // 로컬 DB 동기화 (Upsert)
      if (res.isNotEmpty) {
        await _db.saveSalesCalls(res);
      }

      List<SalesCall> parsed = parseSalesCallList(res);
      
      if (uncalledOnly == true) {
        // 미통화: (초기 단계) && (단순문의 아님)
        parsed = parsed.where((c) => c.isMissed).toList();
      }
      
      if (completedOnly == true) {
        // 완료(처리됨): !(미통화) => (단계 진행됨) || (단순문의)
        parsed = parsed.where((c) => !c.isMissed).toList();
      }
      
      if (incompleteOnly == true) {
        parsed = parsed.where((c) => ![2,3,4].contains(c.statusId)).toList();
      }
      
      if (excludeSimpleInquiries) {
        parsed = parsed.where((c) => c.statusId != 4).toList();
      }
      return parsed;
    } catch (e) {
      throw ApiException('통화 목록을 불러오는데 실패했습니다: $e');
    }
  }

  Future<SalesCall> fetchCallById(String id) async {
    try {
      final res = await _client.from('sales_calls').select('''
        *,
        product_categories(name),
        inquiry_methods(name),
        call_statuses(name),
        regions($_regionSelect),
        call_history($_callHistorySelect)
      ''').eq('id', id).maybeSingle();

      if (res == null) {
        throw ApiException('통화를 찾을 수 없습니다.', statusCode: 404);
      }
      
      // 개별 상세 조회 시에도 캐시 업데이트
      await _db.saveSalesCalls([res]);

      return SalesCall.fromJson(res);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('통화 상세 정보를 가져오는데 실패했습니다: $e');
    }
  }

  Future<SalesCall> createCall(Map<String, dynamic> body) async {
    try {
      final res = await _client.from('sales_calls').insert(body).select().single();
      return fetchCallById(res['id']);
    } catch (e) {
      if (e is SocketException || e.toString().contains('SocketException') || e.toString().contains('Failed host lookup')) {
        await _db.savePendingCall(body);
        throw OfflineException();
      }
      throw ApiException('등록에 실패했습니다: $e');
    }
  }

  Future<SalesCall> createSalesCall(SalesCallDraft draft) {
    return createCall(draft.toInsertJson());
  }

  /// 오프라인 중 등록된 상담 내역을 서버로 동기화
  Future<int> syncPendingCalls() async {
    final pendings = await _db.getPendingCalls();
    if (pendings.isEmpty) return 0;

    int successCount = 0;
    for (var item in pendings) {
      final id = item['id'] as int;
      final data = item['data'] as Map<String, dynamic>;
      
      try {
        await _client.from('sales_calls').insert(data);
        await _db.deletePendingCall(id);
        successCount++;
      } catch (_) {
        // 네트워크가 여전히 안 좋거나 데이터 오류면 다음 기회에
      }
    }
    return successCount;
  }

  Future<int> getPendingCount() async {
    final list = await _db.getPendingCalls();
    return list.length;
  }

  Future<SalesCall> updateCall(String id, Map<String, dynamic> body) async {
    try {
      await _client.from('sales_calls').update(body).eq('id', id);
      return fetchCallById(id);
    } catch (e) {
      throw ApiException('수정에 실패했습니다: $e');
    }
  }

  Future<void> addCallHistory(String callId, Map<String, dynamic> historyData) async {
    try {
      await _client.from('call_history').insert({
        ...historyData,
        'sales_call_id': callId,
      });
    } catch (e) {
      throw ApiException('상담 이력 저장에 실패했습니다: $e');
    }
  }

  TodayStats _todayStatsFromRows(List<Map<String, dynamic>> res) {
    final total = res.length;
    final incomplete = res.where((row) {
      final stage = row['call_stage']?.toString().trim();
      final isInitial =
          stage == null || stage == '' || stage == '0' || stage == '접수';
      final isNotSimple = row['status_id'] != 4;
      return isInitial && isNotSimple;
    }).length;
    final completed = total - incomplete;
    return TodayStats.fromJson({
      'today_count': total,
      'incomplete_count': incomplete,
      'completed_today': completed,
    });
  }

  Future<TodayStats> fetchTodayStats() => fetchStatsForDate(todayYmdSeoul());

  Future<TodayStats> fetchStatsForDate(String ymdSeoul) async {
    try {
      final res = await _client
          .from('sales_calls')
          .select('id, status_id, call_stage')
          .eq('call_date', ymdSeoul);
      return _todayStatsFromRows(res);
    } catch (e) {
      throw ApiException('통계 데이터를 불러오는데 실패했습니다: $e');
    }
  }

  Future<TodayStats> fetchStatsForDateRange(
    String fromYmd,
    String toYmdInclusive,
  ) async {
    try {
      final res = await _client
          .from('sales_calls')
          .select('id, status_id, call_stage')
          .gte('call_date', '$fromYmd 00:00:00')
          .lte('call_date', '$toYmdInclusive 23:59:59');
      return _todayStatsFromRows(res);
    } catch (e) {
      throw ApiException('통계 데이터를 불러오는데 실패했습니다: $e');
    }
  }

  Future<List<SalesCall>> searchCalls(String query, {int limit = 50}) async {
    if (query.trim().isEmpty) return [];
    
    try {
      final q = '%${query.trim()}%';
      // or filter: customer_name, customer_phone, inquiry_content, region_sido, region_name
      final res = await _client.from('sales_calls').select('''
        *,
        product_categories(name),
        inquiry_methods(name),
        call_statuses(name),
        regions($_regionSelect)
      ''').or('customer_name.ilike.$q,customer_phone.ilike.$q,inquiry_content.ilike.$q,region_sido.ilike.$q,region_name.ilike.$q')
      .order('created_at', ascending: false)
      .limit(limit);

      return parseSalesCallList(res);
    } catch (e) {
      throw ApiException('검색 중 오류가 발생했습니다: $e');
    }
  }
}

String _ymdPlusOneDay(String ymd) {
  final parts = ymd.split('-');
  if (parts.length != 3) return ymd;
  final y = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  final d = int.tryParse(parts[2]);
  if (y == null || m == null || d == null) return ymd;
  final next = DateTime(y, m, d).add(const Duration(days: 1));
  return '${next.year}-${next.month.toString().padLeft(2, '0')}-${next.day.toString().padLeft(2, '0')}';
}
