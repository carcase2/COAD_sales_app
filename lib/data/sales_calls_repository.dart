import 'dart:io';
import 'package:coad_customer_calls/core/network/api_exception.dart';
import 'package:coad_customer_calls/data/app_dependencies.dart';
import 'package:coad_customer_calls/data/local/database_helper.dart';
import 'package:coad_customer_calls/core/utils/date_seoul.dart';
import 'package:coad_customer_calls/models/master_data.dart';
import 'package:coad_customer_calls/models/sales_call.dart';
import 'package:coad_customer_calls/models/today_stats.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// **1층: 메타데이터·URL** — 웹 `supabaseClient`와 동일한 **메인** Supabase 프로젝트
class SalesCallsRepository {
  SalesCallsRepository(AppDependencies deps);

  final SupabaseClient _client = Supabase.instance.client;
  final DatabaseHelper _db = DatabaseHelper.instance;

  Future<MasterDataBundle> fetchMasterData() async {
    // 1. 로컬 캐시 확인
    final cached = await _db.getMasterData('master_bundle');
    if (cached != null) {
      // 캐시가 있으면 즉시 반환하고 백그라운드에서 갱신 시도 (옵션)
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
    final regions = await _client.from('regions').select();

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

  /// 로컬 DB에서 캐시된 목록 조회
  Future<List<SalesCall>> fetchCachedCalls({String? date, bool? incompleteOnly}) async {
    final res = await _db.getSalesCalls(
      date: date,
      statusId: incompleteOnly == true ? 1 : null,
      limit: 100,
    );
    return parseSalesCallList(res);
  }

  Future<List<SalesCall>> fetchCalls({
    String? date,
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
        regions(*)
      ''';
      
      if (includeCallHistory) {
        selectStr += ', call_history(*)';
      }

      PostgrestFilterBuilder<List<Map<String, dynamic>>> queryBuilder = _client.from('sales_calls').select(selectStr); 

      if (date != null) {
        queryBuilder = queryBuilder
            .gte('call_date', '$date 00:00:00')
            .lte('call_date', '$date 23:59:59');
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
        regions(*),
        call_history(*)
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

  Future<TodayStats> fetchTodayStats() async {
    try {
      final todayStr = todayYmdSeoul();
      
      final res = await _client
          .from('sales_calls')
          .select('id, status_id, call_stage')
          .eq('call_date', todayStr);

      final total = res.length;
      
      // 기획 기준 미통화: (단계가 0/null/접수) && (상황이 단순문의(4) 아님)
      final incomplete = res.where((row) {
        final stage = row['call_stage']?.toString().trim();
        final isInitial = stage == null || stage == '' || stage == '0' || stage == '접수';
        final isNotSimple = row['status_id'] != 4;
        return isInitial && isNotSimple;
      }).length;
      
      // 완료: 전체 - 미통화 (또는 명시적으로 단계가 존재하거나 단순문의인 건)
      final completed = total - incomplete;
      
      return TodayStats.fromJson({
        'today_count': total,
        'incomplete_count': incomplete,
        'completed_today': completed,
      });
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
        regions(*)
      ''').or('customer_name.ilike.$q,customer_phone.ilike.$q,inquiry_content.ilike.$q,region_sido.ilike.$q,region_name.ilike.$q')
      .order('created_at', ascending: false)
      .limit(limit);

      return parseSalesCallList(res);
    } catch (e) {
      throw ApiException('검색 중 오류가 발생했습니다: $e');
    }
  }
}
