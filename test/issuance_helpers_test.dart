import 'package:coad_customer_calls/features/issuance/issuance_helpers.dart';
import 'package:coad_customer_calls/features/issuance/issuance_request_provider.dart';
import 'package:flutter_test/flutter_test.dart';

IssuanceRequestRow _row({
  Map<String, dynamic>? issue,
  Map<String, dynamic>? master,
}) {
  return IssuanceRequestRow(
    master: master ?? const {'id': '1', 'created_at': '2026-06-18T00:00:00Z'},
    issue: issue,
    domain: IssuanceDomain.taxInvoice,
    kind: IssuanceRowKind.issued,
    issuedPct: 100,
    remainingPct: 0,
  );
}

void main() {
  test('issuanceIssueYmdForRow prefers issue_date', () {
    final ymd = issuanceIssueYmdForRow(
      _row(
        issue: const {'issue_date': '2026-06-17'},
        master: const {'id': '1', 'issue_date': '2026-06-18'},
      ),
    );
    expect(ymd, '2026-06-17');
  });

  test('issuanceIssueYmdForRow falls back to master issue_date', () {
    final ymd = issuanceIssueYmdForRow(
      _row(
        master: const {'id': '1', 'issue_date': '2026-06-18'},
      ),
    );
    expect(ymd, '2026-06-18');
  });
}
