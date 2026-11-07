import 'package:coad_customer_calls/features/work/work_task_card.dart';
import 'package:coad_customer_calls/features/work/work_task_list_page.dart';
import 'package:coad_customer_calls/models/work_task.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

WorkTask _task(
  String id, {
  String status = '접수',
  String? due,
  String priority = '보통',
  String completed = '',
}) => WorkTask(
  id: id,
  detail: '',
  title: '업무 $id 제목이 조금 긴 경우에도 줄바꿈이 잘 되는지 확인',
  status: status,
  dueDate: due,
  priorityName: priority,
  requester: '권요한',
  assigneeEmails: const ['a@x.com', 'b@x.com'],
  assigneeNames: const ['허만', '김경덕'],
  completedDate: completed,
);

void main() {
  const today = '2026-11-07';

  testWidgets('카드는 할 일·완료를 글자로 구분한다', (tester) async {
    tester.view.physicalSize = const Size(375 * 3, 812 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    var completed = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              WorkTaskCard(
                task: _task('1', due: '2026-11-03', priority: '특급'),
                today: today,
                busy: false,
                assigneeColors: const {},
                onStart: () {},
                onComplete: () => completed++,
              ),
              WorkTaskCard(
                task: _task('2', status: '완료', completed: '2026-11-06'),
                today: today,
                busy: false,
                assigneeColors: const {},
                onReopen: () {},
              ),
              WorkTaskCard(
                task: _task('3', status: '진행중', due: '2026-11-07'),
                today: today,
                busy: false,
                assigneeColors: const {},
                onComplete: () {},
              ),
            ],
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('완료하기'), findsNWidgets(2));
    expect(find.text('완료됨'), findsOneWidget);
    expect(find.text('4일 지남 · 11/3'), findsOneWidget);
    expect(find.text('오늘 마감'), findsOneWidget);
    expect(find.text('완료 11/6'), findsOneWidget);
    expect(find.text('할 일'), findsOneWidget);
    expect(find.text('담당 허만, 김경덕 · 요청 권요한'), findsNWidgets(3));
    await tester.tap(find.text('완료하기').first);
    expect(completed, 1);
  });

  testWidgets('목록 화면은 기한 묶음과 완료 날 묶음으로 나눈다', (tester) async {
    tester.view.physicalSize = const Size(375 * 3, 812 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final tick = ValueNotifier(0);
    addTearDown(tick.dispose);
    final board = WorkTaskBoard(
      today: today,
      assignees: const [WorkAssignee(email: 'a@x.com', name: '허만')],
      tasks: [
        _task('1', due: '2026-11-03'),
        _task('2', due: '2026-11-07'),
        _task('3', due: '2026-11-09'),
        _task('4'),
        _task('5', status: '완료', completed: '2026-11-07'),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: WorkTaskListPage(
          tick: tick,
          board: () => board,
          busy: () => false,
          colors: () => const {},
          card: (task) => Text('card ${task.id}'),
          onAdd: (_) {},
          onRefresh: () async {},
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('할 일 4'), findsOneWidget);
    expect(find.text('기한 지남'), findsOneWidget);
    expect(find.text('오늘 마감'), findsOneWidget);
    expect(find.text('이번 주'), findsOneWidget);
    await tester.tap(find.text('완료 1'));
    await tester.pumpAndSettle();
    expect(find.text('오늘 완료'), findsOneWidget);
    expect(find.text('card 5'), findsOneWidget);
  });
}
