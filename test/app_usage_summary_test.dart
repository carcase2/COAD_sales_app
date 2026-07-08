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
    expect(appUsageTabLabel('unknown'), 'unknown');
    expect(appUsageTabLabel(''), '—');
  });
}
