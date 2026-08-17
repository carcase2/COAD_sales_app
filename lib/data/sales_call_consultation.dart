import 'package:coad_customer_calls/core/utils/date_seoul.dart';

/// 웹 `SalesCallsTab` · COAD_home `docs/flutter-sales-call-status-prompt.md` 와 동일 규칙.

class SalesCallConsultationValidationException implements Exception {
  SalesCallConsultationValidationException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// `call_statuses` id ↔ name (웹 `getStatusId` 기준, 기타는 UI·history text용)
abstract final class CallStatusIds {
  static const int undecided = 1;
  static const int lost = 2;
  static const int won = 3;
  static const int simpleInquiry = 4;
  static const int designInquiry = 5;
  static const int other = 6;
}

const Map<String, int> kCallStatusIdByName = {
  '미결정': CallStatusIds.undecided,
  '미수주': CallStatusIds.lost,
  '수주': CallStatusIds.won,
  '단순문의': CallStatusIds.simpleInquiry,
  '설계문의': CallStatusIds.designInquiry,
  '기타': CallStatusIds.other,
};

String callStatusNameFromId(int? id) {
  switch (id) {
    case CallStatusIds.undecided:
      return '미결정';
    case CallStatusIds.lost:
      return '미수주';
    case CallStatusIds.won:
      return '수주';
    case CallStatusIds.simpleInquiry:
      return '단순문의';
    case CallStatusIds.designInquiry:
    case 22:
      return '설계문의';
    case CallStatusIds.other:
      return '기타';
    default:
      return '미결정';
  }
}

/// 다음 상담 차수 = 기존 이력 건수 + 1
int nextConsultationCallStage(int existingHistoryCount) => existingHistoryCount + 1;

/// `call_history.status` (text) — 2차 이상 followUp: 단순/설계 → 기타
String callHistoryStatusText({
  required int statusId,
  required String statusName,
  required int callStage,
}) {
  if (callStage >= 2) {
    if (statusId == CallStatusIds.simpleInquiry ||
        statusId == CallStatusIds.designInquiry ||
        statusId == CallStatusIds.other) {
      return '기타';
    }
    const direct = {'미결정', '미수주', '수주', '기타'};
    if (direct.contains(statusName)) return statusName;
    return callStatusNameFromId(statusId);
  }
  return statusName;
}

String? emptyToNull(String? value) {
  final t = value?.trim() ?? '';
  return t.isEmpty ? null : t;
}

/// 웹 `InlineConsultationInputModal` / `FollowUpConsultationModal` — 예정일은 **미결정만**
bool statusRequiresNextScheduledDate(int statusId) =>
    statusId == CallStatusIds.undecided;

/// 수주·미수주·단순문의·설계문의·기타는 추가 상담 입력 불필요.
bool canEnterFurtherConsultation(int? statusId) {
  if (statusId == null) return true;
  return statusId == CallStatusIds.undecided;
}

/// 수주·미수주·단순문의·설계문의·기타 → DB `next_scheduled_date` = null
String? resolveNextScheduledDateForSave(int statusId, String? nextScheduledDateYmd) {
  if (!statusRequiresNextScheduledDate(statusId)) return null;
  return emptyToNull(nextScheduledDateYmd);
}

/// 상담 예정일 선택 후, 그날 기존 팔로우 건수 안내.
String consultationFollowDateCountMessage({
  required String ymd,
  required int? count,
}) {
  final label = formatYmdFlowLabelKo(ymd);
  if (count == null) {
    return '$label 예정 건수를 확인하지 못했습니다.';
  }
  if (count == 0) {
    return '$label에는 예정된 상담이 없습니다.';
  }
  return '$label에 이미 $count건이 예정되어 있습니다.';
}

/// 미수주·수주(종료)는 상담내용 선택 — 미수주는 `unsuccessful_reason`만 필수.
bool consultationContentRequiredForStatus(int statusId) =>
    statusId != CallStatusIds.lost && statusId != CallStatusIds.won;

void validateConsultationSubmit({
  required String consultationContent,
  required int statusId,
  required String? nextScheduledDateYmd,
  required String? unsuccessfulReason,
}) {
  if (consultationContentRequiredForStatus(statusId) &&
      consultationContent.trim().isEmpty) {
    throw SalesCallConsultationValidationException('상담내용을 입력해주세요.');
  }
  if (statusId == CallStatusIds.undecided &&
      emptyToNull(nextScheduledDateYmd) == null) {
    throw SalesCallConsultationValidationException(
      '미결정 상태일 때는 다음 상담 예정날짜를 입력해주세요.',
    );
  }
  if (statusId == CallStatusIds.lost && emptyToNull(unsuccessfulReason) == null) {
    throw SalesCallConsultationValidationException('미수주 이유를 입력해주세요.');
  }
}

Map<String, dynamic> buildCallHistoryInsert({
  required String salesCallId,
  required String consultationContent,
  required int statusId,
  required String statusName,
  required int callStage,
  required String callDateYmd,
  required String callTimeHms,
  required String? nextScheduledDateYmd,
  required String? unsuccessfulReason,
  required String createdBy,
}) {
  final nextDate = resolveNextScheduledDateForSave(statusId, nextScheduledDateYmd);
  return {
    'sales_call_id': salesCallId,
    'consultation_content': consultationContent.trim(),
    'call_date': callDateYmd,
    'call_time': callTimeHms,
    'call_stage': callStage,
    'status_id': statusId,
    'status': callHistoryStatusText(
      statusId: statusId,
      statusName: statusName,
      callStage: callStage,
    ),
    'next_scheduled_date': nextDate,
    'unsuccessful_reason':
        statusId == CallStatusIds.lost ? emptyToNull(unsuccessfulReason) : null,
    'created_by': createdBy,
  };
}

Map<String, dynamic> buildSalesCallUpdateAfterConsultation({
  required int statusId,
  required int callStage,
  required String? nextScheduledDateYmd,
}) {
  return {
    'status_id': statusId,
    'call_stage': callStage,
    'next_scheduled_date':
        resolveNextScheduledDateForSave(statusId, nextScheduledDateYmd),
    'updated_at': DateTime.now().toUtc().toIso8601String(),
  };
}

/// 접수 시 `call_stage` / `status_id` (웹 POST 동일)
({int statusId, int callStage}) registrationStatus({
  required bool isSimpleInquiry,
}) {
  if (isSimpleInquiry) {
    return (statusId: CallStatusIds.simpleInquiry, callStage: 1);
  }
  return (statusId: CallStatusIds.undecided, callStage: 0);
}

/// `call_history` 행의 상담 차수 (정수)
int parseCallStageFromHistoryMap(Map<String, dynamic> h) {
  final v = h['call_stage'] ?? h['stage'];
  if (v is int) return v;
  if (v is num) return v.toInt();
  final raw = v?.toString().trim() ?? '';
  if (raw.isEmpty || raw == '접수') return 0;
  final m = RegExp(r'(\d+)').firstMatch(raw);
  if (m == null) return 0;
  return int.tryParse(m.group(1)!) ?? 0;
}

DateTime _historySortDateTime(Map<String, dynamic> h) {
  final dateRaw = (h['call_date'] ?? '').toString().trim();
  final timeRaw = (h['call_time'] ?? '').toString().trim();
  if (dateRaw.isNotEmpty) {
    final combined = timeRaw.isNotEmpty ? '$dateRaw $timeRaw' : dateRaw;
    final parsed = DateTime.tryParse(combined.replaceFirst(' ', 'T'));
    if (parsed != null) return parsed;
  }
  final created = (h['created_at'] ?? '').toString().trim();
  if (created.isNotEmpty) {
    final parsed = DateTime.tryParse(created);
    if (parsed != null) return parsed;
  }
  return DateTime.fromMillisecondsSinceEpoch(0);
}

/// 상담 이력 UI 순서: **높은 차수 먼저** (3→2→1). DB `call_stage`가 모두 1이면 접수 시각 순으로 차수 추정.
List<Map<String, dynamic>> orderCallHistoryForDisplay(
  List<Map<String, dynamic>> history,
) {
  if (history.isEmpty) return const [];

  final asc = List<Map<String, dynamic>>.from(history)
    ..sort((a, b) => _historySortDateTime(a).compareTo(_historySortDateTime(b)));

  final parsedStages = asc.map(parseCallStageFromHistoryMap).toList();
  final distinctPositive = parsedStages.where((s) => s > 0).toSet();
  // DB에 차수가 비어 있거나 전부 1(또는 동일한 1 이하)이면 접수 시각 순으로 1·2·3차 추정
  final inferSequence = asc.length > 1 &&
      (parsedStages.every((s) => s <= 0) ||
          (distinctPositive.length <= 1 &&
              (distinctPositive.isEmpty || distinctPositive.first <= 1)));

  final enriched = <Map<String, dynamic>>[];
  for (var i = 0; i < asc.length; i++) {
    final item = Map<String, dynamic>.from(asc[i]);
    final parsed = parsedStages[i];
    item['_display_stage'] = inferSequence ? (i + 1) : (parsed > 0 ? parsed : (i + 1));
    enriched.add(item);
  }

  enriched.sort((a, b) {
    final sa = (a['_display_stage'] as num).toInt();
    final sb = (b['_display_stage'] as num).toInt();
    if (sb != sa) return sb.compareTo(sa);
    return _historySortDateTime(b).compareTo(_historySortDateTime(a));
  });

  return enriched;
}

int displayStageFromHistoryMap(Map<String, dynamic> h) {
  final injected = h['_display_stage'];
  if (injected is int) return injected;
  if (injected is num) return injected.toInt();
  final parsed = parseCallStageFromHistoryMap(h);
  return parsed > 0 ? parsed : 1;
}

String displayStageLabelFromHistoryMap(Map<String, dynamic> h) =>
    '${displayStageFromHistoryMap(h)}차';

int? statusIdFromStatusName(String? raw) {
  final name = (raw ?? '').trim();
  if (name.isEmpty || name == 'null') return null;
  return kCallStatusIdByName[name];
}

int? statusIdFromHistoryMap(Map<String, dynamic> h) {
  final v = h['status_id'];
  if (v is int) {
    return v;
  }
  if (v is num) {
    return v.toInt();
  }
  final parsed = int.tryParse('${v ?? ''}');
  if (parsed != null) return parsed;
  return statusIdFromStatusName((h['status'] ?? '').toString());
}

bool isTerminalConsultationStatus(int? statusId) =>
    statusId != null && statusId != CallStatusIds.undecided;

String? unsuccessfulReasonFromHistoryMap(Map<String, dynamic> h) {
  final raw = h['unsuccessful_reason'] ?? h['unsuccessfulReason'];
  final s = (raw ?? '').toString().trim();
  if (s.isEmpty || s == 'null') return null;
  return s;
}
