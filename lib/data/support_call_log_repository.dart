import 'dart:convert';

import 'package:coad_customer_calls/core/network/api_exception.dart';
import 'package:coad_customer_calls/core/utils/date_seoul.dart';
import 'package:coad_customer_calls/core/utils/region_branch.dart';
import 'package:coad_customer_calls/core/utils/support_visit_capacity.dart';
import 'package:coad_customer_calls/data/support_supabase.dart';
import 'package:coad_customer_calls/data/support_visit_report.dart';
import 'package:coad_customer_calls/models/region.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
    this.serviceStatusId,
    this.visitDate,
    this.visitTeamId,
    this.visitTime,
    this.latitude,
    this.longitude,
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
  final int? serviceStatusId;
  final String? visitDate;
  final String? visitTeamId;
  final String? visitTime;
  final double? latitude;
  final double? longitude;

  bool get hasCoords =>
      latitude != null &&
      longitude != null &&
      latitude!.abs() <= 90 &&
      longitude!.abs() <= 180;

  List<String> get attachmentUrls => [...firstImageUrls, ...secondImageUrls];

  bool get isPending => isSupportServiceStatusPending(serviceStatusId);

  SupportCallLog copyWith({
    int? serviceStatusId,
    String? visitDate,
    String? visitTeamId,
    String? visitTime,
    bool clearVisitTeamId = false,
    bool clearVisitTime = false,
    double? latitude,
    double? longitude,
  }) {
    return SupportCallLog(
      id: id,
      customerName: customerName,
      customerPhone: customerPhone,
      issue: issue,
      address: address,
      createdBy: createdBy,
      createdAt: createdAt,
      callDate: callDate,
      firstImageUrls: firstImageUrls,
      secondImageUrls: secondImageUrls,
      serviceStatusId: serviceStatusId ?? this.serviceStatusId,
      visitDate: visitDate ?? this.visitDate,
      visitTeamId: clearVisitTeamId
          ? null
          : (visitTeamId ?? this.visitTeamId),
      visitTime: clearVisitTime ? null : (visitTime ?? this.visitTime),
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }

  factory SupportCallLog.fromJson(Map<String, dynamic> json) {
    return SupportCallLog(
      id: (json['id'] ?? '').toString(),
      customerName: (json['customer_name'] ?? '').toString(),
      customerPhone: (json['customer_phone'] ?? '').toString(),
      issue: (json['issue'] ?? '').toString(),
      address: json['address']?.toString(),
      createdBy: json['created_by']?.toString(),
      createdAt: parseSupabaseTimestampUtc(json['created_at']),
      callDate: parseSupabaseTimestampUtc(json['call_date']),
      firstImageUrls: parseSupportUrlList(json['first_image_urls']),
      secondImageUrls: parseSupportUrlList(json['second_image_urls']),
      serviceStatusId: int.tryParse('${json['service_status_id'] ?? ''}'),
      visitDate: () {
        final raw = json['visit_date']?.toString().trim() ?? '';
        if (raw.isEmpty) return null;
        return raw.length >= 10 ? raw.substring(0, 10) : raw;
      }(),
      visitTeamId: () {
        final raw = json['visit_team_id']?.toString().trim() ?? '';
        return raw.isEmpty ? null : raw;
      }(),
      visitTime: () {
        final raw = json['visit_time']?.toString().trim() ?? '';
        if (raw.isEmpty) return null;
        return raw.length >= 5 ? raw.substring(0, 5) : raw;
      }(),
      latitude: double.tryParse('${json['latitude'] ?? ''}'),
      longitude: double.tryParse('${json['longitude'] ?? ''}'),
    );
  }
}

class SupportFeedbackWaitItem {
  const SupportFeedbackWaitItem({
    required this.log,
    required this.lastConsultAt,
  });

  final SupportCallLog log;
  final DateTime lastConsultAt;
}

class SupportHomePeriodStats {
  const SupportHomePeriodStats({
    required this.reception,
    required this.pending,
    required this.visits,
    this.visitsCompleted = 0,
    required this.updated,
  });

  final int reception;
  final int pending;
  /// 기간 내 방문예정(미완료).
  final int visits;
  /// 기간 내 방문완료.
  final int visitsCompleted;
  final int updated;

