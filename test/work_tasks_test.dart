import 'package:coad_customer_calls/core/utils/work_permissions.dart';
import 'package:coad_customer_calls/models/app_user.dart';
import 'package:coad_customer_calls/models/work_task.dart';
import 'package:flutter_test/flutter_test.dart';

AppUser _user({String role = 'user', String? groupName}) => AppUser(
  id: '김경덕',
  name: '김경덕',
  role: role,
  permissions: const [],
  groupName: groupName,
);

WorkTask _task({
  required String id,
  required String title,
  required String status,
  String? due,
}) => WorkTask(id: id, title: title, detail: '', status: status, dueDate: due);

void main() {
  test('업무관리 메뉴는 연구소와 관리자만', () {
    expect(canAccessWorkTasks(null), isFalse);
    expect(canAccessWorkTasks(_user(groupName: '연구소')), isTrue);
    expect(canAccessWorkTasks(_user(groupName: '관리자')), isTrue);
    expect(canAccessWorkTasks(_user(role: 'admin', groupName: '영업')), isFalse);
    expect(canAccessWorkTasks(_user(groupName: '기술센터')), isFalse);
  });

  test('남은 업무는 기한 지난 건, 오늘, 이후 순이고 보류는 빼지 않는다', () {
    const today = '2026-10-21';
    final board = WorkTaskBoard(
      today: today,
      assignees: const [],
      tasks: [
        _task(id: '1', title: '이후', status: '접수', due: '2026-10-25'),
        _task(id: '2', title: '오늘', status: '진행중', due: '2026-10-21'),
        _task(id: '3', title: '지남', status: '접수', due: '2026-10-01'),
        _task(id: '4', title: '보류건', status: '보류', due: '2026-10-01'),
        _task(id: '5', title: '없음', status: '접수'),
      ],
    );

    expect(board.remaining.map((task) => task.title), ['지남', '오늘', '이후', '없음']);
    expect(board.held.map((task) => task.title), ['보류건']);
    expect(board.dueTodayCount, 1);
    expect(board.overdueCount, 1);
    expect(board.remaining.first.canStart, isTrue);
    expect(board.remaining[1].canStart, isFalse);
    expect(board.held.first.canHold, isFalse);
    expect(board.held.first.canStart, isTrue);
  });

  test('오늘 완료한 업무는 남은 수에서 빠지지만 그 날과 기한에는 보인다', () {
    const today = '2026-10-22';
    final done = WorkTask(
      id: '9',
      title: '오늘 끝',
      detail: '',
      status: '완료',
      dueDate: '2026-10-20',
      completedDate: today,
    );
    final open = _task(id: '2', title: '진행', status: '진행중', due: today);
    final board = WorkTaskBoard(
      today: today,
      assignees: const [],
      tasks: [done, open],
    );

    expect(board.remaining.map((task) => task.title), ['진행']);
    expect(board.completed.map((task) => task.title), ['오늘 끝']);
    expect(board.dueTodayCount, 1);
    expect(board.overdueCount, 0);
    expect(done.isDone, isTrue);
    expect(done.canComplete, isFalse);
    expect(workTaskOnDay(done, today), isTrue);
    expect(workTaskOnDay(done, '2026-10-20'), isTrue);
    expect(workTaskOnDay(done, '2026-10-21'), isFalse);
    expect(workTaskMarkDays(done), ['2026-10-20', today]);
    expect(workTaskOnDay(open, today), isTrue);
  });

  test('완료일을 응답에서 읽고 완료 건만 완료 목록에 넣는다', () {
    final board = WorkTaskBoard.fromJson({
      'today': '2026-10-22',
      'tasks': [
        {
          'id': '9',
          'title': '끝',
          'detail': '',
          'status': '완료',
          'dueDate': '2026-10-20T00:00:00',
          'completedDate': '2026-10-22T15:00:00',
          'requester': 'coaddoor12@gmail.com',
        },
        {
          'id': '2',
          'title': '진행',
          'detail': '',
          'status': '진행중',
          'dueDate': '2026-10-22',
        },
      ],
      'assignees': [
        {'email': 'coaddoor12@gmail.com', 'name': '김경덕'},
      ],
    });

    final done = board.tasks.firstWhere((task) => task.id == '9');
    expect(done.completedDate, '2026-10-22');
    expect(done.dueDate, '2026-10-20');
    expect(done.requester, '김경덕');
    expect(board.completed.map((task) => task.title), ['끝']);
    expect(board.remaining.map((task) => task.title), ['진행']);
  });

  test('담당과 중요도로 거르고 담당자별로 묶는다', () {
    const people = [
      WorkAssignee(email: 'a@coad.co.kr', name: '김경덕'),
      WorkAssignee(email: 'b@coad.co.kr', name: '허만'),
    ];
    final tasks = [
      WorkTask(
        id: '1',
        title: '특급',
        detail: '',
        status: '접수',
        dueDate: '2026-10-21',
        assigneeEmails: const ['a@coad.co.kr'],
        priorityName: '특급',
      ),
      WorkTask(
        id: '2',
        title: '보통',
        detail: '',
        status: '진행중',
        dueDate: '2026-10-22',
        assigneeEmails: const ['b@coad.co.kr'],
        priorityName: '보통',
      ),
      WorkTask(
        id: '3',
        title: '같이',
        detail: '',
        status: '접수',
        assigneeEmails: const ['a@coad.co.kr', 'b@coad.co.kr'],
        priorityName: '높음',
      ),
    ];

    final mine = filterWorkTasks(tasks, assigneeEmail: 'a@coad.co.kr');
    expect(mine.map((task) => task.title), ['특급', '같이']);
    final urgent = filterWorkTasks(tasks, priorityName: '특급');
    expect(urgent.map((task) => task.title), ['특급']);

    final groups = groupWorkTasksByAssignee(tasks, people);
    expect(groups.map((group) => group.name), ['김경덕', '허만']);
    expect(groups.first.tasks.map((task) => task.title), ['특급', '같이']);
    expect(groups.last.tasks.map((task) => task.title), ['보통', '같이']);
  });

  test('2026년 10월 달력은 목요일에 시작하고 일을 유지한 채 달을 옮긴다', () {
    final cells = workMonthCells('2026-10-21');
    expect(cells.length % 7, 0);
    expect(cells.take(4), [null, null, null, null]);
    expect(cells[4], '2026-10-01');
    expect(cells.whereType<String>().length, 31);
    expect(shiftWorkMonth('2026-10-31', 1), '2026-11-30');
    expect(shiftWorkMonth('2026-10-21', -1), '2026-09-21');
  });

  test('업무 응답에서 중요도와 담당 메일을 읽는다', () {
    final board = WorkTaskBoard.fromJson({
      'today': '2026-10-21',
      'myEmail': 'a@coad.co.kr',
      'assignees': [
        {'email': 'a@coad.co.kr', 'name': '김경덕'},
      ],
      'priorities': [
        {'id': 2, 'name': '보통'},
        {'id': 4, 'name': '특급'},
      ],
      'tasks': [
        {
          'id': '9',
          'title': '샘플',
          'detail': '',
          'status': '접수',
          'dueDate': '2026-10-21',
          'priorityId': 4,
          'priority': '특급',
          'assigneeEmails': ['a@coad.co.kr'],
          'assigneeNames': ['김경덕'],
        },
      ],
    });

    expect(board.priorities.map((item) => item.name), ['특급', '보통']);
    expect(board.tasks.single.priorityId, '4');
    expect(board.tasks.single.priorityName, '특급');
    expect(board.tasks.single.assigneeEmails, ['a@coad.co.kr']);
    expect(workPriorityRank('특급'), lessThan(workPriorityRank('보통')));
  });

  test('요청자 메일은 담당 이름으로 바꾸고 만든 시각과 댓글을 읽는다', () {
    final board = WorkTaskBoard.fromJson({
      'today': '2026-10-21',
      'assignees': [
        {'email': 'coaddoor12@gmail.com', 'name': '김경덕'},
      ],
      'tasks': [
        {
          'id': '1',
          'title': '문',
          'detail': '',
          'status': '접수',
          'requester': 'COADDOOR12@gmail.com',
          'createdAt': '2026-10-21T06:30:00Z',
        },
      ],
    });
    expect(board.tasks.single.requester, '김경덕');
    expect(board.tasks.single.createdAt, '2026-10-21T06:30:00Z');
    final comment = WorkComment.fromJson({
      'id': 'c1',
      'author': '김경덕',
      'content': '확인했습니다',
      'createdAt': '2026-10-21T07:00:00Z',
    });
    expect(comment.author, '김경덕');
    expect(comment.content, '확인했습니다');
  });

  test('같은 담당 목록은 서로 다른 색 칸을 받고 순서가 바뀌어도 같다', () {
    const emails = [
      'b@coad.co.kr',
      'a@coad.co.kr',
      'c@coad.co.kr',
      'd@coad.co.kr',
    ];
    final slots = workAssigneeColorSlots(emails);
    expect(slots.values.toSet(), hasLength(4));
    expect(workAssigneeColorSlots(emails.reversed), slots);
    expect(workAssigneePaletteSize, 8);
  });

  test('담당자별 보드는 업무가 없는 사람도 포함하고 특급 수를 센다', () {
    const people = [
      WorkAssignee(email: 'a@coad.co.kr', name: '김경덕'),
      WorkAssignee(email: 'b@coad.co.kr', name: '허만'),
    ];
    final boards = workPersonBoards([
      WorkTask(
        id: '1',
        title: '급함',
        detail: '',
        status: '접수',
        assigneeEmails: const ['a@coad.co.kr'],
        priorityName: '특급',
      ),
    ], people);
    expect(boards.map((board) => board.name), ['김경덕', '허만']);
    expect(boards.first.urgentCount, 1);
    expect(boards.last.tasks, isEmpty);
  });

  test('김경덕test 담당은 고르는 목록과 카드 이름에서 뺀다', () {
    const people = [
      WorkAssignee(email: 'coaddoor12@gmail.com', name: '김경덕'),
      WorkAssignee(email: 'carcase2@gmail.com', name: '김경덕test'),
      WorkAssignee(email: 'b@coad.co.kr', name: '허만'),
    ];
    expect(visibleWorkAssignees(people).map((person) => person.name), [
      '김경덕',
      '허만',
    ]);
    expect(workAssigneeHidden(name: '김경덕test'), isTrue);
    expect(workAssigneeHidden(email: 'CARCASE2@gmail.com'), isTrue);
    expect(workAssigneeHidden(name: '김경덕'), isFalse);

    final labels = visibleTaskAssignees(
      WorkTask(
        id: '1',
        title: '같이',
        detail: '',
        status: '접수',
        assigneeNames: const ['김경덕', '김경덕test'],
        assigneeEmails: const ['coaddoor12@gmail.com', 'carcase2@gmail.com'],
      ),
    );
    expect(labels.map((person) => person.name), ['김경덕']);
  });
}
