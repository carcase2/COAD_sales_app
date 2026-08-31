import 'package:coad_customer_calls/core/constants/gosu_appsheet.dart';
import 'package:coad_customer_calls/core/network/api_exception.dart';
import 'package:coad_customer_calls/core/utils/date_seoul.dart';
import 'package:coad_customer_calls/core/utils/gosu_calls_utils.dart';
import 'package:coad_customer_calls/core/utils/phone_validation.dart';
import 'package:coad_customer_calls/models/gosu_sales_call.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum GosuListMode {
  todayReception,
  todayUpdated,
  awaitingFollowUp,
  activeFollowUp,
  closed,
  scheduled,
  dateRange,
  updatedRange,
  followRange,
}

class GosuHomeCounts {
  const GosuHomeCounts({
    required this.periodReception,
    required this.periodUpdated,
    required this.awaitingFollowUp,
    required this.activeFollowUp,
    required this.scheduled,
  });

  final int periodReception;
  final int periodUpdated;
  final int awaitingFollowUp;
  final int activeFollowUp;
  final int scheduled;

  static const empty = GosuHomeCounts(
    periodReception: 0,
    periodUpdated: 0,
    awaitingFollowUp: 0,
    activeFollowUp: 0,
    scheduled: 0,
  );
}

class GosuListPage {
  const GosuListPage({required this.items, required this.hasMore});

  final List<GosuSalesCall> items;
  final bool hasMore;
}

class GosuSalesCallsRepository {
  GosuSalesCallsRepository();

  final SupabaseClient _client = Supabase.instance.client;

  static const int listPageSize = 50;
  static const String _listSelect = '''
        id, call_date, call_time, customer_name, customer_phone, inquiry_content,
        status_id, assigned_to, created_by, created_at, updated_at,
        region_sido, region_name, region_label, region_manager, region_branch_type,
        product_category_name, inquiry_method_name, status_name,
        follow_up, follow_up_content, call_stage, next_scheduled_date, source
      ''';

  PostgrestFilterBuilder<T> _applyOpenFilter<T>(PostgrestFilterBuilder<T> q) {
    return q.or('follow_up.is.null,follow_up.neq.$kGosuProgressClosed');
  }

