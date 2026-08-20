import 'dart:convert';

import 'package:coad_customer_calls/core/network/api_exception.dart';
import 'package:coad_customer_calls/core/utils/date_seoul.dart';
import 'package:coad_customer_calls/data/support_supabase.dart';
import 'package:coad_customer_calls/data/support_visit_report.dart';

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

  List<String> get attachmentUrls => [...firstImageUrls, ...secondImageUrls];

  bool get isPending => isSupportServiceStatusPending(serviceStatusId);

  SupportCallLog copyWith({int? serviceStatusId, String? visitDate}) {
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

const kSupportStatusCompleted = 1;
const kSupportStatusInProgress = 2;
const kSupportStatusReceived = 4;
const kSupportStatusVisitScheduled = 5;

const _supportCallLogSelect =
    'id, customer_name, customer_phone, issue, address, created_by, created_at, call_date, first_image_urls, second_image_urls, service_status_id, visit_date';

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
    if (report.visitYmd.trim().isEmpty) {
      throw ApiException('방문일을 선택해 주세요.');
    }
    if (report.notes.trim().isEmpty) {
      throw ApiException('방문 내용을 입력해 주세요.');
    }
    if (report.isPaid && (report.amount ?? 0) <= 0) {
      throw ApiException('유상이면 금액을 입력해 주세요.');
    }
    if (!report.completed && (report.nextVisitYmd ?? '').trim().isEmpty) {
      throw ApiException('미완료이면 다음 방문일을 선택해 주세요.');
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
      await client.from('call_logs').update(patch).eq('id', callLogId);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('방문 기록 저장에 실패했습니다. $e');
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
    String? sendYmd,
  }) async {
    final text = description.trim();
    if (text.isEmpty) {
      throw ApiException('상담 내용을 입력해 주세요.');
    }
    if (outcome == SupportConsultOutcome.visit &&
        (visitYmd == null || visitYmd.trim().isEmpty)) {
      throw ApiException('방문예정일을 선택해 주세요.');
    }
    try {
      final client = supportSupabaseClient();
      final body = [
        if (outcome != null)
          supportConsultOutcomeLine(
            outcome,
            ymd: outcome == SupportConsultOutcome.visit
                ? visitYmd
                : outcome == SupportConsultOutcome.quoteSend
                ? sendYmd
                : null,
          ),
        text,
      ].join('\n');
      await client.from('service_requests').insert({
        'call_log_id': callLogId,
        'description': body,
        if (createdBy != null && createdBy.trim().isNotEmpty)
          'created_by': createdBy.trim(),
      });
      final patch = <String, dynamic>{};
      if (outcome != null) {
        patch['service_status_id'] = supportConsultOutcomeStatusId(outcome);
        if (outcome == SupportConsultOutcome.visit) {
          patch['visit_date'] = visitYmd;
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
        addEvent(
          SupportScheduleEvent(
            kind: SupportScheduleKind.visit,
            ymd: ymd,
            log: log,
            caption: log.serviceStatusId == kSupportStatusCompleted
                ? '방문완료'
                : '방문예정',
          ),
        );
      }

      try {
        final reports = await client
            .from('service_requests')
            .select('description, call_log_id')
            .ilike('description', '$kSupportVisitReportMarker%')
            .limit(800);
        final byLog = <String, List<SupportVisitReport>>{};
        for (final row in List<Map<String, dynamic>>.from(reports)) {
          final parsed = parseSupportVisitReport(
            (row['description'] ?? '').toString(),
          );
          final id = (row['call_log_id'] ?? '').toString();
          if (parsed == null || id.isEmpty) continue;
          byLog.putIfAbsent(id, () => []).add(parsed);
        }
        if (byLog.isNotEmpty) {
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
                addEvent(
                  SupportScheduleEvent(
                    kind: SupportScheduleKind.visit,
                    ymd: visitYmd,
                    log: log,
                    caption: report.completed ? '방문완료' : '방문',
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
                  ),
                );
              }
            }
          }
        }
      } catch (_) {}

      try {
        final reqs = await client
            .from('service_requests')
            .select('description, call_log_id')
            .ilike('description', '%발송예정%')
            .limit(500);
        final ymdByLogId = <String, String>{};
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
          final id = (row['call_log_id'] ?? '').toString();
          if (id.isEmpty) continue;
          ymdByLogId[id] = ymd;
        }
        if (ymdByLogId.isNotEmpty) {
          final logs = await client
              .from('call_logs')
              .select(_supportCallLogSelect)
              .inFilter('id', ymdByLogId.keys.toList())
              .limit(400);
          for (final row in List<Map<String, dynamic>>.from(logs)) {
            final log = SupportCallLog.fromJson(row);
            final ymd = ymdByLogId[log.id];
            if (ymd == null) continue;
            events.add(
              SupportScheduleEvent(
                kind: SupportScheduleKind.quoteSend,
                ymd: ymd,
                log: log,
              ),
            );
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

enum SupportScheduleKind { visit, quoteSend }

class SupportScheduleEvent {
  const SupportScheduleEvent({
    required this.kind,
    required this.ymd,
    required this.log,
    this.caption,
  });

  final SupportScheduleKind kind;
  final String ymd;
  final SupportCallLog log;
  final String? caption;

  String get label =>
      caption ?? (kind == SupportScheduleKind.visit ? '방문예정' : '견적서 발송예정');
}

enum SupportConsultOutcome { closed, verbalQuote, quoteSend, visit }

String supportConsultOutcomeLabel(SupportConsultOutcome outcome) =>
    switch (outcome) {
      SupportConsultOutcome.closed => '마무리',
      SupportConsultOutcome.verbalQuote => '구두 견적',
      SupportConsultOutcome.quoteSend => '견적서 발송',
      SupportConsultOutcome.visit => '방문 요청',
    };

int supportConsultOutcomeStatusId(SupportConsultOutcome outcome) =>
    switch (outcome) {
      SupportConsultOutcome.closed => kSupportStatusCompleted,
      SupportConsultOutcome.verbalQuote => kSupportStatusInProgress,
      SupportConsultOutcome.quoteSend => kSupportStatusInProgress,
      SupportConsultOutcome.visit => kSupportStatusVisitScheduled,
    };

String supportConsultOutcomeLine(SupportConsultOutcome outcome, {String? ymd}) {
  final label = supportConsultOutcomeLabel(outcome);
  final day = (ymd ?? '').trim();
  if (outcome == SupportConsultOutcome.quoteSend && day.isNotEmpty) {
    return '[결과: $label · 발송예정 $day]';
  }
  if (outcome == SupportConsultOutcome.visit && day.isNotEmpty) {
    return '[결과: $label · 방문예정 $day]';
  }
  return '[결과: $label]';
}

({SupportConsultOutcome? outcome, String? ymd, String body})
parseSupportConsultation(String raw) {
  SupportConsultOutcome? outcome;
  String? ymd;
  final rest = <String>[];
  for (final line in raw.split('\n')) {
    final m = RegExp(
      r'^\[결과:\s*(마무리|구두 견적|견적서 발송|방문 요청)(?:\s*·\s*(?:발송예정|방문예정)\s*(\d{4}-\d{2}-\d{2}))?\]$',
    ).firstMatch(line.trim());
    if (m != null && outcome == null) {
      outcome = switch (m.group(1)) {
        '마무리' => SupportConsultOutcome.closed,
        '구두 견적' => SupportConsultOutcome.verbalQuote,
        '견적서 발송' => SupportConsultOutcome.quoteSend,
        '방문 요청' => SupportConsultOutcome.visit,
        _ => null,
      };
      ymd = m.group(2);
      continue;
    }
    rest.add(line);
  }
  return (outcome: outcome, ymd: ymd, body: rest.join('\n').trim());
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
