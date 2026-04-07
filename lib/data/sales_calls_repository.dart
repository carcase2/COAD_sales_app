import 'package:coad_customer_calls/core/network/api_exception.dart';
import 'package:coad_customer_calls/data/app_dependencies.dart';
import 'package:coad_customer_calls/models/master_data.dart';
import 'package:coad_customer_calls/models/sales_call.dart';
import 'package:coad_customer_calls/models/today_stats.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SalesCallsRepository {
  SalesCallsRepository(AppDependencies deps);

  final SupabaseClient _client = Supabase.instance.client;

  Future<MasterDataBundle> fetchMasterData() async {
    try {
      final pc = await _client.from('product_categories').select();
      final im = await _client.from('inquiry_methods').select();
      final regions = await _client.from('regions').select();

      return MasterDataBundle.fromJson({
        'product_categories': pc,
        'inquiry_methods': im,
        'regions': regions,
      });
    } catch (e) {
      throw ApiException('마스터 데이터를 불러오는데 실패했습니다: $e');
    }
  }

  Future<List<SalesCall>> fetchCalls({
    String? date,
    String? fromDate,
    int? limit,
    int? offset,
    bool includeCallHistory = true,
    bool? incompleteOnly,
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
        // Warning: Will gracefully ignore if call_history relation does not exist
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
        queryBuilder = queryBuilder.eq('status_id', 1);
      }
      if (completedOnly == true) {
        queryBuilder = queryBuilder.neq('status_id', 1);
      }

      PostgrestTransformBuilder<List<Map<String, dynamic>>> transformBuilder = queryBuilder.order('created_at', ascending: false);

      if (limit != null) {
        int rTop = (offset ?? 0) + limit - 1;
        transformBuilder = transformBuilder.range(offset ?? 0, rTop);
      }

      final res = await transformBuilder;
      List<SalesCall> parsed = parseSalesCallList(res);
      if (excludeSimpleInquiries) {
        parsed = parsed.where((c) {
          final n = c.inquiryMethodName;
          return n != '설계문의' && n != '단순문의';
        }).toList();
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
        regions(*)
      ''').eq('id', id).maybeSingle();

      if (res == null) {
        throw ApiException('통화를 찾을 수 없습니다.', statusCode: 404);
      }
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
      throw ApiException('등록에 실패했습니다: $e');
    }
  }

  Future<SalesCall> updateCall(String id, Map<String, dynamic> body) async {
    try {
      await _client.from('sales_calls').update(body).eq('id', id);
      return fetchCallById(id);
    } catch (e) {
      throw ApiException('수정에 실패했습니다: $e');
    }
  }

  Future<TodayStats> fetchTodayStats() async {
    try {
      final todayStr = DateTime.now().toIso8601String().split('T').first;
      
      final res = await _client
          .from('sales_calls')
          .select('id, status_id, inquiry_methods(name)')
          .gte('call_date', '$todayStr 00:00:00')
          .lte('call_date', '$todayStr 23:59:59');

      final total = res.length;
      final completed = res.where((row) => row['status_id'] != 1).length;
      
      final incomplete = res.where((row) {
        if (row['status_id'] != 1) return false;
        final im = row['inquiry_methods'];
        if (im is Map) {
          final name = im['name'];
          if (name == '설계문의' || name == '단순문의') return false;
        }
        return true;
      }).length;
      
      return TodayStats.fromJson({
        'today_count': total,
        'incomplete_count': incomplete,
        'completed_today': completed,
      });
    } catch (e) {
      throw ApiException('통계 데이터를 불러오는데 실패했습니다: $e');
    }
  }
}