  /// 미종료 건. 팔로업중 = 종료 전 전체, 기존진행중 = 1차 이후.
  Future<List<GosuSalesCall>> _fetchOpenCalls({int limit = 4000}) async {
    final res = await _client
        .from('gosu_sales_calls')
        .select(_listSelect)
        .or('follow_up.is.null,follow_up.neq.$kGosuProgressClosed')
        .order('created_at', ascending: false)
        .limit(limit);
    return res
        .whereType<Map>()
        .map((e) => GosuSalesCall.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  PostgrestFilterBuilder<int> _countQuery() =>
      _client.from('gosu_sales_calls').count(CountOption.exact);

  Future<GosuHomeCounts> fetchHomeCounts({
    required String fromYmd,
    required String toYmdInclusive,
  }) async {
    try {
      final startIso = '${fromYmd}T00:00:00+09:00';
      final endExclusiveIso =
          '${addDaysToYmd(toYmdInclusive, 1)}T00:00:00+09:00';

      final reception = await _countQuery()
          .gte('call_date', fromYmd)
          .lte('call_date', toYmdInclusive);
      final updated = await _countQuery()
          .gte('updated_at', startIso)
          .lt('updated_at', endExclusiveIso);
      final open = await _fetchOpenCalls();
      return GosuHomeCounts(
        periodReception: reception,
        periodUpdated: updated,
        awaitingFollowUp: open.where(isGosuFollowUpOpen).length,
        activeFollowUp: open.where(isGosuActiveFollowUp).length,
        scheduled: open.where(isGosuCalendarScheduled).length,
      );
    } catch (e) {
      throw ApiException('자동문의고수 현황을 불러오지 못했습니다. $e');
    }
  }

  Future<GosuListPage> fetchCallsPage({
    required GosuListMode mode,
    String? fromYmd,
    String? toYmdInclusive,
    int offset = 0,
    int? limit,
  }) async {
    final pageSize =
        limit ??
        switch (mode) {
          GosuListMode.todayReception ||
          GosuListMode.dateRange ||
          GosuListMode.todayUpdated ||
          GosuListMode.updatedRange => 1000,
          _ => listPageSize,
        };
    try {
      var query = _client.from('gosu_sales_calls').select(_listSelect);
      switch (mode) {
        case GosuListMode.todayReception:
        case GosuListMode.dateRange:
          final from = fromYmd ?? todayYmdSeoul();
          final to = toYmdInclusive ?? from;
          query = query.gte('call_date', from).lte('call_date', to);
        case GosuListMode.todayUpdated:
        case GosuListMode.updatedRange:
          final from = fromYmd ?? todayYmdSeoul();
          final to = toYmdInclusive ?? from;
          query = query
              .gte('updated_at', '${from}T00:00:00+09:00')
              .lt('updated_at', '${addDaysToYmd(to, 1)}T00:00:00+09:00');
        case GosuListMode.awaitingFollowUp:
        case GosuListMode.activeFollowUp:
          final open = await _fetchOpenCalls();
          final all = mode == GosuListMode.awaitingFollowUp
              ? open.where(isGosuFollowUpOpen).toList()
              : open.where(isGosuActiveFollowUp).toList();
          final slice = all.skip(offset).take(pageSize).toList();
          return GosuListPage(
            items: slice,
            hasMore: offset + slice.length < all.length,
          );
        case GosuListMode.closed:
          query = query.eq('follow_up', kGosuProgressClosed);
        case GosuListMode.scheduled:
        case GosuListMode.followRange:
          query = _applyOpenFilter(
            query,
          ).not('next_scheduled_date', 'is', null);
          if (fromYmd != null) {
            query = query.gte('next_scheduled_date', fromYmd);
          }
          if (toYmdInclusive != null) {
            query = query.lte('next_scheduled_date', toYmdInclusive);
          }
      }

      final res = await query
          .order('created_at', ascending: false)
          .range(offset, offset + pageSize - 1);
      final items = res
          .whereType<Map>()
          .map((e) => GosuSalesCall.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      return GosuListPage(items: items, hasMore: items.length >= pageSize);
    } catch (e) {
      throw ApiException('자동문의고수 목록을 불러오지 못했습니다. $e');
    }
  }

  Future<List<GosuSalesCall>> fetchScheduledForCalendar({
    required String fromYmd,
    required String toYmdInclusive,
  }) async {
    final page = await fetchCallsPage(
      mode: GosuListMode.followRange,
      fromYmd: fromYmd,
      toYmdInclusive: toYmdInclusive,
      offset: 0,
      limit: 1000,
    );
    return page.items.where(isGosuCalendarScheduled).toList();
  }

  Future<GosuSalesCall> fetchById(String id) async {
    try {
      final row = await _client
          .from('gosu_sales_calls')
          .select()
          .eq('id', id)
          .maybeSingle();
      if (row == null) {
        throw ApiException('접수를 찾을 수 없습니다.');
      }
      final history = await _client
          .from('gosu_call_history')
          .select()
          .eq('gosu_sales_call_id', id)
          .order('call_stage', ascending: true);
      final json = Map<String, dynamic>.from(row);
      json['call_history'] = history;
      return GosuSalesCall.fromJson(json);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('자동문의고수 상세를 불러오지 못했습니다. $e');
    }
  }

  Future<List<GosuSalesCall>> findByPhone(String phone, {int limit = 8}) async {
    final digits = normalizePhoneDigits(phone);
    if (digits.length < 8) return const [];
    try {
      final patterns = phoneSearchPatterns(digits);
      final orParts = <String>[
        for (final p in patterns) 'customer_phone.ilike.%$p%',
      ];
      final res = await _client
          .from('gosu_sales_calls')
          .select(_listSelect)
          .or(orParts.join(','))
          .order('created_at', ascending: false)
          .limit(limit);
      return res
          .whereType<Map>()
          .map((e) => GosuSalesCall.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      throw ApiException('전화번호 검색에 실패했습니다. $e');
    }
  }

  Future<List<String>> fetchAssignees() async {
    try {
      final groups = await _client
          .from('groups')
          .select('id, name')
          .eq('name', kGosuGroupName);
      final groupIds = groups
          .whereType<Map>()
          .map((e) => e['id']?.toString())
          .whereType<String>()
          .where((id) => id.isNotEmpty)
          .toList();
      if (groupIds.isEmpty) return const [];

      final names = <String>{};
      final byGroup = await _client
          .from('users')
          .select('name, is_active, group_id')
          .inFilter('group_id', groupIds);
      for (final u in byGroup.whereType<Map>()) {
        if (u['is_active'] == false) continue;
        final name = (u['name'] ?? '').toString().trim();
        if (name.isNotEmpty) names.add(name);
      }
      final list = names.toList()..sort((a, b) => a.compareTo(b));
      return list;
    } catch (_) {
      return const [];
    }
  }

  Future<GosuSalesCall> createCall({
    required String customerName,
    required String customerPhone,
    required String inquiryContent,
    String? productCategoryName,
    int? productCategoryId,
    String? inquiryMethodName,
    int? inquiryMethodId,
    int? regionId,
    String? regionSido,
    String? regionName,
    String? regionManager,
    String? regionBranchType,
    String? regionLabel,
    String? assignedTo,
    required String createdBy,
    List<String> images = const [],
    bool closeImmediately = false,
    String closeNote = '',
  }) async {
    if (customerPhone.trim().isEmpty || inquiryContent.trim().isEmpty) {
      throw ApiException('연락처와 문의 내용은 필수입니다.');
    }
    if (closeImmediately && closeNote.trim().isEmpty) {
      throw ApiException('종료 접수 시 처리·안내 내용을 입력해주세요.');
    }
    try {
      final parts = seoulNowCallDateTimeParts();
      var assigned = assignedTo?.trim() ?? '';
      if (assigned.isEmpty || assigned == '시스템') {
        final manager = regionManager?.trim() ?? '';
        assigned = manager.isNotEmpty && manager != '시스템' ? manager : createdBy;
      }
      final statusId = closeImmediately ? 4 : 1;
      final statusName = closeImmediately ? '단순문의' : '미결정';
      final row = await _client
          .from('gosu_sales_calls')
          .insert({
            'call_date': parts.ymd,
            'call_time': parts.hms,
            'product_category_id': productCategoryId,
            'product_category_name': productCategoryName,
            'customer_name': customerName.trim().isEmpty
                ? '상호없음'
                : customerName.trim(),
            'customer_phone': customerPhone.trim(),
            'region_id': regionId,
            'inquiry_method_id': inquiryMethodId,
            'inquiry_method_name': inquiryMethodName,
            'inquiry_content': inquiryContent.trim(),
            'status_id': statusId,
            'status_name': statusName,
            'assigned_to': assigned,
            'created_by': createdBy,
            if (images.isNotEmpty) 'images': images,
            'region_sido': regionSido,
            'region_name': regionName,
            'region_manager': regionManager,
            'region_branch_type': regionBranchType,
            'region_label': regionLabel,
            'follow_up': closeImmediately
                ? kGosuProgressClosed
                : kGosuProgressOpen,
            'follow_up_content': closeImmediately ? closeNote.trim() : null,
            'call_stage': closeImmediately ? 1 : 0,
            'next_scheduled_date': null,
            'source': 'app',
          })
          .select()
          .single();

      if (closeImmediately) {
        await _client.from('gosu_call_history').insert({
          'gosu_sales_call_id': row['id'],
          'call_date': parts.ymd,
          'call_time': parts.hms,
          'call_stage': 1,
          'consultation_content': closeNote.trim(),
          'next_scheduled_date': null,
          'follow_result': kGosuProgressClosed,
          'created_by': createdBy,
        });
      }
      return fetchById(row['id'].toString());
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('자동문의고수 접수에 실패했습니다. $e');
    }
  }

  Future<GosuSalesCall> updateCall(String id, Map<String, dynamic> body) async {
    try {
      await _client.from('gosu_sales_calls').update(body).eq('id', id);
      return fetchById(id);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('수정에 실패했습니다. $e');
    }
  }

  Future<void> deleteCall(String id) async {
    try {
      await _client
          .from('gosu_call_history')
          .delete()
          .eq('gosu_sales_call_id', id);
      await _client.from('gosu_sales_calls').delete().eq('id', id);
    } catch (e) {
      throw ApiException('삭제에 실패했습니다. $e');
    }
  }

  Future<GosuSalesCall> saveFollowUp({
    required String callId,
    required String consultationContent,
    required String followResult,
    String? nextScheduledDate,
    required String createdBy,
  }) async {
    final error = validateGosuFollowUpForm(
      consultationContent: consultationContent,
      nextScheduledDate: nextScheduledDate ?? '',
      followResult: followResult,
    );
    if (error != null) throw ApiException(error);

    try {
      final call = await fetchById(callId);
      final nextStage = getNextGosuFollowUpStage(
        call.callHistory.length,
        call.callStage,
      );
      final parts = seoulNowCallDateTimeParts();
      final scheduled = followResult == kGosuProgressOpen
          ? (nextScheduledDate?.trim().isEmpty == true
                ? null
                : nextScheduledDate!.trim())
          : null;

      await _client.from('gosu_call_history').insert({
        'gosu_sales_call_id': callId,
        'call_date': parts.ymd,
        'call_time': parts.hms,
        'call_stage': nextStage,
        'consultation_content': consultationContent.trim(),
        'next_scheduled_date': scheduled,
        'follow_result': followResult,
        'created_by': createdBy,
      });

      await _client
          .from('gosu_sales_calls')
          .update({
            'call_stage': nextStage,
            'next_scheduled_date': scheduled,
            'follow_up': followResult,
            'follow_up_content': consultationContent.trim(),
          })
          .eq('id', callId);

      return fetchById(callId);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('팔로업 저장에 실패했습니다. $e');
    }
  }
}
