import 'dart:convert';

import 'package:coad_customer_calls/core/network/api_exception.dart';
import 'package:coad_customer_calls/core/utils/date_seoul.dart';
import 'package:coad_customer_calls/data/support_supabase.dart';

class SupportCallLog {
  const SupportCallLog({
    required this.id,
    required this.customerName,
    required this.customerPhone,
    required this.issue,
    this.address,
    this.createdBy,
    this.createdAt,
    this.callDate,
    this.firstImageUrls = const [],
    this.secondImageUrls = const [],
  });

  final String id;
  final String customerName;
  final String customerPhone;
  final String issue;
  final String? address;
  final String? createdBy;
  final DateTime? createdAt;
  final DateTime? callDate;
  final List<String> firstImageUrls;
  final List<String> secondImageUrls;

  List<String> get attachmentUrls => [...firstImageUrls, ...secondImageUrls];

  factory SupportCallLog.fromJson(Map<String, dynamic> json) {
    DateTime? parseTime(Object? raw) {
      if (raw == null) return null;
      return DateTime.tryParse(raw.toString());
    }

    return SupportCallLog(
      id: (json['id'] ?? '').toString(),
      customerName: (json['customer_name'] ?? '').toString(),
      customerPhone: (json['customer_phone'] ?? '').toString(),
      issue: (json['issue'] ?? '').toString(),
      address: json['address']?.toString(),
      createdBy: json['created_by']?.toString(),
      createdAt: parseTime(json['created_at']),
      callDate: parseTime(json['call_date']),
      firstImageUrls: parseSupportUrlList(json['first_image_urls']),
      secondImageUrls: parseSupportUrlList(json['second_image_urls']),
    );
  }
}

class SupportHomePeriodStats {
  const SupportHomePeriodStats({
    required this.reception,
    required this.pending,
    required this.visits,
    required this.updated,
  });

  final int reception;
  final int pending;
  final int visits;
  final int updated;

  static const empty = SupportHomePeriodStats(
    reception: 0,
    pending: 0,
    visits: 0,
    updated: 0,
  );
}

class SupportCallLogDraft {
  const SupportCallLogDraft({
    required this.customerName,
    required this.customerPhone,
    required this.issue,
    this.address,
    this.latitude,
    this.longitude,
    this.createdBy,
    this.firstImageUrls = const [],
  });

  final String customerName;
  final String customerPhone;
  final String issue;
  final String? address;
  final double? latitude;
  final double? longitude;
  final String? createdBy;
  final List<String> firstImageUrls;
}

const _supportCallLogSelect =
    'id, customer_name, customer_phone, issue, address, created_by, created_at, call_date, first_image_urls, second_image_urls';

class SupportCallLogRepository {
  SupportCallLogRepository();

  Future<List<SupportCallLog>> list({
    int limit = 150,
    String? fromYmd,
    String? toYmdInclusive,
    bool pendingOnly = false,
    bool visitOnly = false,
  }) async {
    try {
      final fromIso = fromYmd == null ? null : '${fromYmd}T00:00:00+09:00';
      final toIso = toYmdInclusive == null
          ? null
          : '${addDaysToYmd(toYmdInclusive, 1)}T00:00:00+09:00';
      var query = supportSupabaseClient()
          .from('call_logs')
          .select(_supportCallLogSelect);
      if (visitOnly && fromYmd != null && toYmdInclusive != null) {
        query = query
            .gte('visit_date', fromYmd)
            .lte('visit_date', toYmdInclusive);
      } else if (fromIso != null && toIso != null) {
        query = query.gte('created_at', fromIso).lt('created_at', toIso);
      }
      if (pendingOnly) {
        query = query.or('service_status_id.is.null,service_status_id.eq.4');
      }
      final rows = await query
          .order('created_at', ascending: false)
          .limit(limit);
      return List<Map<String, dynamic>>.from(
        rows,
      ).map(SupportCallLog.fromJson).toList();
    } catch (e) {
      throw ApiException('A/S 접수 내역을 불러오지 못했습니다. $e');
    }
  }

