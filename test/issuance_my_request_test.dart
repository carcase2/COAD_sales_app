import 'package:coad_customer_calls/features/issuance/issuance_request_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  IssuanceRequestRow taxRow({
    required String name,
    String invoice = '',
    String requester = '김경덕',
  }) {
    return IssuanceRequestRow(
      domain: IssuanceDomain.taxInvoice,
      kind: IssuanceRowKind.request,
      master: {
        'id': name,
        'customer_name': name,
        'invoice_number': invoice,
        'requester': requester,
      },
      issue: null,
    );
  }

  test('issuanceRowMatchesQuery — 현장명·번호', () {
    final row = taxRow(name: '삼성전자 평택', invoice: 'TAX-202608-0012');
    expect(issuanceRowMatchesQuery(row, '삼성'), isTrue);
    expect(issuanceRowMatchesQuery(row, '평택'), isTrue);
    expect(issuanceRowMatchesQuery(row, '202608'), isTrue);
    expect(issuanceRowMatchesQuery(row, '현대'), isFalse);
    expect(issuanceRowMatchesQuery(row, ''), isTrue);
  });

  test('issuanceIsOwnRequest — 요청자 이름', () {
    final row = taxRow(name: '현장', requester: '김경덕');
    expect(issuanceIsOwnRequest(row, '김경덕'), isTrue);
    expect(issuanceIsOwnRequest(row, '홍길동'), isFalse);
  });

  test('leftoverRequestPct — 첫 요청 30%면 잔여 70', () {
    final pending30 = IssuanceRequestRow(
      domain: IssuanceDomain.taxInvoice,
      kind: IssuanceRowKind.request,
      master: {'percentage': 30, 'customer_name': '현장'},
      issue: null,
    );
    expect(pending30.leftoverRequestPct, 70);

    final partial = IssuanceRequestRow(
      domain: IssuanceDomain.taxInvoice,
      kind: IssuanceRowKind.partial,
      issuedPct: 40,
      remainingPct: 60,
      master: {'percentage': 40, 'customer_name': '현장'},
      issue: null,
    );
    expect(partial.leftoverRequestPct, 60);
  });
}
