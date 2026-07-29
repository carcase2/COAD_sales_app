import 'dart:convert';
import 'dart:io';
import 'package:coad_customer_calls/core/network/api_exception.dart';
import 'package:coad_customer_calls/core/utils/korean_network_error.dart';
import 'package:coad_customer_calls/data/app_dependencies.dart';
import 'package:coad_customer_calls/data/local/database_helper.dart';
import 'package:coad_customer_calls/core/utils/date_seoul.dart';
import 'package:coad_customer_calls/core/utils/phone_validation.dart';
import 'package:coad_customer_calls/models/master_data.dart';
import 'package:coad_customer_calls/models/region.dart';
import 'package:coad_customer_calls/models/sales_call.dart';
import 'package:coad_customer_calls/models/sales_call_draft.dart';
import 'package:coad_customer_calls/models/temp_manager_override.dart';
import 'package:coad_customer_calls/data/temp_manager_logic.dart';
import 'package:coad_customer_calls/models/today_stats.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// **1층: 메타데이터·URL** — 웹 `supabaseClient`와 동일한 **메인** Supabase 프로젝트
class SalesCallsRepository {
  SalesCallsRepository(this._deps);

  final AppDependencies _deps;
  final SupabaseClient _client = Supabase.instance.client;
  final DatabaseHelper _db = DatabaseHelper.instance;

  static const Duration _revertExpiredThrottle = Duration(minutes: 10);
  static const Duration _tempOverridesCacheTtl = Duration(minutes: 2);

  DateTime? _lastRevertExpiredAt;
  Future<int>? _revertInFlight;
  List<TempManagerOverride>? _cachedOverrides;
  DateTime? _overridesCachedAt;
  Future<List<TempManagerOverride>>? _overridesInFlight;

  /// 접수 저장·동기화 후 임시 담당 캐시를 비웁니다.
  void invalidateTempManagerCache({bool forceRevertOnNextFetch = false}) {
    _cachedOverrides = null;
    _overridesCachedAt = null;
    if (forceRevertOnNextFetch) {
      _lastRevertExpiredAt = null;
    }
  }

  Future<void> _maybeRevertExpired({bool force = false}) async {
    final now = DateTime.now();
    if (!force &&
        _lastRevertExpiredAt != null &&
        now.difference(_lastRevertExpiredAt!) < _revertExpiredThrottle) {
      return;
    }
    if (_revertInFlight != null) {
      await _revertInFlight;
      return;
    }
    final future = revertExpiredTempManagerCalls().then((reverted) {
      _lastRevertExpiredAt = DateTime.now();
      if (reverted > 0) {
        invalidateTempManagerCache();
      }
      return reverted;
    });
    _revertInFlight = future;
    try {
      await future;
    } finally {
      if (identical(_revertInFlight, future)) {
        _revertInFlight = null;
      }
    }
  }

