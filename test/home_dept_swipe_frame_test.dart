import 'package:coad_customer_calls/features/home/home_dept_swipe_frame.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _labels = ['영업부', '고객지원팀', '자동문의고수'];

Widget _frame({
  required double width,
  required int pageIndex,
  required ValueChanged<int> onGoTo,
  Widget? child,
}) {
  return MaterialApp(
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: width,
          height: 640,
          child: HomeDeptSwipeFrame(
            pageIndex: pageIndex,
            pageCount: 3,
            pageLabels: _labels,
            onGoTo: onGoTo,
            accentFor: (index) => Colors.primaries[index],
            child:
                child ??
                const ColoredBox(
                  key: Key('dept-page'),
                  color: Colors.white,
                  child: Row(children: [Text('왼쪽글자'), Spacer(), Text('오른쪽글자')]),
                ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('좁은 폰 너비에서는 화살표를 숨기고 내용이 가득 찬다', (tester) async {
    for (final width in [320.0, 360.0, 399.0]) {
      await tester.pumpWidget(
        _frame(width: width, pageIndex: 1, onGoTo: (_) {}),
      );

      expect(find.byIcon(Icons.chevron_left_rounded), findsNothing);
      expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);
      expect(find.text('왼쪽글자'), findsOneWidget);
      expect(find.text('오른쪽글자'), findsOneWidget);

      final frame = tester.getRect(find.byType(HomeDeptSwipeFrame));
      final page = tester.getRect(find.byKey(const Key('dept-page')));
      expect(page.left, frame.left);
      expect(page.right, frame.right);
      expect(page.width, width);
    }
  });

  testWidgets('좁은 화면에서도 스와이프로 페이지를 넘긴다', (tester) async {
    final controller = PageController();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    });

    await tester.pumpWidget(
      _frame(
        width: 360,
        pageIndex: 0,
        onGoTo: (_) {},
        child: PageView(
          controller: controller,
          children: const [
            Center(child: Text('영업카드')),
            Center(child: Text('지원카드')),
            Center(child: Text('고수카드')),
          ],
        ),
      ),
    );

    await tester.drag(find.byType(PageView), const Offset(-280, 0));
    await tester.pumpAndSettle();

    expect(controller.page, closeTo(1, 0.01));
    expect(find.text('지원카드'), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);
  });

  testWidgets('넓은 화면 화살표는 카드 글자와 겹치지 않는다', (tester) async {
    final visits = <int>[];
    await tester.pumpWidget(
      _frame(width: 800, pageIndex: 1, onGoTo: visits.add),
    );

    final page = tester.getRect(find.byKey(const Key('dept-page')));
    final leftText = tester.getRect(find.text('왼쪽글자'));
    final rightText = tester.getRect(find.text('오른쪽글자'));
    final leftArrow = tester.getRect(find.byTooltip('영업부'));
    final rightArrow = tester.getRect(find.byTooltip('자동문의고수'));

    expect(leftArrow.right, lessThanOrEqualTo(page.left));
    expect(rightArrow.left, greaterThanOrEqualTo(page.right));
    expect(leftArrow.overlaps(leftText), isFalse);
    expect(leftArrow.overlaps(rightText), isFalse);
    expect(rightArrow.overlaps(leftText), isFalse);
    expect(rightArrow.overlaps(rightText), isFalse);
    expect(page.width, 800 - HomeDeptSwipeFrame.laneWidth * 2);

    expect(leftArrow.width, lessThanOrEqualTo(24));
    expect(rightArrow.width, lessThanOrEqualTo(24));

    await tester.tap(find.byIcon(Icons.chevron_right_rounded));
    await tester.pump();
    expect(visits, [2]);

    await tester.tap(find.byIcon(Icons.chevron_left_rounded));
    await tester.pump();
    expect(visits, [2, 0]);
  });

  testWidgets('끝 페이지에서는 진행 방향 화살표만 레일 밖에 둔다', (tester) async {
    await tester.pumpWidget(_frame(width: 480, pageIndex: 0, onGoTo: (_) {}));

    expect(find.byIcon(Icons.chevron_left_rounded), findsNothing);
    final rightArrow = tester.getRect(find.byIcon(Icons.chevron_right_rounded));
    final page = tester.getRect(find.byKey(const Key('dept-page')));
    expect(rightArrow.left, greaterThanOrEqualTo(page.right));
    expect(find.byTooltip('고객지원팀'), findsOneWidget);

    await tester.pumpWidget(_frame(width: 480, pageIndex: 2, onGoTo: (_) {}));
    expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);
    final leftArrow = tester.getRect(find.byIcon(Icons.chevron_left_rounded));
    final lastPage = tester.getRect(find.byKey(const Key('dept-page')));
    expect(leftArrow.right, lessThanOrEqualTo(lastPage.left));
    expect(find.byTooltip('고객지원팀'), findsOneWidget);
  });
}
