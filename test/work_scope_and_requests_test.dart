import 'package:coad_customer_calls/models/work_request.dart';
import 'package:coad_customer_calls/models/work_task.dart';
import 'package:flutter_test/flutter_test.dart';

WorkTask _task(
  String id, {
  String status = '접수',
  String? due,
  List<String> emails = const [],
  String requester = '',
  String priority = '',
  String completed = '',
  String detail = '',
}) => WorkTask(
  id: id,
  title: '업무$id',
  detail: detail,
  status: status,
  dueDate: due,
  assigneeEmails: emails,
  assigneeNames: [for (final e in emails) e.split('@').first],
  requester: requester,
  priorityName: priority,
  completedDate: completed,
);

WorkRequest _req(
  String id, {
  String status = '요청',
  String progress = '',
  String from = '영업',
  String to = '연구소',
  String created = '2026-11-01',
  String requesterId = 'u1',
}) => WorkRequest(
  id: id,
  title: '요청$id',
  fromGroup: from,
  toGroup: to,
  status: status,
  progress: progress,
  createdAt: created,
  requesterUserId: requesterId,
);

void main() {
  group('업무 범위·검색·묶음', () {
    final tasks = [
      _task('1', emails: ['me@x.com'], requester: '허만'),
      _task('2', emails: ['other@x.com'], requester: '김경덕'),
      _task('3', emails: ['me@x.com', 'other@x.com'], detail: '도면 수정'),
    ];

    test('내 업무는 담당에 내 메일, 내가 요청은 요청인이 내 이름', () {
      expect(
        scopeWorkTasks(
          tasks,
          WorkTaskScope.mine,
          myEmail: 'me@x.com',
        ).map((t) => t.id),
        ['1', '3'],
      );
      expect(
        scopeWorkTasks(
          tasks,
          WorkTaskScope.requested,
          myName: '김경덕',
        ).map((t) => t.id),
        ['2'],
      );
      expect(scopeWorkTasks(tasks, WorkTaskScope.mine), isEmpty);
      expect(scopeWorkTasks(tasks, WorkTaskScope.all).length, 3);
    });

    test('검색은 띄어쓰기를 무시하고 내용·담당 이름도 본다', () {
      expect(searchWorkTasks(tasks, '도면수정').map((t) => t.id), ['3']);
      expect(searchWorkTasks(tasks, 'other').map((t) => t.id), ['2', '3']);
      expect(searchWorkTasks(tasks, '  ').length, 3);
    });

    test('기한 지남·오늘·이번 주·그 뒤·없음으로 묶고 묶음 안은 특급·진행중부터', () {
      const today = '2026-11-07';
      final sections = workTaskSections([
        _task('a', due: '2026-11-10'),
        _task('b', due: '2026-11-07', priority: '보통'),
        _task('c', due: '2026-11-07', priority: '특급'),
        _task('d'),
        _task('e', due: '2026-11-01'),
        _task('f', due: '2026-11-20'),
        _task('g', due: '2026-11-07', priority: '보통', status: '진행중'),
      ], today);
      expect(sections.map((s) => s.group), [
        WorkTaskGroup.overdue,
        WorkTaskGroup.today,
        WorkTaskGroup.week,
        WorkTaskGroup.later,
        WorkTaskGroup.undated,
      ]);
      expect(sections[1].tasks.map((t) => t.id), ['c', 'g', 'b']);
      expect(sections.first.label, '기한 지남');
    });

    test('묶음 개수와 기한까지 남은 날', () {
      const today = '2026-11-07';
      final counts = workTaskGroupCounts([
        _task('a', due: '2026-11-06'),
        _task('b', due: '2026-11-13'),
        _task('c', due: '2026-11-14'),
      ], today);
      expect(counts[WorkTaskGroup.overdue], 1);
      expect(counts[WorkTaskGroup.week], 1);
      expect(counts[WorkTaskGroup.later], 1);
      expect(counts[WorkTaskGroup.today], 0);
      expect(workDueOffset('2026-12-01', '2026-11-30'), 1);
      expect(workDueOffset(null, today), isNull);
    });

    test('최근 완료는 늦게 끝낸 것부터이고 다시 열 수 있다', () {
      final board = WorkTaskBoard(
        today: '2026-11-07',
        assignees: const [],
        tasks: [
          _task('x', status: '완료', completed: '2026-11-01'),
          _task('y', status: '완료', completed: '2026-11-06'),
          _task('z'),
        ],
      );
      expect(board.recentDone.map((t) => t.id), ['y', 'x']);
      expect(board.remaining.map((t) => t.id), ['z']);
      expect(board.recentDone.first.canReceive, isTrue);
      expect(board.recentDone.first.canComplete, isFalse);
    });

    test('응답의 myName·completedDate 를 읽는다', () {
      final board = WorkTaskBoard.fromJson({
        'today': '2026-11-07',
        'myName': '김경덕',
        'tasks': [
          {
            'id': '1',
            'title': 't',
            'status': '완료',
            'completedDate': '2026-11-05T00:00',
          },
        ],
        'assignees': [],
      });
      expect(board.myName, '김경덕');
      expect(board.tasks.single.completedDate, '2026-11-05');
    });
  });

  group('부서 요청', () {
    test('받은 요청은 처리할 것부터, 보낸 요청은 내 부서 것', () {
      final board = WorkRequestBoard(
        today: '2026-11-07',
        viewer: const WorkRequestViewer(id: 'u9', name: '허만', groupName: '연구소'),
        targets: const ['영업'],
        requests: [
          _req('done', status: '수락', progress: '완료', created: '2026-11-05'),
          _req('new', created: '2026-11-02'),
          _req('held', status: '보류', created: '2026-11-06'),
          _req('mine', from: '연구소', to: '영업', requesterId: 'u9'),
        ],
      );
      expect(board.incoming.map((r) => r.id), ['new', 'held', 'done']);
      expect(board.outgoing.map((r) => r.id), ['mine']);
      expect(board.waitingCount, 1);
    });

    test('관리자는 모든 받은 요청을 본다', () {
      final board = WorkRequestBoard(
        today: '',
        viewer: const WorkRequestViewer(
          id: 'a',
          name: '관리자',
          groupName: '관리자',
          seeAll: true,
        ),
        targets: const [],
        requests: [
          _req('1'),
          _req('2', to: '총무'),
        ],
      );
      expect(board.incoming.length, 2);
    });

    test('상태 표시와 다음 진행 단계', () {
      expect(_req('1').stateLabel, '요청');
      expect(_req('1', status: '수락', progress: '접수').stateLabel, '수락 · 접수');
      expect(nextWorkRequestProgress(_req('1')), isNull);
      expect(
        nextWorkRequestProgress(_req('1', status: '수락', progress: '접수')),
        '진행중',
      );
      expect(
        nextWorkRequestProgress(_req('1', status: '수락', progress: '진행중')),
        '완료',
      );
      expect(
        nextWorkRequestProgress(_req('1', status: '수락', progress: '완료')),
        isNull,
      );
      expect(_req('1', status: '수락', progress: '완료').isClosed, isTrue);
      expect(_req('1', status: '거절').isClosed, isTrue);
      expect(_req('1', status: '수락', progress: '진행중').decisionOpen, isFalse);
    });

    test('서버 응답을 읽는다', () {
      final board = WorkRequestBoard.fromJson({
        'today': '2026-11-07',
        'viewer': {'id': 'u1', 'name': '김', 'groupName': '영업', 'seeAll': false},
        'targets': ['연구소', '총무'],
        'requests': [
          {
            'id': 'r1',
            'title': '도면',
            'fromGroup': '영업',
            'toGroup': '연구소',
            'status': '요청',
            'dueDate': '2026-11-09',
            'canCancel': true,
          },
        ],
      });
      expect(board.targets, ['연구소', '총무']);
      expect(board.requests.single.canCancel, isTrue);
      expect(board.requests.single.priority, '보통');
      expect(board.priorities, workRequestPriorities);
    });
  });
}
