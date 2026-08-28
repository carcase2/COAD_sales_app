import 'package:coad_customer_calls/features/mes/mes_order_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('잔금은 계약금액에서 계약금·중도금을 뺀다', () {
    final rows = mesSyncBalance(
      [
        MesPayRow(kind: 'DEPOSIT', amount: '300000'),
        MesPayRow(kind: 'BALANCE'),
      ],
      1000000,
    );
    expect(rows.last.kind, 'BALANCE');
    expect(rows.last.amount, '700000');
  });

  test('현장 다음 단계는 검색 중이 아니고 현장명이 있을 때만', () {
    expect(mesCanNextSite(siteMode: 'search', siteName: '삼성'), isFalse);
    expect(mesCanNextSite(siteMode: 'new', siteName: ''), isFalse);
    expect(mesCanNextSite(siteMode: 'existing', siteName: '삼성전자'), isTrue);
  });

  test('영업 등록 payload는 웹과 같은 키를 쓴다', () {
    final body = mesBuildOrderPayload(
      draft: false,
      customerId: '',
      siteId: '',
      siteName: '삼성전자 평택',
      siteAddress: '경기 평택',
      siteAddressDetail: '3동',
      locationType: '1',
      managerName: '홍길동',
      phones: [MesPhoneRow(kind: 'mobile', phone: '01012345678')],
      branchCode: '1000',
      salesUserId: 'u1',
      installDays: [
        MesInstallDay(date: '2026-08-29', slots: [1, 2]),
      ],
      contractAmount: 1000000,
      vatIncluded: true,
      contractTypes: const ['3'],
      mfgNote: '',
      installNote: '',
      remark: '',
      items: [
        MesItemRow(productId: 'p1', qty: '2', widthMm: '3,000', heightMm: '2500', motor: 'L'),
      ],
      materials: [
        MesMatRow(materialId: 'm1', qty: '2', fromBom: true, label: 'SNS-001'),
      ],
      payments: [
        MesPayRow(kind: 'DEPOSIT', amount: '300000', dueDate: '2026-08-30', payBank: '1000'),
        MesPayRow(kind: 'BALANCE', amount: '700000', dueDate: '2026-09-30', payBank: '1000'),
      ],
      photos: [MesPhotoRef(id: 'pending:x', category: 'SITE_DRAWING')],
    );
    expect(body['branchCode'], '1000');
    expect(body['site']['name'], '삼성전자 평택');
    expect(body['site']['managerPhone'], contains('010-1234-5678'));
    expect(body['items'][0]['widthMm'], 3000);
    expect(body['items'][0]['qty'], 2);
    expect(body['installPlan'][0]['slots'], [1, 2]);
    expect(body['photos'], isEmpty);
    expect((body['payments'] as List).length, 2);
  });

  test('센서 판별은 kind와 이름 모두 본다', () {
    expect(mesIsSensor(kind: 'sensor'), isTrue);
    expect(mesIsSensor(code: 'SNS-001', name: '안전센서'), isTrue);
    expect(mesIsSensor(name: '모터'), isFalse);
  });
}
