import 'package:coad_customer_calls/features/work/work_day_sheet.dart';
import 'package:coad_customer_calls/models/work_task.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('날짜를 누르면 예정·완료를 고른 뒤에 목록이 나온다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WorkDaySheet(
            ymd: '2026-10-22',
            onAdd: () {},
            taskBuilder: (task) => Text(task.title),
            tasks: const [
              WorkTask(
                id: '1',
                title: '예정업무',
                detail: '',
                status: '진행중',
                dueDate: '2026-10-22',
              ),
              WorkTask(
                id: '2',
                title: '완료업무',
                detail: '',
                status: '완료',
                dueDate: '2026-10-20',
                completedDate: '2026-10-22',
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('예정'), findsOneWidget);
    expect(find.text('완료'), findsOneWidget);
    expect(find.text('예정업무'), findsNothing);
    expect(find.text('완료업무'), findsNothing);
    expect(find.text('이 날 업무 추가'), findsOneWidget);

    await tester.tap(find.text('예정'));
    await tester.pumpAndSettle();

    expect(find.text('예정업무'), findsOneWidget);
    expect(find.text('완료업무'), findsNothing);
    expect(find.text('이 날 업무 추가'), findsOneWidget);

    await tester.tap(find.byTooltip('메뉴'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('완료'));
    await tester.pumpAndSettle();

    expect(find.text('완료업무'), findsOneWidget);
    expect(find.text('예정업무'), findsNothing);
    expect(find.text('이 날 업무 추가'), findsNothing);
  });
}
