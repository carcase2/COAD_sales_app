import 'package:coad_customer_calls/core/constants/gosu_appsheet.dart';
import 'package:coad_customer_calls/models/gosu_sales_call.dart';

int gosuCallStageOf(GosuSalesCall row) => row.callStage;

bool isGosuFollowUpStarted(GosuSalesCall row) {
  if (gosuCallStageOf(row) >= 1) return true;
  if ((row.followUpContent ?? '').trim().isNotEmpty) return true;
  if ((row.nextScheduledDate ?? '').trim().isNotEmpty) return true;
  if (row.callHistory.isNotEmpty) return true;
  if (row.source == 'appsheet') return true;
  return false;
}

bool isGosuOpen(GosuSalesCall row) =>
    gosuProgressOf(row.followUp) == kGosuProgressOpen;

bool isGosuClosed(GosuSalesCall row) =>
    gosuProgressOf(row.followUp) == kGosuProgressClosed;

String gosuProgressOf(String? followUp) =>
    followUp == kGosuProgressClosed ? kGosuProgressClosed : kGosuProgressOpen;

String gosuWorkflowStatusLabel(GosuSalesCall row) {
  if (isGosuClosed(row)) return kGosuProgressClosed;
  if (!isGosuFollowUpStarted(row)) return kGosuStatusReceived;
  return kGosuProgressOpen;
}

/// 1차 이상 팔로업 후 아직 종료 전 — 기존진행중.
bool isGosuActiveFollowUp(GosuSalesCall row) =>
    isGosuOpen(row) && isGosuFollowUpStarted(row);

/// 접수만 되고 1차 팔로업 전 — 목록 필터 '접수'.
bool isGosuAwaitingFirstFollowUp(GosuSalesCall row) =>
    isGosuOpen(row) && !isGosuFollowUpStarted(row);

/// 종료 전 전체 — 홈 카드 '팔로업중'.
bool isGosuFollowUpOpen(GosuSalesCall row) => isGosuOpen(row);

int getNextGosuFollowUpStage(int historyLength, int? currentStage) {
  final stage = currentStage ?? 0;
  if (historyLength > 0) return historyLength + 1;
  return stage > 0 ? stage + 1 : 1;
}

String gosuStageLabel(int stage) {
  if (stage <= 0) return '미팔로업';
  return '$stage차 팔로업';
}

bool isGosuCalendarScheduled(GosuSalesCall row) {
  if ((row.nextScheduledDate ?? '').trim().isEmpty) return false;
  if (isGosuClosed(row)) return false;
  return true;
}

/// 고수 접수 담당자 칩. 인트라넷과 같이 자동문의고수 부서만. 비워도 됨.
List<String> gosuAssigneeChoices({
  required Iterable<String> departmentNames,
}) {
  final names = <String>{};
  for (final raw in departmentNames) {
    final n = raw.trim();
    if (n.isNotEmpty) names.add(n);
  }
  final list = names.toList()..sort((a, b) => a.compareTo(b));
  return list;
}

String? validateGosuFollowUpForm({
  required String consultationContent,
  required String nextScheduledDate,
  required String followResult,
}) {
  if (consultationContent.trim().isEmpty) return '팔로업 내용을 입력하세요.';
  if (followResult == kGosuProgressOpen && nextScheduledDate.trim().isEmpty) {
    return '진행중이면 다음 팔로업 예정일을 입력하세요.';
  }
  return null;
}
