import 'package:coad_customer_calls/features/home/home_flow_stats.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('홈 영업부 통계 카드 숫자·라벨이 크게 보인다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HomeMiniStatsWidget(
            compact: true,
            receptionLabel: '금일 접수',
            incompleteLabel: '금일 미통화',
            followLabel: '금일 팔로우',
            updatedLabel: '금일 업데이트',
            today: 3,
            incomplete: 2,
            todayFollow: 4,
            updated: 1,
            uncalledRateText: '10.0%',
            avgFirstResponseText: '5분',
            onTapToday: () {},
            onTapIncomplete: () {},
            onTapTodayFollow: () {},
            onTapUpdated: () {},
            onTapUncalledRate: () {},
            onTapFirstResponse: () {},
          ),
        ),
      ),
    );

    expect(find.text('영업부'), findsNothing);
    expect(find.text('금일 접수'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);

    final value = tester.widget<Text>(find.text('3'));
    expect(value.style?.fontSize, 20);

    final label = tester.widget<Text>(find.text('금일 접수'));
    expect(label.style?.fontSize, 14.5);
  });

  testWidgets('홈 고객지원팀 통계 카드도 같은 크기를 쓴다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HomeSupportMiniStatsWidget(
            compact: true,
            receptionLabel: '금일 A/S',
            pendingLabel: '금일 미처리',
            visitLabel: '금일 방문',
            updatedLabel: '금일 업데이트',
            reception: 5,
            pending: 1,
            visits: 2,
            updated: 0,
            onTapReception: () {},
            onTapPending: () {},
            onTapVisit: () {},
            onTapUpdated: () {},
          ),
        ),
      ),
    );

    expect(find.text('고객지원팀'), findsNothing);

    final value = tester.widget<Text>(find.text('5'));
    expect(value.style?.fontSize, 20);
  });

  testWidgets('홈 고객지원팀 통계에 전체 카드가 보인다', (tester) async {
    var opened = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HomeSupportMiniStatsWidget(
            compact: true,
            receptionLabel: '금일 A/S',
            pendingLabel: '금일 미처리',
            visitLabel: '금일 방문',
            updatedLabel: '금일 업데이트',
            reception: 5,
            pending: 1,
            visits: 2,
            updated: 0,
            onTapReception: () {},
            onTapPending: () {},
            onTapVisit: () {},
            onTapUpdated: () {},
            onTapAll: () => opened = true,
            allCount: 12,
            onTapAllPending: () {},
            onTapAllIncomplete: () {},
          ),
        ),
      ),
    );

    expect(find.text('전체'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
    await tester.tap(find.text('전체'));
    await tester.pump();
    expect(opened, isTrue);
  });
}
