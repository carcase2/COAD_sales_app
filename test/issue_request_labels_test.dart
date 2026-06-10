import 'package:coad_customer_calls/features/issue_request/issue_request_labels.dart';
import 'package:coad_customer_calls/features/issue_request/issue_request_user_id.dart';
import 'package:coad_customer_calls/models/app_user.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('IssueRequestLabels', () {
    test('requestTypeLabel — 알려진 유형', () {
      expect(IssueRequestLabels.requestTypeLabel('tax_invoice'), '세금계산서');
      expect(IssueRequestLabels.requestTypeLabel('performance_bond'), '이행증권');
    });

    test('statusLabel — pending/approved/rejected', () {
      expect(IssueRequestLabels.statusLabel('pending'), '대기');
      expect(IssueRequestLabels.statusLabel('approved'), '승인');
      expect(IssueRequestLabels.statusLabel('rejected'), '반려');
    });
  });

  group('resolveIssueRequestUserId', () {
    test('숫자 로그인 ID', () {
      final user = AppUser(
        id: '42',
        name: '테스트',
        role: 'user',
        permissions: const [],
      );
      expect(resolveIssueRequestUserId(user), 42);
    });

    test('비숫자 로그인 ID', () {
      final user = AppUser(
        id: 'admin',
        name: '관리자',
        role: 'admin',
        permissions: const [],
      );
      expect(resolveIssueRequestUserId(user), isNull);
    });
  });
}