  static const empty = SupportHomePeriodStats(
    reception: 0,
    pending: 0,
    visits: 0,
    visitsCompleted: 0,
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

const kSupportStatusCompleted = 1;
const kSupportStatusInProgress = 2;
const kSupportStatusReceived = 4;
const kSupportStatusVisitScheduled = 5;

const _supportCallLogSelect =
    'id, customer_name, customer_phone, issue, address, created_by, created_at, call_date, first_image_urls, second_image_urls, service_status_id, visit_date, visit_team_id, visit_time, latitude, longitude';

class SupportCallLogRepository {
  SupportCallLogRepository();

  Future<List<SupportCallLog>> list({
    int limit = 150,
    String? fromYmd,
    String? toYmdInclusive,
    bool pendingOnly = false,
    bool visitOnly = false,
    bool incompleteOnly = false,
    int? statusId,
  }) async {
    try {
      final fromIso = fromYmd == null ? null : seoulDayStartUtcIso(fromYmd);
      final toIso = toYmdInclusive == null
          ? null
          : seoulDayEndExclusiveUtcIso(toYmdInclusive);
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
      if (statusId != null) {
        query = query.eq('service_status_id', statusId);
      } else if (pendingOnly) {
        query = query.or('service_status_id.is.null,service_status_id.eq.4');
      } else if (incompleteOnly) {
        query = query.or(
          'service_status_id.is.null,service_status_id.neq.$kSupportStatusCompleted',
        );
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

  Future<int> countAll() async {
    try {
      return await supportSupabaseClient()
          .from('call_logs')
          .count(CountOption.exact);
    } catch (e) {
      throw ApiException('A/S 전체 건수를 불러오지 못했습니다. $e');
    }
  }

  Future<int> countPending() async {
    try {
      final res = await supportSupabaseClient()
          .from('call_logs')
          .select('id')
          .or(
            'service_status_id.is.null,service_status_id.eq.$kSupportStatusReceived',
          )
          .count(CountOption.exact);
      return res.count;
    } catch (e) {
      throw ApiException('A/S 미처리 건수를 불러오지 못했습니다. $e');
    }
  }

  Future<int> countIncomplete() async {
    try {
      final res = await supportSupabaseClient()
          .from('call_logs')
          .select('id')
          .or(
            'service_status_id.is.null,service_status_id.neq.$kSupportStatusCompleted',
          )
          .count(CountOption.exact);
      return res.count;
    } catch (e) {
      throw ApiException('A/S 미완료 건수를 불러오지 못했습니다. $e');
    }
  }

  /// 접수별 마지막 상담 결과. 방문 기록 줄은 뺀다.
  Future<Map<String, SupportConsultSnapshot>> lastConsultSnapshots(
    Iterable<String> callLogIds,
  ) async {
    final ids = callLogIds
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();
    if (ids.isEmpty) return const {};
    try {
      final rows = await supportSupabaseClient()
          .from('service_requests')
          .select('call_log_id, description, created_at')
          .inFilter('call_log_id', ids)
          .order('created_at');
      final byLog = <String, List<String>>{};
      for (final row in List<Map<String, dynamic>>.from(rows)) {
        final id = (row['call_log_id'] ?? '').toString();
        final desc = (row['description'] ?? '').toString();
        if (id.isEmpty || isSupportVisitReportText(desc)) continue;
        byLog.putIfAbsent(id, () => []).add(desc);
      }
      final out = <String, SupportConsultSnapshot>{};
      for (final e in byLog.entries) {
        String? ymd;
        String? sentYmd;
        for (final raw in e.value) {
          final parsed = parseSupportConsultation(raw);
          if (parsed.outcome == SupportConsultOutcome.quoteSend) {
            ymd = parsed.ymd;
            sentYmd = parsed.sentYmd;
          }
        }
        out[e.key] = SupportConsultSnapshot(
          outcome: lastSupportConsultOutcome(e.value),
          ymd: ymd,
          sentYmd: sentYmd,
          count: e.value.length,
        );
      }
      return out;
    } catch (e) {
      throw ApiException('상담 결과를 불러오지 못했습니다. $e');
    }
  }

  /// 답 대기(상태 2) 중 마지막 상담 결과가 [outcome]인 건.
  Future<List<SupportCallLog>> listByLastConsultOutcome(
    SupportConsultOutcome outcome, {
    int limit = 200,
  }) async {
    final logs = await list(statusId: kSupportStatusInProgress, limit: limit);
    return filterLogsByLastConsultOutcome(logs, outcome);
  }

  Future<List<SupportCallLog>> filterLogsByLastConsultOutcome(
    List<SupportCallLog> logs,
    SupportConsultOutcome outcome,
  ) async {
    if (logs.isEmpty) return const [];
    try {
      final rows = await supportSupabaseClient()
          .from('service_requests')
          .select('call_log_id, description, created_at')
          .inFilter('call_log_id', logs.map((e) => e.id).toList())
          .order('created_at');
      final byLog = <String, List<String>>{};
      for (final row in List<Map<String, dynamic>>.from(rows)) {
        final id = (row['call_log_id'] ?? '').toString();
        final desc = (row['description'] ?? '').toString();
        if (id.isEmpty || isSupportVisitReportText(desc)) continue;
        byLog.putIfAbsent(id, () => []).add(desc);
      }
      return logs
          .where(
            (log) =>
                lastSupportConsultOutcome(byLog[log.id] ?? const []) == outcome,
          )
          .toList();
    } catch (e) {
      throw ApiException('상담 결과 목록을 불러오지 못했습니다. $e');
    }
  }

  /// 마지막 상담이 피드백 대기인 접수 + 그 상담 시각(UTC).
  Future<List<SupportFeedbackWaitItem>> listFeedbackWaitItems({
    int limit = 200,
  }) async {
    final logs = await list(statusId: kSupportStatusInProgress, limit: limit);
    if (logs.isEmpty) return const [];
    try {
      final rows = await supportSupabaseClient()
          .from('service_requests')
          .select('call_log_id, description, created_at')
          .inFilter('call_log_id', logs.map((e) => e.id).toList())
          .order('created_at');
      final lastByLog =
          <String, ({SupportConsultOutcome? outcome, DateTime? at})>{};
      for (final row in List<Map<String, dynamic>>.from(rows)) {
        final id = (row['call_log_id'] ?? '').toString();
        final desc = (row['description'] ?? '').toString();
        if (id.isEmpty || isSupportVisitReportText(desc)) continue;
        final outcome = parseSupportConsultation(desc).outcome;
        if (outcome == null) continue;
        lastByLog[id] = (
          outcome: outcome,
          at: parseSupabaseTimestampUtc(row['created_at']),
        );
      }
      final items = <SupportFeedbackWaitItem>[];
      for (final log in logs) {
        final last = lastByLog[log.id];
        if (last == null ||
            last.outcome != SupportConsultOutcome.feedbackWait) {
          continue;
        }
        items.add(
          SupportFeedbackWaitItem(
            log: log,
            lastConsultAt: last.at ?? log.createdAt ?? DateTime.now().toUtc(),
          ),
        );
      }
      return items;
    } catch (e) {
      throw ApiException('피드백 대기 목록을 불러오지 못했습니다. $e');
    }
  }

  /// 지도용. 완료가 아닌 접수(주소 있는 것).
  Future<List<SupportCallLog>> listForMap({int limit = 400}) async {
    try {
      final rows = await supportSupabaseClient()
          .from('call_logs')
          .select(_supportCallLogSelect)
          .not('address', 'is', null)
          .or(
            'service_status_id.is.null,service_status_id.eq.$kSupportStatusReceived,service_status_id.eq.$kSupportStatusInProgress,service_status_id.eq.$kSupportStatusVisitScheduled',
          )
          .order('created_at', ascending: false)
          .limit(limit);
      return List<Map<String, dynamic>>.from(rows)
          .map(SupportCallLog.fromJson)
          .where((e) => (e.address ?? '').trim().isNotEmpty)
          .toList();
    } catch (e) {
      throw ApiException('지도 접수를 불러오지 못했습니다. $e');
    }
  }

  Future<void> saveCoords({
    required String id,
    required double latitude,
    required double longitude,
  }) async {
    try {
      await supportSupabaseClient()
          .from('call_logs')
          .update({'latitude': latitude, 'longitude': longitude})
          .eq('id', id);
    } catch (_) {}
  }

  Future<SupportHomePeriodStats> periodStats({
    required String fromYmd,
    required String toYmdInclusive,
  }) async {
    try {
      final fromIso = seoulDayStartUtcIso(fromYmd);
      final toIso = seoulDayEndExclusiveUtcIso(toYmdInclusive);
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
      var visitsCompleted = 0;
      try {
        final visitRows = await client
            .from('call_logs')
            .select('id, service_status_id')
            .gte('visit_date', fromYmd)
            .lte('visit_date', toYmdInclusive);
        for (final row in List<Map<String, dynamic>>.from(visitRows)) {
          final status = int.tryParse('${row['service_status_id'] ?? ''}');
          if (status == kSupportStatusCompleted) {
            visitsCompleted++;
          } else {
            visits++;
          }
        }
      } catch (_) {
        for (final row in created) {
          final ymd = _rowYmd(row['visit_date']);
          if (ymd == null ||
              ymd.compareTo(fromYmd) < 0 ||
              ymd.compareTo(toYmdInclusive) > 0) {
            continue;
          }
          final status = int.tryParse('${row['service_status_id'] ?? ''}');
          if (status == kSupportStatusCompleted) {
            visitsCompleted++;
          } else {
            visits++;
          }
        }
      }

      return SupportHomePeriodStats(
        reception: created.length,
        pending: pending,
        visits: visits,
        visitsCompleted: visitsCompleted,
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
    final when = seoulNowCallDateTimeParts();
    final row = <String, dynamic>{
      'customer_name': draft.customerName,
      'customer_phone': draft.customerPhone,
      'issue': draft.issue,
      'address': draft.address,
      // KST 벽시계 — UTC 자정으로 묶이면 새벽~오전 접수가 전일로 간다.
      'call_date': '${when.ymd}T${when.hms}+09:00',
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

  Future<List<SupportConsultation>> listConsultations(String callLogId) async {
    try {
      final rows = await supportSupabaseClient()
          .from('service_requests')
          .select('id, description, created_by, created_at')
          .eq('call_log_id', callLogId)
          .order('created_at', ascending: true);
      return List<Map<String, dynamic>>.from(rows)
          .map(SupportConsultation.fromJson)
          .where((c) => !isSupportVisitReportText(c.description))
          .toList();
    } catch (e) {
      throw ApiException('상담 내용을 불러오지 못했습니다. $e');
    }
  }

  Future<List<SupportVisitReport>> listVisitReports(String callLogId) async {
    try {
      final rows = await supportSupabaseClient()
          .from('service_requests')
          .select('id, description, created_by, created_at')
          .eq('call_log_id', callLogId)
          .order('created_at', ascending: true);
      final out = <SupportVisitReport>[];
      for (final row in List<Map<String, dynamic>>.from(rows)) {
        final parsed = parseSupportVisitReport(
          (row['description'] ?? '').toString(),
          id: (row['id'] ?? '').toString(),
          createdBy: row['created_by']?.toString(),
          createdAt: parseSupabaseTimestampUtc(row['created_at']),
        );
        if (parsed != null) out.add(parsed);
      }
      return out;
    } catch (e) {
      throw ApiException('방문 기록을 불러오지 못했습니다. $e');
    }
  }

  /// 현장 방문 기록. 완료면 접수를 완료로, 미완료면 다음 방문일로 일정을 옮긴다.
  Future<void> addVisitReport({
    required String callLogId,
    required SupportVisitReport report,
  }) async {
    final issue = supportVisitReportIssue(report);
    if (issue != null) throw ApiException(issue);
    final log = await getById(callLogId);
    final consults = await listConsultations(callLogId);
    if (!supportVisitRecordCanAdd(
      visitDate: log.visitDate,
      serviceStatusId: log.serviceStatusId,
      consultationDescriptions: consults.map((c) => c.description),
    )) {
      if (log.serviceStatusId == kSupportStatusCompleted) {
        throw ApiException('완료된 접수는 방문 기록을 추가할 수 없습니다.');
      }
      throw ApiException('방문 요청으로 일정이 잡힌 뒤에 방문 기록을 남길 수 있습니다.');
    }
    try {
      final client = supportSupabaseClient();
      final createdBy = (report.createdBy ?? '').trim();
      await client.from('service_requests').insert({
        'call_log_id': callLogId,
        'description': serializeSupportVisitReport(report),
        if (createdBy.isNotEmpty) 'created_by': createdBy,
      });
      final patch = <String, dynamic>{
        'service_status_id': report.completed
            ? kSupportStatusCompleted
            : kSupportStatusVisitScheduled,
        'visit_date': report.completed ? report.visitYmd : report.nextVisitYmd,
      };
      if (report.completed) {
        patch['visit_team_id'] = null;
        patch['visit_time'] = null;
      } else {
        final teamId = (report.nextVisitTeamId ?? '').trim();
        if (teamId.isEmpty) {
          throw ApiException('다음 방문 팀을 선택해 주세요.');
        }
        final time = (report.nextVisitTime ?? '').trim();
        if (time.isEmpty) {
          throw ApiException('다음 방문 시간을 선택해 주세요.');
        }
        patch['visit_team_id'] = teamId;
        patch['visit_time'] = time.length >= 5 ? time.substring(0, 5) : time;
      }
      await client.from('call_logs').update(patch).eq('id', callLogId);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('방문 기록 저장에 실패했습니다. $e');
    }
  }

  Future<void> updateVisitReport(SupportVisitReport report) async {
    final id = (report.id ?? '').trim();
    if (id.isEmpty) {
      throw ApiException('방문 기록 id가 없습니다.');
    }
    try {
      await supportSupabaseClient()
          .from('service_requests')
          .update({'description': serializeSupportVisitReport(report)})
          .eq('id', id);
    } catch (e) {
      throw ApiException('입금 상태를 저장하지 못했습니다. $e');
    }
  }

  /// 상담 저장. 결과에 따라 완료/진행중/방문예정으로 바꾸고 미처리에서 제외한다.
  Future<void> addConsultation({
    required String callLogId,
    required String description,
    String? createdBy,
    int? currentStatusId,
    SupportConsultOutcome? outcome,
    String? visitYmd,
    String? visitTeamId,
    String? visitTime,
    String? visitTeamLabel,
    String? sendYmd,
    int? amount,
  }) async {
    final text = description.trim();
    if (outcome == SupportConsultOutcome.visit &&
        (visitYmd == null || visitYmd.trim().isEmpty)) {
      throw ApiException('방문예정일을 선택해 주세요.');
    }
    if (outcome == SupportConsultOutcome.visit &&
        (visitTeamId == null || visitTeamId.trim().isEmpty)) {
      throw ApiException('방문 팀을 선택해 주세요.');
    }
    if (outcome == SupportConsultOutcome.visit &&
        (visitTime == null || visitTime.trim().isEmpty)) {
      throw ApiException('방문 시간을 선택해 주세요.');
    }
    if (outcome == SupportConsultOutcome.verbalQuote &&
        (amount == null || amount <= 0)) {
      throw ApiException('구두 견적 금액을 입력해 주세요.');
    }
    final body = text.isNotEmpty
        ? text
        : outcome == SupportConsultOutcome.visit
        ? supportVisitConsultBody(
            ymd: visitYmd!,
            time: visitTime!,
            teamLabel: visitTeamLabel,
          )
        : '';
    if (body.isEmpty) {
      throw ApiException('상담 내용을 입력해 주세요.');
    }
    try {
      final client = supportSupabaseClient();
      if (outcome == SupportConsultOutcome.visit) {
        await _ensureVisitSlotFree(
          visitYmd: visitYmd!,
          visitTeamId: visitTeamId!,
          visitTime: visitTime!,
          excludeLogId: callLogId,
        );
      }
      final bodyLines = [
        if (outcome != null)
          supportConsultOutcomeLine(
            outcome,
            ymd: outcome == SupportConsultOutcome.visit
                ? visitYmd
                : outcome == SupportConsultOutcome.quoteSend
                ? sendYmd
                : null,
            visitTime: outcome == SupportConsultOutcome.visit
                ? visitTime
                : null,
            amount:
                outcome == SupportConsultOutcome.verbalQuote ||
                    outcome == SupportConsultOutcome.quoteSend
                ? amount
                : null,
          ),
        body,
      ].join('\n');
      await client.from('service_requests').insert({
        'call_log_id': callLogId,
        'description': bodyLines,
        if (createdBy != null && createdBy.trim().isNotEmpty)
          'created_by': createdBy.trim(),
      });
      final patch = <String, dynamic>{};
      if (outcome != null) {
        patch['service_status_id'] = supportConsultOutcomeStatusId(outcome);
        if (outcome == SupportConsultOutcome.visit) {
          patch['visit_date'] = visitYmd;
          patch['visit_team_id'] = visitTeamId!.trim();
          final t = visitTime!.trim();
          patch['visit_time'] = t.length >= 5 ? t.substring(0, 5) : t;
        }
      } else if (isSupportServiceStatusPending(currentStatusId)) {
        patch['service_status_id'] = kSupportStatusInProgress;
      }
      if (patch.isNotEmpty) {
        await client.from('call_logs').update(patch).eq('id', callLogId);
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('상담 내용 저장에 실패했습니다. $e');
    }
  }

  /// 방문예정일·팀만 변경 (접수 상세·달력).
  Future<void> updateVisitSchedule({
    required String callLogId,
    required String visitYmd,
    required String visitTeamId,
    required String visitTime,
  }) async {
    final id = callLogId.trim();
    final ymd = visitYmd.trim();
    final teamId = visitTeamId.trim();
    final time = visitTime.trim();
    if (id.isEmpty) throw ApiException('접수 id가 없습니다.');
    if (ymd.isEmpty) throw ApiException('방문예정일을 선택해 주세요.');
    if (teamId.isEmpty) throw ApiException('방문 팀을 선택해 주세요.');
    if (time.isEmpty) throw ApiException('방문 시간을 선택해 주세요.');
    try {
      await _ensureVisitSlotFree(
        visitYmd: ymd,
        visitTeamId: teamId,
        visitTime: time,
        excludeLogId: id,
      );
      await supportSupabaseClient()
          .from('call_logs')
          .update({
            'visit_date': ymd,
            'visit_team_id': teamId,
            'visit_time': time.length >= 5 ? time.substring(0, 5) : time,
            'service_status_id': kSupportStatusVisitScheduled,
          })
          .eq('id', id);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('방문예정일을 저장하지 못했습니다. $e');
    }
  }

  Future<void> _ensureVisitSlotFree({
    required String visitYmd,
    required String visitTeamId,
    required String visitTime,
    String? excludeLogId,
  }) async {
    final slot = visitTime.length >= 5 ? visitTime.substring(0, 5) : visitTime;
    final rows = await supportSupabaseClient()
        .from('call_logs')
        .select('id')
        .eq('visit_date', visitYmd)
        .eq('visit_team_id', visitTeamId)
        .eq('visit_time', slot)
        .neq('service_status_id', kSupportStatusCompleted)
        .limit(4);
    final skip = (excludeLogId ?? '').trim();
    for (final row in List<Map<String, dynamic>>.from(rows)) {
      final id = (row['id'] ?? '').toString();
      if (skip.isNotEmpty && id == skip) continue;
      throw ApiException('그 팀·날짜·시간에 이미 방문이 있습니다.');
    }
  }

  Future<void> markQuoteSent({
    required String consultationId,
    required String description,
    String? sentYmd,
  }) async {
    final id = consultationId.trim();
    if (id.isEmpty) {
      throw ApiException('상담 id가 없습니다.');
    }
    try {
      await supportSupabaseClient()
          .from('service_requests')
          .update({
            'description': rewriteSupportQuoteSentLine(
              description,
              sentYmd: sentYmd,
            ),
          })
          .eq('id', id);
    } catch (e) {
      throw ApiException('견적서 발송 여부를 저장하지 못했습니다. $e');
    }
  }

  Future<List<SupportScheduleEvent>> listScheduleEvents({
    required String fromYmd,
    required String toYmdInclusive,
  }) async {
    try {
      final client = supportSupabaseClient();
      final events = <SupportScheduleEvent>[];
      final seen = <String>{};
      void addEvent(SupportScheduleEvent event) {
        final key = '${event.kind.name}|${event.log.id}|${event.ymd}';
        if (!seen.add(key)) return;
        events.add(event);
      }

      final byLog = <String, List<SupportVisitReport>>{};
      try {
        final reports = await client
            .from('service_requests')
            .select('id, description, call_log_id, created_by, created_at')
            .ilike('description', '$kSupportVisitReportMarker%')
            .limit(800);
        for (final row in List<Map<String, dynamic>>.from(reports)) {
          final parsed = parseSupportVisitReport(
            (row['description'] ?? '').toString(),
            id: (row['id'] ?? '').toString(),
            createdBy: row['created_by']?.toString(),
            createdAt: parseSupabaseTimestampUtc(row['created_at']),
          );
          final id = (row['call_log_id'] ?? '').toString();
          if (parsed == null || id.isEmpty) continue;
          byLog.putIfAbsent(id, () => []).add(parsed);
        }
      } catch (_) {}

      SupportVisitReport? reportOnDay(String logId, String ymd) {
        for (final r in byLog[logId] ?? const <SupportVisitReport>[]) {
          if (r.visitYmd.trim() == ymd) return r;
        }
        return null;
      }

      String? normalizeTime(String? raw) {
        final t = (raw ?? '').trim();
        if (t.isEmpty) return null;
        return t.length >= 5 ? t.substring(0, 5) : t;
      }

      final visitRows = await client
          .from('call_logs')
          .select(_supportCallLogSelect)
          .gte('visit_date', fromYmd)
          .lte('visit_date', toYmdInclusive)
          .limit(400);
      for (final row in List<Map<String, dynamic>>.from(visitRows)) {
        final log = SupportCallLog.fromJson(row);
        final ymd = log.visitDate;
        if (ymd == null || ymd.isEmpty) continue;
        final report = reportOnDay(log.id, ymd);
        addEvent(
          SupportScheduleEvent(
            kind: SupportScheduleKind.visit,
            ymd: ymd,
            log: log,
            caption: log.serviceStatusId == kSupportStatusCompleted
                ? '방문완료'
                : '방문예정',
            visitReport: report,
            scheduledYmd: ymd,
            scheduledTime: normalizeTime(log.visitTime),
            actualYmd: report?.visitYmd,
            actualTime: normalizeTime(report?.visitTime),
          ),
        );
      }

      if (byLog.isNotEmpty) {
        try {
          final logs = await client
              .from('call_logs')
              .select(_supportCallLogSelect)
              .inFilter('id', byLog.keys.toList())
              .limit(400);
          for (final row in List<Map<String, dynamic>>.from(logs)) {
            final log = SupportCallLog.fromJson(row);
            for (final report
                in byLog[log.id] ?? const <SupportVisitReport>[]) {
                final visitYmd = report.visitYmd;
              if (visitYmd.compareTo(fromYmd) >= 0 &&
                  visitYmd.compareTo(toYmdInclusive) <= 0) {
                final scheduledYmd =
                    (report.scheduledYmd ?? '').trim().isNotEmpty
                    ? report.scheduledYmd!.trim()
                    : visitYmd;
                final scheduledTime =
                    normalizeTime(report.scheduledTime) ??
                    ((log.visitDate ?? '') == scheduledYmd
                        ? normalizeTime(log.visitTime)
                        : null) ??
                    normalizeTime(report.visitTime);
                addEvent(
                  SupportScheduleEvent(
                    kind: SupportScheduleKind.visit,
                    ymd: visitYmd,
                    log: log,
                    caption: report.completed ? '방문완료' : '방문',
                    visitReport: report,
                    scheduledYmd: scheduledYmd,
                    scheduledTime: scheduledTime,
                    actualYmd: visitYmd,
                    actualTime: normalizeTime(report.visitTime),
                  ),
                );
              }
              final next = report.nextVisitYmd ?? '';
              if (!report.completed &&
                  next.isNotEmpty &&
                  next.compareTo(fromYmd) >= 0 &&
                  next.compareTo(toYmdInclusive) <= 0) {
                addEvent(
                  SupportScheduleEvent(
                    kind: SupportScheduleKind.visit,
                    ymd: next,
                    log: log,
                    caption: '재방문예정',
                    visitReport: report,
                    scheduledYmd: next,
                    scheduledTime: normalizeTime(report.nextVisitTime) ??
                        normalizeTime(log.visitTime),
                    actualYmd: null,
                    actualTime: null,
                  ),
                );
              }
              final calendarYmd = report.depositCalendarYmd ?? '';
              if (report.isPaid &&
                  calendarYmd.isNotEmpty &&
                  calendarYmd.compareTo(fromYmd) >= 0 &&
                  calendarYmd.compareTo(toYmdInclusive) <= 0) {
                final due = (report.depositYmd ?? '').trim();
                final paidDay = report.effectiveDepositPaidYmd ?? '';
                final caption = report.depositPaid
                    ? (due.isNotEmpty && due != paidDay
                          ? '입금완료 $paidDay · 예정 $due'
                          : '입금완료 $paidDay')
                    : '입금예정';
                addEvent(
                  SupportScheduleEvent(
                    kind: SupportScheduleKind.deposit,
                    ymd: calendarYmd,
                    log: log,
                    caption: caption,
                    amount: report.amount,
                    depositPaid: report.depositPaid,
                    visitReport: report,
                    scheduledYmd: due.isEmpty ? null : due,
                    actualYmd: report.depositPaid ? paidDay : null,
                  ),
                );
              }
            }
          }
        } catch (_) {}
      }

      try {
        final reqs = await client
            .from('service_requests')
            .select('id, description, call_log_id')
            .ilike('description', '%발송예정%')
            .limit(500);
        final rowsByLog = <String, List<Map<String, dynamic>>>{};
        for (final row in List<Map<String, dynamic>>.from(reqs)) {
          final parsed = parseSupportConsultation(
            (row['description'] ?? '').toString(),
          );
          final ymd = parsed.ymd;
          if (parsed.outcome != SupportConsultOutcome.quoteSend ||
              ymd == null ||
              ymd.compareTo(fromYmd) < 0 ||
              ymd.compareTo(toYmdInclusive) > 0) {
            continue;
          }
          final logId = (row['call_log_id'] ?? '').toString();
          if (logId.isEmpty) continue;
          rowsByLog.putIfAbsent(logId, () => []).add(row);
        }
        if (rowsByLog.isNotEmpty) {
          final logs = await client
              .from('call_logs')
              .select(_supportCallLogSelect)
              .inFilter('id', rowsByLog.keys.toList())
              .limit(400);
          for (final row in List<Map<String, dynamic>>.from(logs)) {
            final log = SupportCallLog.fromJson(row);
            for (final req in rowsByLog[log.id] ?? const []) {
              final parsed = parseSupportConsultation(
                (req['description'] ?? '').toString(),
              );
              final ymd = parsed.ymd;
              if (ymd == null) continue;
              addEvent(
                SupportScheduleEvent(
                  kind: SupportScheduleKind.quoteSend,
                  ymd: ymd,
                  log: log,
                  consultationId: (req['id'] ?? '').toString(),
                  consultationDescription: (req['description'] ?? '')
                      .toString(),
                  quoteSentYmd: parsed.sentYmd,
                  caption: (parsed.sentYmd ?? '').isEmpty
                      ? '견적서 발송예정'
                      : '발송완료 ${parsed.sentYmd}',
                ),
              );
            }
          }
        }
      } catch (_) {}
      return events;
    } catch (e) {
      throw ApiException('일정을 불러오지 못했습니다. $e');
    }
  }

  /// 오늘·지난 방문/발송 예정 (완료 제외는 호출 측에서).
  Future<List<SupportScheduleEvent>> listDueScheduleEvents({
    required String todayYmd,
  }) {
    return listScheduleEvents(fromYmd: '2020-01-01', toYmdInclusive: todayYmd);
  }

  /// 완료되지 않은 방문예정만 날짜별 건수. 같은 지점만.
  Future<Map<String, int>> countScheduledVisitsByYmd({
    required String fromYmd,
    required String toYmdInclusive,
    required String branch,
    required List<Region> regions,
    String? excludeLogId,
  }) async {
    final byDay = await listScheduledVisitsByYmd(
      fromYmd: fromYmd,
      toYmdInclusive: toYmdInclusive,
      branch: branch,
      regions: regions,
      excludeLogId: excludeLogId,
    );
    return {
      for (final e in byDay.entries) e.key: e.value.totalCount,
    };
  }

  /// 완료되지 않은 방문예정 — 날짜별 팀 배정·총 건수. 같은 지점만.
  Future<Map<String, SupportVisitDayBookings>> listScheduledVisitsByYmd({
    required String fromYmd,
    required String toYmdInclusive,
    required String branch,
    required List<Region> regions,
    String? excludeLogId,
  }) async {
    try {
      final rows = await supportSupabaseClient()
          .from('call_logs')
          .select(
            'id, address, visit_date, visit_team_id, visit_time, service_status_id',
          )
          .gte('visit_date', fromYmd)
          .lte('visit_date', toYmdInclusive)
          .limit(800);
      final counts = <String, SupportVisitDayBookings>{};
      final skip = (excludeLogId ?? '').trim();
      for (final row in List<Map<String, dynamic>>.from(rows)) {
        final id = (row['id'] ?? '').toString();
        if (skip.isNotEmpty && id == skip) continue;
        final status = int.tryParse('${row['service_status_id'] ?? ''}');
        if (status == kSupportStatusCompleted) continue;
        final ymd = _rowYmd(row['visit_date']);
        if (ymd == null || ymd.isEmpty) continue;
        final matched = matchSupportBranchType(
          (row['address'] ?? '').toString(),
          regions,
        );
        if (matched != branch) continue;
        final prev = counts[ymd] ?? const SupportVisitDayBookings();
        final teamId = (row['visit_team_id'] ?? '').toString().trim();
        final timeRaw = (row['visit_time'] ?? '').toString().trim();
        final time = timeRaw.length >= 5 ? timeRaw.substring(0, 5) : timeRaw;
        final timesByTeam = <String, Set<String>>{
          for (final e in prev.timesByTeamId.entries) e.key: {...e.value},
        };
        if (teamId.isNotEmpty) {
          final set = {...(timesByTeam[teamId] ?? <String>{})};
          if (time.isNotEmpty) set.add(time);
          timesByTeam[teamId] = set;
        }
        counts[ymd] = SupportVisitDayBookings(
          timesByTeamId: timesByTeam,
          totalCount: prev.totalCount + 1,
        );
      }
      return counts;
    } catch (e) {
      throw ApiException('방문 가능일을 확인하지 못했습니다. $e');
    }
  }
}

class SupportConsultation {
  const SupportConsultation({
    required this.id,
    required this.description,
    this.createdBy,
    this.createdAt,
  });

  final String id;
  final String description;
  final String? createdBy;
  final DateTime? createdAt;

  factory SupportConsultation.fromJson(Map<String, dynamic> json) {
    return SupportConsultation(
      id: (json['id'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      createdBy: json['created_by']?.toString(),
      createdAt: parseSupabaseTimestampUtc(json['created_at']),
    );
  }
}

/// 웹과 동일: `service_status_id` 4 = 접수(미처리). 값 없음도 미처리로 본다.
bool isSupportServiceStatusPending(int? status) =>
    status == null || status == 4;

/// 마무리·방문 완료가 아니면 미완료.
bool isSupportServiceStatusIncomplete(int? status) =>
    status != kSupportStatusCompleted;

enum SupportScheduleKind { visit, quoteSend, deposit }

class SupportScheduleEvent {
  const SupportScheduleEvent({
    required this.kind,
    required this.ymd,
    required this.log,
    this.caption,
    this.amount,
    this.depositPaid,
    this.visitReport,
    this.consultationId,
    this.consultationDescription,
    this.quoteSentYmd,
    this.scheduledYmd,
    this.scheduledTime,
    this.actualYmd,
    this.actualTime,
  });

  final SupportScheduleKind kind;
  final String ymd;
  final SupportCallLog log;
  final String? caption;
  final int? amount;
  final bool? depositPaid;
  final SupportVisitReport? visitReport;
  final String? consultationId;
  final String? consultationDescription;
  final String? quoteSentYmd;
  /// 방문 예정일 (접수에 잡힌 일정).
  final String? scheduledYmd;
  final String? scheduledTime;
  /// 실제 방문일 (방문 기록).
  final String? actualYmd;
  final String? actualTime;

  bool get quoteSent => (quoteSentYmd ?? '').trim().isNotEmpty;

  String get label {
    if (caption != null) return caption!;
    return switch (kind) {
      SupportScheduleKind.visit => '방문예정',
      SupportScheduleKind.quoteSend =>
        quoteSent ? '발송완료 $quoteSentYmd' : '견적서 발송예정',
      SupportScheduleKind.deposit => (depositPaid ?? false)
          ? ((actualYmd ?? '').trim().isEmpty
                ? '입금완료'
                : '입금완료 $actualYmd')
          : '입금예정',
    };
  }
}

enum SupportConsultOutcome {
  closed,
  feedbackWait,
  verbalQuote,
  quoteSend,
  visit,
}

String supportConsultOutcomeLabel(SupportConsultOutcome outcome) =>
    switch (outcome) {
      SupportConsultOutcome.closed => '마무리',
      SupportConsultOutcome.feedbackWait => '피드백 대기',
      SupportConsultOutcome.verbalQuote => '구두 견적',
      SupportConsultOutcome.quoteSend => '정식 견적서',
      SupportConsultOutcome.visit => '방문 요청',
    };

String supportConsultOutcomeHint(SupportConsultOutcome outcome) =>
    switch (outcome) {
      SupportConsultOutcome.closed => '이 전화로 접수를 끝냅니다.',
      SupportConsultOutcome.feedbackWait =>
        '전화로 이것저것 안내하고 일단 해보게 합니다. 고객이 다시 연락 오면 다음 상담에서 마무리하거나 방문·견적을 잡습니다.',
      SupportConsultOutcome.verbalQuote =>
        '지금은 말로 금액만 남깁니다. 나중에 정식 견적서를 작성해 보낼 수도 있고, 다시 전화 오면 방문일을 잡습니다.',
      SupportConsultOutcome.quoteSend =>
        '정식 견적서를 작성하고, 보낼 날을 정한 뒤 보냅니다. 받은 다음 방문 요청이면 방문일을 잡습니다.',
      SupportConsultOutcome.visit => '방문일을 잡고 현장에 갑니다. 다녀온 뒤에 방문 기록을 남깁니다.',
    };

String supportCallLogProgressLabel(int? status) {
  if (isSupportServiceStatusPending(status)) return '미처리';
  if (status == kSupportStatusVisitScheduled) return '방문예정';
  if (status == kSupportStatusCompleted) return '완료';
  if (status == kSupportStatusInProgress) return '대기';
  return '진행중';
}

SupportConsultOutcome? lastSupportConsultOutcome(
  Iterable<String> consultationDescriptions,
) {
  SupportConsultOutcome? last;
  for (final raw in consultationDescriptions) {
    final parsed = parseSupportConsultation(raw);
    if (parsed.outcome != null) last = parsed.outcome;
  }
  return last;
}

int supportConsultOutcomeStatusId(SupportConsultOutcome outcome) =>
    switch (outcome) {
      SupportConsultOutcome.closed => kSupportStatusCompleted,
      SupportConsultOutcome.feedbackWait => kSupportStatusInProgress,
      SupportConsultOutcome.verbalQuote => kSupportStatusInProgress,
      SupportConsultOutcome.quoteSend => kSupportStatusInProgress,
      SupportConsultOutcome.visit => kSupportStatusVisitScheduled,
    };

String supportConsultOutcomeLine(
  SupportConsultOutcome outcome, {
  String? ymd,
  String? visitTime,
  String? sentYmd,
  int? amount,
}) {
  final stored = switch (outcome) {
    SupportConsultOutcome.closed => '마무리',
    SupportConsultOutcome.feedbackWait => '피드백 대기',
    SupportConsultOutcome.verbalQuote => '구두 견적',
    SupportConsultOutcome.quoteSend => '견적서 발송',
    SupportConsultOutcome.visit => '방문 요청',
  };
  final day = (ymd ?? '').trim();
  final time = (visitTime ?? '').trim();
  final sent = (sentYmd ?? '').trim();
  if (outcome == SupportConsultOutcome.quoteSend && day.isNotEmpty) {
    final extra = amount != null ? ' · 금액 $amount' : '';
    if (sent.isNotEmpty) {
      return '[결과: $stored · 발송예정 $day · 발송완료 $sent$extra]';
    }
    return '[결과: $stored · 발송예정 $day$extra]';
  }
  if (outcome == SupportConsultOutcome.visit && day.isNotEmpty) {
    final t = time.isEmpty
        ? ''
        : ' · 시간 ${time.length >= 5 ? time.substring(0, 5) : time}';
    return '[결과: $stored · 방문예정 $day$t]';
  }
  if (outcome == SupportConsultOutcome.verbalQuote && amount != null) {
    return '[결과: $stored · 금액 $amount]';
  }
  return '[결과: $stored]';
}

/// 방문 상담 본문(내용 비어 있을 때).
String supportVisitConsultBody({
  required String ymd,
  required String time,
  String? teamLabel,
}) {
  final day = ymd.trim();
  final t = time.trim();
  final slot = t.length >= 5 ? t.substring(0, 5) : t;
  final team = (teamLabel ?? '').trim();
  final parts = <String>[
    if (day.isNotEmpty && slot.isNotEmpty) '방문일정 $day $slot',
    if (day.isNotEmpty && slot.isEmpty) '방문일정 $day',
    if (team.isNotEmpty) team,
  ];
  return parts.join(' · ');
}

int? parseSupportConsultAmountDigits(String raw) {
  final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.isEmpty) return null;
  return int.tryParse(digits);
}

String formatSupportConsultAmountGrouped(String raw) {
  final amount = parseSupportConsultAmountDigits(raw);
  if (amount == null) return '';
  final digits = amount.toString();
  final buf = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buf.write(',');
    buf.write(digits[i]);
  }
  return buf.toString();
}

String rewriteSupportQuoteSentLine(String description, {String? sentYmd}) {
  final parsed = parseSupportConsultation(description);
  final planned = (parsed.ymd ?? '').trim();
  final head = supportConsultOutcomeLine(
    SupportConsultOutcome.quoteSend,
    ymd: planned.isEmpty ? sentYmd : planned,
    sentYmd: sentYmd,
  );
  if (parsed.body.isEmpty) return head;
  return '$head\n${parsed.body}';
}

({
  SupportConsultOutcome? outcome,
  String? ymd,
  String? visitTime,
  String? sentYmd,
  int? amount,
  String body,
})
parseSupportConsultation(String raw) {
  SupportConsultOutcome? outcome;
  String? ymd;
  String? visitTime;
  String? sentYmd;
  int? amount;
  final rest = <String>[];
  for (final line in raw.split('\n')) {
    final m = RegExp(
      r'^\[결과:\s*(마무리|피드백 대기|구두 견적|견적서 발송|방문 요청)'
      r'(?:\s*·\s*(?:발송예정|방문예정)\s*(\d{4}-\d{2}-\d{2}))?'
      r'(?:\s*·\s*시간\s*(\d{1,2}:\d{2}))?'
      r'(?:\s*·\s*발송완료\s*(\d{4}-\d{2}-\d{2}))?'
      r'(?:\s*·\s*금액\s*([\d,]+))?\]$',
    ).firstMatch(line.trim());
    if (m != null && outcome == null) {
      outcome = switch (m.group(1)) {
        '마무리' => SupportConsultOutcome.closed,
        '피드백 대기' => SupportConsultOutcome.feedbackWait,
        '구두 견적' => SupportConsultOutcome.verbalQuote,
        '견적서 발송' => SupportConsultOutcome.quoteSend,
        '방문 요청' => SupportConsultOutcome.visit,
        _ => null,
      };
      ymd = m.group(2);
      visitTime = m.group(3);
      sentYmd = m.group(4);
      amount = parseSupportConsultAmountDigits(m.group(5) ?? '');
      continue;
    }
    rest.add(line);
  }
  return (
    outcome: outcome,
    ymd: ymd,
    visitTime: visitTime,
    sentYmd: sentYmd,
    amount: amount,
    body: rest.join('\n').trim(),
  );
}

/// 방문 요청으로 방문 일정이 잡힌 뒤에만 방문 기록이 필요하다.
bool supportVisitRecordAllowed({
  String? visitDate,
  int? serviceStatusId,
  Iterable<String> consultationDescriptions = const [],
  int existingVisitReportCount = 0,
}) {
  if (existingVisitReportCount > 0) return true;
  if ((visitDate ?? '').trim().isNotEmpty) return true;
  if (serviceStatusId == kSupportStatusVisitScheduled) return true;
  for (final raw in consultationDescriptions) {
    final parsed = parseSupportConsultation(raw);
    if (parsed.outcome == SupportConsultOutcome.visit &&
        (parsed.ymd ?? '').trim().isNotEmpty) {
      return true;
    }
  }
  return false;
}

/// 완료된 접수는 방문 기록을 더 남기지 않는다. 미완료·재방문만 추가한다.
bool supportVisitRecordCanAdd({
  String? visitDate,
  int? serviceStatusId,
  Iterable<String> consultationDescriptions = const [],
  int existingVisitReportCount = 0,
}) {
  if (serviceStatusId == kSupportStatusCompleted) return false;
  return supportVisitRecordAllowed(
    visitDate: visitDate,
    serviceStatusId: serviceStatusId,
    consultationDescriptions: consultationDescriptions,
    existingVisitReportCount: existingVisitReportCount,
  );
}

enum SupportNextAction { consult, quote, visit, deposit, done }

class SupportConsultSnapshot {
  const SupportConsultSnapshot({
    this.outcome,
    this.ymd,
    this.sentYmd,
    this.count = 0,
  });

  final SupportConsultOutcome? outcome;
  final String? ymd;
  final String? sentYmd;
  final int count;
}

class SupportFlowCue {
  const SupportFlowCue({
    required this.action,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.progressLabel,
  });

  final SupportNextAction action;
  final String title;
  final String subtitle;
  final String actionLabel;
  final String progressLabel;
}

/// 목록·상세에서 지금 할 일.
/// 접수 → 1차 상담(마무리 / 피드백 대기 / 구두 견적 / 정식 견적서 / 방문) → 방문일 → 방문 기록.
SupportFlowCue supportFlowCue({
  required int? serviceStatusId,
  int consultationCount = 0,
  bool canAddVisit = false,
  String? visitDate,
  String? depositYmd,
  bool depositPaid = true,
  SupportConsultOutcome? lastOutcome,
  String? quoteSendYmd,
  String? quoteSentYmd,
}) {
  if (serviceStatusId == kSupportStatusCompleted) {
    final due = (depositYmd ?? '').trim();
    if (due.isNotEmpty && !depositPaid) {
      return SupportFlowCue(
        action: SupportNextAction.deposit,
        title: '입금 대기',
        subtitle: '입금예정일 $due · 달력에서 입금을 확인합니다',
        actionLabel: '달력',
        progressLabel: '입금대기 $due',
      );
    }
    return const SupportFlowCue(
      action: SupportNextAction.done,
      title: '완료',
      subtitle: '이 접수는 끝났습니다',
      actionLabel: '',
      progressLabel: '완료',
    );
  }
  if (canAddVisit) {
    final day = (visitDate ?? '').trim();
    return SupportFlowCue(
      action: SupportNextAction.visit,
      title: '다음: 방문 기록',
      subtitle: day.isEmpty
          ? '방문한 뒤에 완료·유무상을 남깁니다. 미완료면 다음 방문일을 잡습니다'
          : '방문일 $day · 다녀온 뒤 방문 기록을 남깁니다',
      actionLabel: '방문 기록',
      progressLabel: day.isEmpty ? '다음: 방문 기록' : '다음: 방문 $day',
    );
  }
  if (consultationCount == 0 ||
      isSupportServiceStatusPending(serviceStatusId)) {
    return const SupportFlowCue(
      action: SupportNextAction.consult,
      title: '다음: 1차 상담',
      subtitle: '전화 내용을 남기고 마무리, 피드백 대기, 구두 견적, 정식 견적서, 방문 중 하나를 고릅니다',
      actionLabel: '1차 상담',
      progressLabel: '다음: 1차 상담',
    );
  }
  final stage = consultationCount + 1;
  if (lastOutcome == SupportConsultOutcome.feedbackWait) {
    return SupportFlowCue(
      action: SupportNextAction.consult,
      title: '피드백 대기',
      subtitle: '전화로 안내했습니다. 다시 연락 오면 $stage차 상담에서 마무리하거나 방문·견적을 잡습니다',
      actionLabel: '$stage차 상담',
      progressLabel: '피드백 대기',
    );
  }
  if (lastOutcome == SupportConsultOutcome.verbalQuote) {
    return SupportFlowCue(
      action: SupportNextAction.consult,
      title: '구두 견적 대기',
      subtitle:
          '말로 금액을 전했습니다. 정식 견적서를 보내거나, 다시 오면 방문일을 잡거나 $stage차 상담을 남깁니다',
      actionLabel: '$stage차 상담',
      progressLabel: '구두 견적 대기',
    );
  }
  if (lastOutcome == SupportConsultOutcome.quoteSend) {
    final sent = (quoteSentYmd ?? '').trim();
    if (sent.isNotEmpty) {
      return SupportFlowCue(
        action: SupportNextAction.consult,
        title: '견적서 발송 완료',
        subtitle: '발송완료 $sent. 고객이 다시 오면 방문일을 잡거나 마무리합니다',
        actionLabel: '$stage차 상담',
        progressLabel: '발송완료 $sent',
      );
    }
    final day = (quoteSendYmd ?? '').trim();
    return SupportFlowCue(
      action: SupportNextAction.quote,
      title: day.isEmpty ? '정식 견적서 작성' : '견적서 발송예정 $day',
      subtitle: '견적서를 작성해 보낼 날 발송했다고 체크합니다. 오늘이나 다른 날도 됩니다',
      actionLabel: '견적서',
      progressLabel: day.isEmpty ? '정식 견적서' : '발송예정 $day',
    );
  }
  return SupportFlowCue(
    action: SupportNextAction.consult,
    title: '다음: $stage차 상담',
    subtitle: '답이 왔으면 마무리하거나, 정식 견적서·방문 요청을 고릅니다',
    actionLabel: '$stage차 상담',
    progressLabel: '대기',
  );
}

SupportFlowCue supportFlowCueFromLog(
  SupportCallLog log, {
  SupportConsultSnapshot? last,
}) {
  return supportFlowCue(
    serviceStatusId: log.serviceStatusId,
    consultationCount:
        last?.count ??
        (isSupportServiceStatusPending(log.serviceStatusId) ? 0 : 1),
    canAddVisit: supportVisitRecordCanAdd(
      visitDate: log.visitDate,
      serviceStatusId: log.serviceStatusId,
    ),
    visitDate: log.visitDate,
    lastOutcome: last?.outcome,
    quoteSendYmd: last?.ymd,
    quoteSentYmd: last?.sentYmd,
  );
}

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
