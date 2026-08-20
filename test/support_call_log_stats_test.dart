import 'package:coad_customer_calls/data/support_call_log_repository.dart';
import 'package:coad_customer_calls/features/customer_support/customer_support_intake_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('service_status 4 and empty count as pending', () {
    expect(isSupportServiceStatusPending(null), isTrue);
    expect(isSupportServiceStatusPending(4), isTrue);
    expect(isSupportServiceStatusPending(1), isFalse);
    expect(isSupportServiceStatusPending(5), isFalse);
  });

  test('parseSupportIssueBody reads urgency, product, site, body', () {
    final parsed = parseSupportIssueBody('[긴급도 상] 오버헤드도어\n현장: 항\n가');
    expect(parsed.urgency, SupportUrgency.high);
    expect(parsed.productName, '오버헤드도어');
    expect(parsed.siteName, '항');
    expect(parsed.body, '가');
  });

  test('parseSupportIssueBody keeps plain issue as body', () {
    final parsed = parseSupportIssueBody('111');
    expect(parsed.urgency, SupportUrgency.mid);
    expect(parsed.productName, '');
    expect(parsed.siteName, '');
    expect(parsed.body, '111');
  });

  test('parseSupportUrlList reads json array and list', () {
    expect(parseSupportUrlList(null), isEmpty);
    expect(parseSupportUrlList(['a.jpg', 'b.pdf']), ['a.jpg', 'b.pdf']);
    expect(parseSupportUrlList('["https://x/a.jpg"]'), ['https://x/a.jpg']);
  });
}
