import 'package:coad_customer_calls/models/app_usage_summary.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('topTabKeyFromCounts picks highest count', () {
    expect(
      topTabKeyFromCounts({'home': 2, 'reception': 5, 'issuance': 1}),
      'reception',
    );
    expect(topTabKeyFromCounts({}), '');
  });

  test('appUsageTabLabel maps known keys', () {
    expect(appUsageTabLabel('home'), '홈');
    expect(appUsageTabLabel('reception'), '접수');
    expect(appUsageTabLabel('quoter'), '견적');
    expect(appUsageTabLabel('quoter_log'), '견적 로그');
    expect(appUsageTabLabel('unknown'), 'unknown');
    expect(appUsageTabLabel(''), '—');
  });

  test('engagementScore rewards consistency and feature breadth', () {
    const steady = AppUsageSummary(
      userId: 'a',
      userName: '꾸준',
      weekOpens: 7,
      activeDays: 7,
      topTabKey: 'reception',
      tabCounts: {
        'home': 10,
        'reception': 20,
        'issuance': 5,
        'menu': 2,
      },
    );
    const sparse = AppUsageSummary(
      userId: 'b',
      userName: '가끔',
      weekOpens: 20,
      activeDays: 1,
      topTabKey: 'home',
      tabCounts: {'home': 2},
    );

    expect(steady.engagementScore(7), greaterThan(sparse.engagementScore(7)));
    expect(steady.totalTabTaps, 37);
    expect(steady.distinctTabs, 4);
  });

  test('AppUsageInsights ranks features and users', () {
    final insights = AppUsageInsights.fromUsers(
      const [
        AppUsageSummary(
          userId: '1',
          userName: '김사용',
          weekOpens: 12,
          activeDays: 3,
          topTabKey: 'home',
          tabCounts: {'home': 5, 'reception': 2},
        ),
        AppUsageSummary(
          userId: '2',
          userName: '이활용',
          weekOpens: 6,
          activeDays: 6,
          topTabKey: 'reception',
          tabCounts: {
            'home': 3,
            'reception': 12,
            'issuance': 3,
            'menu': 1,
            'settings': 1,
          },
        ),
      ],
      periodDays: 7,
    );

    expect(insights.activeUserCount, 2);
    expect(insights.totalOpens, 18);
    expect(insights.totalTabTaps, 27);
    expect(insights.topFeatureKey, 'reception');
    expect(insights.topUsageUser?.userName, '김사용');
    expect(insights.topEngagementUser?.userName, '이활용');
    expect(insights.featureRanking.first.count, 14);
  });
}