  Future<SupportHomePeriodStats> periodStats({
    required String fromYmd,
    required String toYmdInclusive,
  }) async {
    try {
      final fromIso = '${fromYmd}T00:00:00+09:00';
      final toIso = '${addDaysToYmd(toYmdInclusive, 1)}T00:00:00+09:00';
      final client = supportSupabaseClient();
      // `updated_at` 컬럼이 없는 Support DB가 있어 기본 select에 넣지 않는다.
      final createdRows = await client
          .from('call_logs')
          .select('id, created_at, visit_date, service_status_id')
          .gte('created_at', fromIso)
          .lt('created_at', toIso);
      final created = List<Map<String, dynamic>>.from(createdRows);
      var pending = 0;
      for (final row in created) {
        final status = int.tryParse('${row['service_status_id'] ?? ''}');
        if (isSupportServiceStatusPending(status)) pending++;
      }
      var updated = created.length;
      try {
        final updatedRows = await client
            .from('call_logs')
            .select('id')
            .gte('updated_at', fromIso)
            .lt('updated_at', toIso);
        updated = List<dynamic>.from(updatedRows).length;
      } catch (_) {}

      var visits = 0;
      try {
        final visitRows = await client
            .from('call_logs')
            .select('id')
            .gte('visit_date', fromYmd)
            .lte('visit_date', toYmdInclusive);
        visits = List<dynamic>.from(visitRows).length;
      } catch (_) {
        visits = created.where((row) {
          final ymd = _rowYmd(row['visit_date']);
          return ymd != null &&
              ymd.compareTo(fromYmd) >= 0 &&
              ymd.compareTo(toYmdInclusive) <= 0;
        }).length;
      }

      return SupportHomePeriodStats(
        reception: created.length,
        pending: pending,
        visits: visits,
        updated: updated,
      );
    } catch (e) {
      throw ApiException('고객지원 통계를 불러오지 못했습니다. $e');
    }
  }

  String? _rowYmd(Object? raw) {
    if (raw == null) return null;
    final parsed = DateTime.tryParse(raw.toString());
    if (parsed != null) return ymdSeoulFromDateTime(parsed);
    final s = raw.toString();
    return s.length >= 10 ? s.substring(0, 10) : null;
  }

  Future<SupportCallLog> create(SupportCallLogDraft draft) async {
    final row = <String, dynamic>{
      'customer_name': draft.customerName,
      'customer_phone': draft.customerPhone,
      'issue': draft.issue,
      'address': draft.address,
      'call_status_id': 1,
      'service_status_id': 4,
      'is_blacklisted': false,
      if (draft.latitude != null) 'latitude': draft.latitude,
      if (draft.longitude != null) 'longitude': draft.longitude,
      if (draft.createdBy != null) 'created_by': draft.createdBy,
      if (draft.firstImageUrls.isNotEmpty)
        'first_image_urls': draft.firstImageUrls,
    };
    try {
      final created = await supportSupabaseClient()
          .from('call_logs')
          .insert(row)
          .select(_supportCallLogSelect)
          .single();
      return SupportCallLog.fromJson(Map<String, dynamic>.from(created));
    } catch (e) {
      throw ApiException('A/S 접수 저장에 실패했습니다. $e');
    }
  }

  Future<SupportCallLog> getById(String id) async {
    try {
      final row = await supportSupabaseClient()
          .from('call_logs')
          .select(_supportCallLogSelect)
          .eq('id', id)
          .single();
      return SupportCallLog.fromJson(Map<String, dynamic>.from(row));
    } catch (e) {
      throw ApiException('A/S 접수를 불러오지 못했습니다. $e');
    }
  }

  Future<SupportCallLog> update(String id, SupportCallLogDraft draft) async {
    final row = <String, dynamic>{
      'customer_name': draft.customerName,
      'customer_phone': draft.customerPhone,
      'issue': draft.issue,
      'address': draft.address,
      'first_image_urls': draft.firstImageUrls,
      if (draft.latitude != null) 'latitude': draft.latitude,
      if (draft.longitude != null) 'longitude': draft.longitude,
    };
    try {
      final updated = await supportSupabaseClient()
          .from('call_logs')
          .update(row)
          .eq('id', id)
          .select(_supportCallLogSelect)
          .single();
      return SupportCallLog.fromJson(Map<String, dynamic>.from(updated));
    } catch (e) {
      throw ApiException('A/S 접수 수정에 실패했습니다. $e');
    }
  }

  Future<void> delete(String id) async {
    try {
      await supportSupabaseClient().from('call_logs').delete().eq('id', id);
    } catch (e) {
      throw ApiException('A/S 접수 삭제에 실패했습니다. $e');
    }
  }
}

/// 웹과 동일: `service_status_id` 4 = 접수(미처리). 값 없음도 미처리로 본다.
bool isSupportServiceStatusPending(int? status) =>
    status == null || status == 4;

List<String> parseSupportUrlList(Object? raw) {
  if (raw == null) return const [];
  if (raw is String) {
    final s = raw.trim();
    if (s.isEmpty) return const [];
    if (s.startsWith('[')) {
      try {
        return parseSupportUrlList(jsonDecode(s));
      } catch (_) {
        return [s];
      }
    }
    return [s];
  }
  if (raw is Iterable) {
    return [
      for (final e in raw)
        if (e != null && e.toString().trim().isNotEmpty) e.toString().trim(),
    ];
  }
  return const [];
}