  Future<List<TempManagerOverride>> _fetchTempOverridesRemote() async {
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

  Future<List<TempManagerOverride>> _getOverridesCached({
    bool force = false,
  }) async {
    final now = DateTime.now();
    if (!force &&
        _cachedOverrides != null &&
        _overridesCachedAt != null &&
        now.difference(_overridesCachedAt!) < _tempOverridesCacheTtl) {
      return _cachedOverrides!;
    }
    if (_overridesInFlight != null) {
      return _overridesInFlight!;
    }
    final future = _fetchTempOverridesRemote().then((rows) {
      _cachedOverrides = rows;
      _overridesCachedAt = DateTime.now();
      return rows;
    });
    _overridesInFlight = future;
    try {
      return await future;
    } finally {
      if (identical(_overridesInFlight, future)) {
        _overridesInFlight = null;
      }
    }
  }

  /// 목록·검색 조회 전 — 만료 원복(스로틀) + 오버라이드 캐시 1회.
  Future<List<TempManagerOverride>> _prepareListFetchContext({
    bool force = false,
  }) async {
    await _maybeRevertExpired(force: force);
    return _getOverridesCached(force: force);
  }

  /// PostgREST/Supabase `api.max_rows` (see `supabase/config.toml`).
  static const int postgrestMaxPageSize = 1000;

  /// 목록·홈 집계 기본 페이지 크기 — UI 「더 보기」와 동일.
  static const int listPageSize = 50;

  static const String _regionSelect = 'id,sido,region,manager,branch_type';
  static const String _callHistorySelect =
      'id,sales_call_id,call_stage,consultation_content,next_scheduled_date,unsuccessful_reason,status,status_id,created_at,created_by';

  /// 품질 지표(첫 응답 시간)용 — 전체 상담 이력 대신 `created_at`만 조인.
  static const String _callHistoryQualitySelect = 'created_at';

  /// 목록/집계용 — `images` 등 대용량 컬럼 제외, 화면 표시에 필요한 필드만.
  static const String _listSelect =
      '''
        id, call_date, call_time, customer_name, customer_phone, inquiry_content,
        product_category_id, inquiry_method_id, region_id, status_id, assigned_to,
        created_by, call_stage, next_scheduled_date, region_sido, region_name,
        region_manager, region_branch_type, created_at, updated_at,
        product_categories(name),
        inquiry_methods(name),
        call_statuses(name),
        regions($_regionSelect)
      ''';

  /// 상세 조회용 — 첨부 이미지 포함.
  static const String _detailSelect =
      '''
        *,
        product_categories(name),
        inquiry_methods(name),
        call_statuses(name),
        regions($_regionSelect)
      ''';

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

  Future<List<TempManagerOverride>> fetchTempOverrides({
    bool force = false,
  }) async {
    await _maybeRevertExpired(force: force);
    return _getOverridesCached(force: force);
  }

  /// 기간 만료된 임시 담당 접수 건을 original_manager로 DB 원복 (웹 revert-expired API와 동일).
  /// BASE_URL이 있으면 Next API를 우선 호출하고, 없으면 Supabase로 직접 원복한다.
  Future<int> revertExpiredTempManagerCalls() async {
    final base = _deps.effectiveBaseUrl;
    if (base.isNotEmpty) {
      try {
        final res = await _deps.transport.request(
          baseUrl: base,
          method: 'POST',
          path: '/api/temp-manager/revert-expired',
        );
        if (res.statusCode >= 200 && res.statusCode < 300) {
          if (res.body.isNotEmpty) {
            final decoded = jsonDecode(res.body);
            if (decoded is Map<String, dynamic>) {
              return (decoded['revertedCount'] as num?)?.toInt() ?? 0;
            }
          }
          return 0;
        }
      } catch (_) {
        // API 실패 시 Supabase 직접 원복으로 폴백
      }
    }
    return _revertExpiredViaSupabase();
  }

  Future<int> _revertExpiredViaSupabase() async {
    final todayYmd = todayYmdSeoul();
    final overrides = await _fetchTempOverridesRemote();
    final expired = overrides
        .where((o) => isTempOverrideExpired(o, todayYmd))
        .toList();
    if (expired.isEmpty) return 0;

    final regionNames = expired
        .map((o) => o.regionName.trim())
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList();
    if (regionNames.isEmpty) return 0;

    final callRes = await _client
        .from('sales_calls')
        .select('id, assigned_to, call_date, created_at, region_name')
        .inFilter('region_name', regionNames);

    final revertTargets = <String, String>{};
    for (final row in callRes) {
      final call = SalesCall.fromJson(Map<String, dynamic>.from(row));
      for (final o in expired) {
        if (shouldRevertCallToOriginal(call, o, todayYmd)) {
          revertTargets[call.id] = o.originalManager.trim();
          break;
        }
      }
    }
    if (revertTargets.isEmpty) return 0;

    final byManager = <String, List<String>>{};
    for (final e in revertTargets.entries) {
      byManager.putIfAbsent(e.value, () => []).add(e.key);
    }

    final now = DateTime.now().toUtc().toIso8601String();
    for (final entry in byManager.entries) {
      await _client
          .from('sales_calls')
          .update({'assigned_to': entry.key, 'updated_at': now})
          .inFilter('id', entry.value);
    }
    return revertTargets.length;
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
  Future<List<SalesCall>> fetchCachedCalls({
    String? date,
    bool? incompleteOnly,
  }) async {
    final res = await _db.getSalesCalls(date: date, statusId: null, limit: 200);
    var parsed = parseSalesCallList(res);
    if (incompleteOnly == true) {
      parsed = parsed.where((c) => c.isMissed).toList();
    }
    return parsed;
  }

  /// [followDate] `yyyy-MM-dd` — `next_scheduled_date`가 해당 날짜인 건만 (날짜 팔로우).
  /// [followRangeStart]·[followRangeEndInclusive] — 팔로우 날짜 **구간**(양끝 포함, `next_scheduled_date` 기준).
  /// [dateRangeStart]·[dateRangeEndInclusive] — 접수일 `call_date` **구간**(양끝 포함).
  /// [updatedAtRangeStartYmd]·[updatedAtRangeEndInclusiveYmd] — `updated_at` 서울 일자 구간(양끝 포함).
  /// [date]가 함께 넘어오면 [followDate]가 우선이며, 접수일(`call_date`) 필터는 적용하지 않음.
  Future<List<SalesCall>> fetchCalls({
    String? date,
    String? followDate,
    String? followRangeStart,
    String? followRangeEndInclusive,
    String? dateRangeStart,
    String? dateRangeEndInclusive,
    String? updatedAtRangeStartYmd,
    String? updatedAtRangeEndInclusiveYmd,
    String? fromDate,
    int? limit,
    int? offset,
    bool includeCallHistory = true,
    bool callHistoryQualityOnly = false,
    bool? incompleteOnly,
    bool? uncalledOnly,
    bool? completedOnly,
    bool excludeSimpleInquiries = false,
    bool calendarFull = false,
    bool cacheLocally = true,
  }) async {
    final batch = await _fetchCallsBatch(
      date: date,
      followDate: followDate,
      followRangeStart: followRangeStart,
      followRangeEndInclusive: followRangeEndInclusive,
      dateRangeStart: dateRangeStart,
      dateRangeEndInclusive: dateRangeEndInclusive,
      updatedAtRangeStartYmd: updatedAtRangeStartYmd,
      updatedAtRangeEndInclusiveYmd: updatedAtRangeEndInclusiveYmd,
      fromDate: fromDate,
      limit: limit,
      offset: offset,
      includeCallHistory: includeCallHistory,
      callHistoryQualityOnly: callHistoryQualityOnly,
      incompleteOnly: incompleteOnly,
      uncalledOnly: uncalledOnly,
      completedOnly: completedOnly,
      excludeSimpleInquiries: excludeSimpleInquiries,
      calendarFull: calendarFull,
      cacheLocally: cacheLocally,
    );
    return batch.items;
  }

  /// 한 페이지 조회 — 목록 화면 초기 로드·「더 보기」용.
  /// [hasMore]는 **서버 raw 행 수** 기준(클라이언트 후처리 전).
  Future<({List<SalesCall> items, bool hasMore, int rawRowCount})>
  fetchCallsPage({
    String? date,
    String? followDate,
    String? followRangeStart,
    String? followRangeEndInclusive,
    String? dateRangeStart,
    String? dateRangeEndInclusive,
    String? updatedAtRangeStartYmd,
    String? updatedAtRangeEndInclusiveYmd,
    String? fromDate,
    int limit = listPageSize,
    int offset = 0,
    bool includeCallHistory = false,
    bool callHistoryQualityOnly = false,
    bool? incompleteOnly,
    bool? uncalledOnly,
    bool? completedOnly,
    bool excludeSimpleInquiries = false,
    bool calendarFull = false,
    bool cacheLocally = true,
    bool fullDetail = false,
  }) async {
    final batch = await _fetchCallsBatch(
      date: date,
      followDate: followDate,
      followRangeStart: followRangeStart,
      followRangeEndInclusive: followRangeEndInclusive,
      dateRangeStart: dateRangeStart,
      dateRangeEndInclusive: dateRangeEndInclusive,
      updatedAtRangeStartYmd: updatedAtRangeStartYmd,
      updatedAtRangeEndInclusiveYmd: updatedAtRangeEndInclusiveYmd,
      fromDate: fromDate,
      limit: limit,
      offset: offset,
      includeCallHistory: includeCallHistory,
      callHistoryQualityOnly: callHistoryQualityOnly,
      incompleteOnly: incompleteOnly,
      uncalledOnly: uncalledOnly,
      completedOnly: completedOnly,
      excludeSimpleInquiries: excludeSimpleInquiries,
      calendarFull: calendarFull,
      cacheLocally: cacheLocally,
      fullDetail: fullDetail,
    );
    return (
      items: batch.items,
      hasMore: batch.rawRowCount >= limit,
      rawRowCount: batch.rawRowCount,
    );
  }

  /// [fetchCalls]와 동일 조건으로 PostgREST 페이지를 반복 조회해 전체를 합칩니다.
  /// `uncalledOnly` 등 클라이언트 후처리가 있어도, 다음 페이지 여부는 **서버 raw 행 수**로 판단합니다.
  /// 홈 집계·배지 등 **전체 기간 합계가 필요한 경우**에만 사용하세요. 목록 UI는 [fetchCallsPage] 권장.
  Future<List<SalesCall>> fetchCallsAllPages({
    String? date,
    String? followDate,
    String? followRangeStart,
    String? followRangeEndInclusive,
    String? dateRangeStart,
    String? dateRangeEndInclusive,
    String? updatedAtRangeStartYmd,
    String? updatedAtRangeEndInclusiveYmd,
    String? fromDate,
    bool includeCallHistory = true,
    bool callHistoryQualityOnly = false,
    bool? incompleteOnly,
    bool? uncalledOnly,
    bool? completedOnly,
    bool excludeSimpleInquiries = false,
    bool calendarFull = false,
    bool cacheLocally = true,
    int pageSize = postgrestMaxPageSize,
    bool fullDetail = false,
  }) async {
    final overrides = await _prepareListFetchContext();
    final merged = <SalesCall>[];
    var offset = 0;
    while (true) {
      final batch = await _fetchCallsBatch(
        date: date,
        followDate: followDate,
        followRangeStart: followRangeStart,
        followRangeEndInclusive: followRangeEndInclusive,
        dateRangeStart: dateRangeStart,
        dateRangeEndInclusive: dateRangeEndInclusive,
        updatedAtRangeStartYmd: updatedAtRangeStartYmd,
        updatedAtRangeEndInclusiveYmd: updatedAtRangeEndInclusiveYmd,
        fromDate: fromDate,
        limit: pageSize,
        offset: offset,
        includeCallHistory: includeCallHistory,
        callHistoryQualityOnly: callHistoryQualityOnly,
        incompleteOnly: incompleteOnly,
        uncalledOnly: uncalledOnly,
        completedOnly: completedOnly,
        excludeSimpleInquiries: excludeSimpleInquiries,
        calendarFull: calendarFull,
        cacheLocally: cacheLocally,
        overrides: overrides,
        fullDetail: fullDetail,
      );
      merged.addAll(batch.items);
      if (batch.rawRowCount < pageSize) break;
      offset += pageSize;
    }
    return merged;
  }

  Future<({List<SalesCall> items, int rawRowCount})> _fetchCallsBatch({
    String? date,
    String? followDate,
    String? followRangeStart,
    String? followRangeEndInclusive,
    String? dateRangeStart,
    String? dateRangeEndInclusive,
    String? updatedAtRangeStartYmd,
    String? updatedAtRangeEndInclusiveYmd,
    String? fromDate,
    int? limit,
    int? offset,
    bool includeCallHistory = true,
    bool callHistoryQualityOnly = false,
    bool? incompleteOnly,
    bool? uncalledOnly,
    bool? completedOnly,
    bool excludeSimpleInquiries = false,
    bool calendarFull = false,
    bool cacheLocally = true,
    bool fullDetail = false,
    List<TempManagerOverride>? overrides,
  }) async {
    try {
      final resolvedOverrides = overrides ?? await _prepareListFetchContext();

      // 목록·집계는 images 등 대용량 필드 제외. 상세만 fullDetail.
      var selectStr = fullDetail ? _detailSelect : _listSelect;

      if (includeCallHistory) {
        final historyCols = callHistoryQualityOnly
            ? _callHistoryQualitySelect
            : _callHistorySelect;
        selectStr += ', call_history($historyCols)';
      }

      PostgrestFilterBuilder<List<Map<String, dynamic>>> queryBuilder = _client
          .from('sales_calls')
          .select(selectStr);

      final updatedStartYmd = updatedAtRangeStartYmd;
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
      } else if (updatedStartYmd != null) {
        // 서울 일자 경계 — coad_home 금일 업데이트와 동일(updated_at 기준).
        final endYmd = updatedAtRangeEndInclusiveYmd ?? updatedStartYmd;
        final startIso = '${updatedStartYmd}T00:00:00+09:00';
        final endExclusiveIso = '${_ymdPlusOneDay(endYmd)}T00:00:00+09:00';
        queryBuilder = queryBuilder
            .gte('updated_at', startIso)
            .lt('updated_at', endExclusiveIso);
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
      PostgrestTransformBuilder<List<Map<String, dynamic>>> transformBuilder =
          queryBuilder.order(
            updatedStartYmd != null ? 'updated_at' : 'created_at',
            ascending: false,
          );

      if (limit != null) {
        int rTop = (offset ?? 0) + limit - 1;
        transformBuilder = transformBuilder.range(offset ?? 0, rTop);
      }

      final res = await transformBuilder;
      final rawRowCount = res.length;

      // 로컬 DB 동기화 (Upsert) — 달력 등 일회성 목록은 생략 가능.
      if (cacheLocally && res.isNotEmpty) {
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
        parsed = parsed.where((c) => ![2, 3, 4].contains(c.statusId)).toList();
      }

      if (excludeSimpleInquiries) {
        parsed = parsed.where((c) => c.statusId != 4).toList();
      }
      return (
        items: applyCallDisplayOverrides(
          parsed,
          resolvedOverrides,
          DateTime.now(),
        ),
        rawRowCount: rawRowCount,
      );
    } catch (e) {
      throw ApiException('통화 목록을 불러오는데 실패했습니다: $e');
    }
  }

  Future<SalesCall> fetchCallById(String id) async {
    try {
      final overrides = await _prepareListFetchContext();

      final res = await _client
          .from('sales_calls')
          .select('''
        $_detailSelect,
        call_history($_callHistorySelect)
      ''')
          .eq('id', id)
          .maybeSingle();

      if (res == null) {
        throw ApiException('통화를 찾을 수 없습니다.', statusCode: 404);
      }

      // 개별 상세 조회 시에도 캐시 업데이트
      await _db.saveSalesCalls([res]);

      final call = SalesCall.fromJson(res);
      return applyCallDisplayOverrides([call], overrides, DateTime.now()).first;
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('통화 상세 정보를 가져오는데 실패했습니다: $e');
    }
  }

  Future<SalesCall> createCall(Map<String, dynamic> body) async {
    try {
      final res = await _client
          .from('sales_calls')
          .insert(body)
          .select()
          .single();
      return fetchCallById(res['id']);
    } catch (e) {
      if (e is SocketException ||
          e.toString().contains('SocketException') ||
          e.toString().contains('Failed host lookup')) {
        await _db.savePendingCall(body);
        throw OfflineException();
      }
      throw ApiException('등록에 실패했습니다: $e');
    }
  }

  Future<SalesCall> createSalesCall(SalesCallDraft draft) {
    return createCall(draft.toInsertJson());
  }

  /// 오프라인 중 등록된 접수·상담을 서버로 동기화.
  Future<int> syncPendingCalls() async {
    final pendings = await _db.getPendingCalls();

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
    successCount += await syncPendingConsultations();
    return successCount;
  }

  /// 동기화 대기 총 건수 — 오프라인 접수 + 오프라인 상담.
  Future<int> getPendingCount() async {
    final calls = await _db.getPendingCalls();
    final consultations = await _db.getPendingConsultations();
    return calls.length + consultations.length;
  }

  Future<SalesCall> updateCall(String id, Map<String, dynamic> body) async {
    try {
      await _client.from('sales_calls').update(body).eq('id', id);
      return fetchCallById(id);
    } catch (e) {
      throw ApiException('수정에 실패했습니다: $e');
    }
  }

  Future<void> deleteCall(String id) async {
    try {
      await _client.from('call_history').delete().eq('sales_call_id', id);
      await _client.from('sales_calls').delete().eq('id', id);
      await _db.deleteSalesCall(id);
      invalidateTempManagerCache(forceRevertOnNextFetch: true);
    } catch (e) {
      throw ApiException('삭제에 실패했습니다: $e');
    }
  }

  Future<void> addCallHistory(
    String callId,
    Map<String, dynamic> historyData,
  ) async {
    try {
      await _client.from('call_history').insert({
        ...historyData,
        'sales_call_id': callId,
      });
    } catch (e) {
      throw ApiException('상담 이력 저장에 실패했습니다: $e');
    }
  }

  /// 상담 저장: history INSERT 후 sales_calls UPDATE (웹과 동일 순서)
  /// 네트워크 오류면 로컬 큐(`pending_consultations`)에 저장 후 [OfflineException].
  Future<void> _patchLocalSalesCallFromBody(
    String callId,
    Map<String, dynamic> salesCallBody,
  ) async {
    final cached = await _db.getSalesCallById(callId);
    if (cached == null) return;
    final merged = Map<String, dynamic>.from(cached)..addAll(salesCallBody);
    await _db.saveSalesCalls([merged]);
  }

  Future<SalesCall> saveConsultationRound({
    required String callId,
    required Map<String, dynamic> historyData,
    required Map<String, dynamic> salesCallBody,
  }) async {
    try {
      await addCallHistory(callId, historyData);
    } catch (e) {
      if (isNetworkConnectivityError(e)) {
        await _db.savePendingConsultation(
          callId: callId,
          historyData: historyData,
          salesCallBody: salesCallBody,
          includeHistory: true,
        );
        await _patchLocalSalesCallFromBody(callId, salesCallBody);
        throw OfflineException('오프라인 — 상담 내용이 저장되어 연결 시 자동 전송됩니다.');
      }
      rethrow;
    }
    try {
      return await updateCall(callId, salesCallBody);
    } catch (e) {
      if (isNetworkConnectivityError(e)) {
        // 이력은 이미 서버에 들어감 — 상태 업데이트만 큐잉.
        await _db.savePendingConsultation(
          callId: callId,
          historyData: historyData,
          salesCallBody: salesCallBody,
          includeHistory: false,
        );
        await _patchLocalSalesCallFromBody(callId, salesCallBody);
        throw OfflineException('오프라인 — 상담 내용이 저장되어 연결 시 자동 전송됩니다.');
      }
      rethrow;
    }
  }

  /// 오프라인 큐의 상담 저장분을 서버로 재전송.
  Future<int> syncPendingConsultations() async {
    final pendings = await _db.getPendingConsultations();
    if (pendings.isEmpty) return 0;

    var successCount = 0;
    for (final item in pendings) {
      final id = item['id'] as int;
      final callId = item['call_id'] as String;
      final historyData = item['history_data'] as Map<String, dynamic>;
      final body = item['sales_call_body'] as Map<String, dynamic>;
      final includeHistory = item['include_history'] as bool;
      try {
        if (includeHistory) {
          await addCallHistory(callId, historyData);
        }
        await _client.from('sales_calls').update(body).eq('id', callId);
        await _db.deletePendingConsultation(id);
        successCount++;
      } catch (_) {
        // 여전히 오프라인이거나 데이터 오류 — 다음 동기화 때 재시도.
      }
    }
    return successCount;
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
    return fetchStatsForDateRange(ymdSeoul, ymdSeoul);
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
      if (e is ApiException) rethrow;
      if (isNetworkConnectivityError(e)) {
        throw ApiException('통계를 불러오지 못했습니다. 네트워크 연결을 확인해 주세요.');
      }
      throw ApiException('통계 데이터를 불러오는데 실패했습니다: $e');
    }
  }

  /// 홈 미통화 배지·담당자 집계용 **경량** 조회 — 요약에 필요한 컬럼만.
  /// 조인·call_history·로컬 DB upsert 없음. `isMissed` 판정 컬럼과
  /// 접수일([call_date]·[call_time]·[created_at]), 담당 표시([assigned_to]·[region_name])만 내려받는다.
  Future<List<SalesCall>> fetchPendingUncalledLite({
    required String fromYmd,
  }) async {
    const cols =
        'id, call_date, call_time, created_at, status_id, call_stage, '
        'assigned_to, region_name';
    try {
      final merged = <SalesCall>[];
      var offset = 0;
      while (true) {
        final res = await _client
            .from('sales_calls')
            .select(cols)
            .gte('call_date', '$fromYmd 00:00:00')
            .neq('status_id', 4)
            .order('created_at', ascending: false)
            .range(offset, offset + postgrestMaxPageSize - 1);
        merged.addAll(parseSalesCallList(res).where((c) => c.isMissed));
        if (res.length < postgrestMaxPageSize) break;
        offset += postgrestMaxPageSize;
      }
      return merged;
    } catch (e) {
      if (isNetworkConnectivityError(e)) {
        throw ApiException('미통화 현황을 불러오지 못했습니다. 네트워크 연결을 확인해 주세요.');
      }
      throw ApiException('미통화 현황을 불러오는데 실패했습니다: $e');
    }
  }

  Future<List<SalesCall>> searchCalls(String query, {int limit = 50}) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];

    try {
      final q = '%$trimmed%';
      final orParts = <String>[
        'customer_name.ilike.$q',
        'inquiry_content.ilike.$q',
        'region_sido.ilike.$q',
        'region_name.ilike.$q',
      ];
      for (final phonePattern in phoneSearchPatterns(trimmed)) {
        orParts.add('customer_phone.ilike.%$phonePattern%');
      }

      final res = await _client
          .from('sales_calls')
          .select(_listSelect)
          .or(orParts.join(','))
          .order('created_at', ascending: false)
          .limit(limit);

      final overrides = await _prepareListFetchContext();
      final parsed = parseSalesCallList(res);
      return applyCallDisplayOverrides(parsed, overrides, DateTime.now());
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
