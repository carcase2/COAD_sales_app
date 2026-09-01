import 'package:coad_customer_calls/core/constants/gosu_appsheet.dart';
import 'package:coad_customer_calls/core/utils/gosu_calls_utils.dart';
import 'package:coad_customer_calls/core/utils/gosu_permissions.dart';
import 'package:coad_customer_calls/models/app_user.dart';
import 'package:coad_customer_calls/models/gosu_sales_call.dart';
import 'package:flutter_test/flutter_test.dart';

GosuSalesCall _call({
  String followUp = kGosuProgressOpen,
  int callStage = 0,
  String followUpContent = '',
  String? nextScheduledDate,
  String source = 'app',
  List<GosuCallHistory> history = const [],
}) {
  return GosuSalesCall(
    id: '1',
    followUp: followUp,
    callStage: callStage,
    followUpContent: followUpContent,
    nextScheduledDate: nextScheduledDate,
    source: source,
    callHistory: history,
  );
}

AppUser _user({
  String role = 'user',
  String? groupName,
  List<String> permissions = const [],
}) => AppUser(
  id: '1',
  name: '테스트',
  role: role,
  permissions: permissions,
  groupName: groupName,
);

void main() {
  test('접수만 된 건도 종료 전이면 팔로업중', () {
    final row = _call();
    expect(isGosuFollowUpOpen(row), isTrue);
    expect(isGosuAwaitingFirstFollowUp(row), isTrue);
    expect(isGosuActiveFollowUp(row), isFalse);
    expect(gosuWorkflowStatusLabel(row), kGosuStatusReceived);
  });

  test('1차 이후 미종료도 팔로업중(종료 전)이다', () {
    final row = _call(callStage: 1);
    expect(isGosuFollowUpOpen(row), isTrue);
    expect(isGosuActiveFollowUp(row), isTrue);
  });

  test('1차 이후 미종료는 기존진행중', () {
    final row = _call(callStage: 1);
    expect(isGosuActiveFollowUp(row), isTrue);
    expect(isGosuAwaitingFirstFollowUp(row), isFalse);
    expect(gosuWorkflowStatusLabel(row), kGosuProgressOpen);
  });

  test('AppSheet 이관·팔로업 내용만 있어도 기존진행중', () {
    expect(isGosuActiveFollowUp(_call(source: 'appsheet')), isTrue);
    expect(isGosuAwaitingFirstFollowUp(_call(source: 'appsheet')), isFalse);
    expect(isGosuActiveFollowUp(_call(followUpContent: '안내함')), isTrue);
    expect(
      isGosuActiveFollowUp(_call(nextScheduledDate: '2026-09-01')),
      isTrue,
    );
  });

  test('종료 건은 달력에서 제외', () {
    final row = _call(
      followUp: kGosuProgressClosed,
      callStage: 1,
      nextScheduledDate: '2026-08-31',
    );
    expect(isGosuClosed(row), isTrue);
    expect(isGosuFollowUpOpen(row), isFalse);
    expect(isGosuCalendarScheduled(row), isFalse);
  });

  test('금일 팔로우는 예정일이 기간 안이고 미종료일 때만', () {
    expect(
      isGosuFollowDueInRange(
        _call(nextScheduledDate: '2026-09-01'),
        fromYmd: '2026-09-01',
        toYmdInclusive: '2026-09-01',
      ),
      isTrue,
    );
    expect(
      isGosuFollowDueInRange(
        _call(nextScheduledDate: '2026-09-02'),
        fromYmd: '2026-09-01',
        toYmdInclusive: '2026-09-01',
      ),
      isFalse,
    );
    expect(
      isGosuFollowDueInRange(
        _call(followUp: kGosuProgressClosed, nextScheduledDate: '2026-09-01'),
        fromYmd: '2026-09-01',
        toYmdInclusive: '2026-09-01',
      ),
      isFalse,
    );
  });

  test('담당자 칩은 자동문의고수 부서만 두고 빈 값은 뺀다', () {
    expect(
      gosuAssigneeChoices(departmentNames: const ['정은실', '운영팀', '', '김민주']),
      ['김민주', '운영팀', '정은실'],
    );
    expect(gosuAssigneeChoices(departmentNames: const ['  ']), isEmpty);
  });

  test('다음 팔로업 차수', () {
    expect(getNextGosuFollowUpStage(0, 0), 1);
    expect(getNextGosuFollowUpStage(1, 1), 2);
    expect(gosuStageLabel(0), '미팔로업');
    expect(gosuStageLabel(2), '2차 팔로업');
  });

  test('진행중 팔로업은 예정일 필수', () {
    expect(
      validateGosuFollowUpForm(
        consultationContent: '안내',
        nextScheduledDate: '',
        followResult: kGosuProgressOpen,
      ),
      isNotNull,
    );
    expect(
      validateGosuFollowUpForm(
        consultationContent: '안내',
        nextScheduledDate: '2026-09-01',
        followResult: kGosuProgressOpen,
      ),
      isNull,
    );
    expect(
      validateGosuFollowUpForm(
        consultationContent: '종료',
        nextScheduledDate: '',
        followResult: kGosuProgressClosed,
      ),
      isNull,
    );
  });

  test('영업부·고객지원·고수 권한이면 자동문의고수 접근', () {
    expect(canAccessGosuCalls(_user(role: 'admin')), isTrue);
    expect(canAccessGosuCalls(_user(permissions: ['gosu_calls'])), isTrue);
    expect(canAccessGosuCalls(_user(permissions: ['support'])), isTrue);
    expect(canAccessGosuCalls(_user(permissions: ['sales_calls'])), isTrue);
    expect(canAccessGosuCalls(_user(groupName: '자동문의고수')), isTrue);
    expect(canAccessGosuCalls(_user(permissions: ['mail'])), isFalse);
  });
}
