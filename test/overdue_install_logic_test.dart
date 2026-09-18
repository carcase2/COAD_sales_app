import 'package:coad_customer_calls/features/issuance/overdue_install_logic.dart';
import 'package:coad_customer_calls/models/overdue_install_site.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('예정일은 오늘 이전만 지난 것으로 본다', () {
    expect(overdueInstallIsOverdue('2026-09-17', '2026-09-18'), isTrue);
    expect(overdueInstallIsOverdue('2026-09-18', '2026-09-18'), isFalse);
    expect(overdueInstallIsOverdue('2026-09-19', '2026-09-18'), isFalse);
    expect(overdueInstallIsOverdue('', '2026-09-18'), isFalse);
  });

  test('담당자는 우리 등록자를 우선한다', () {
    expect(overdueInstallAssigneeKey(managerNm: '현장담당', regUsr: '김경덕'), '김경덕');
    expect(
      overdueInstallAssigneeKey(managerNm: '김경덕', regUsr: '1850017'),
      '김경덕',
    );
    expect(overdueInstallAssigneeKey(managerNm: '', regUsr: '박영업'), '박영업');
    expect(
      overdueInstallAssigneeKey(managerNm: '', regUsr: ''),
      kOverdueInstallMissingAssignee,
    );
  });

  test('앱 users 이름과 맞으면 그 사람을 우리 담당자로 쓴다', () {
    expect(
      overdueInstallAssigneeKey(
        managerNm: '고객담당',
        regUsr: '김경덕',
        ourNames: const ['김경덕', '박영업'],
      ),
      '김경덕',
    );
    expect(
      overdueInstallAssigneeKey(
        managerNm: '박영업',
        regUsr: '1850017',
        ourNames: const ['김경덕', '박영업'],
      ),
      '박영업',
    );
  });

  test('로그인 이름과 담당자 매칭', () {
    expect(overdueInstallIsMine('김경덕', '김경덕'), isTrue);
    expect(overdueInstallIsMine('김경덕', ' 김경덕 '), isTrue);
    expect(overdueInstallIsMine('김경덕', '홍길동'), isFalse);
    expect(overdueInstallIsMine('김경덕', null), isFalse);
  });

  test('일본지사는 제외 대상', () {
    expect(overdueInstallIsJapanPlant('2002'), isTrue);
    expect(overdueInstallIsJapanPlant('1000'), isFalse);
  });

  test('install_done 파싱', () {
    expect(overdueInstallParseDone(true), isTrue);
    expect(overdueInstallParseDone(1), isTrue);
    expect(overdueInstallParseDone(false), isFalse);
    expect(overdueInstallParseDone(0), isFalse);
  });

  test('수금 잔금 키를 raw에서 읽는다', () {
    expect(
      overdueInstallMoneyFromRaw(
        {'REMAIN_PAY_COST': '1,100,000'},
        const ['REMAIN_PAY_COST', 'remain_pay_cost'],
      ),
      1100000,
    );
  });

  test('발행요청 여부 필터', () {
    expect(
      overdueInstallMatchesRequestFilter(
        taxRequestCount: 0,
        filter: OverdueInstallRequestFilter.notRequested,
      ),
      isTrue,
    );
    expect(
      overdueInstallMatchesRequestFilter(
        taxRequestCount: 2,
        filter: OverdueInstallRequestFilter.requested,
      ),
      isTrue,
    );
    expect(overdueInstallRequestBadge(taxRequestCount: 0), '미요청');
    expect(overdueInstallRequestBadge(taxRequestCount: 2), '요청 2건');
  });

  test('세금계산서 초안은 잔금이면 잔금, 품목·지사를 채운다', () {
    const site = OverdueInstallSite(
      inqNo: 'SI260101001',
      instalDt: '2026-09-10',
      siteNm: '삼성현장',
      custNm: '삼성',
      plantCd: '1002',
      plantNm: '대구지사',
      itemCd: '스피드도어 SD',
      managerNm: '김경덕',
      regUsr: '김경덕',
      installDone: false,
      remainPay: 2200000,
      orderTotal: 5500000,
    );
    final prefill = site.toTaxPrefill();
    expect(prefill.customerName, '삼성현장');
    expect(prefill.totalAmount, 2200000);
    expect(prefill.itemType, '잔금');
    expect(prefill.itemName, '스피드도어');
    expect(prefill.branch, '대구');
    expect(prefill.mesRegistered, isTrue);
  });

  test('수주금액에서 공급가액·세액을 나눈다', () {
    expect(
      overdueInstallOrderPriceFromRaw({'ORDER_PRICE': '5,500,000'}),
      5500000,
    );
    expect(overdueInstallOrderPriceFromRaw('{"AMT":"1100000"}'), 1100000);
    final vat = overdueInstallVatSplit(5500000);
    expect(vat?.tax, 500000);
    expect(vat?.supply, 5000000);
    expect(overdueInstallVatSplit(null), isNull);
  });

  test('담당자 묶음은 나 먼저, 그다음 건수', () {
    final groups = overdueInstallGroupByAssignee(
      [
        ('홍길동', '2026-09-10'),
        ('김경덕', '2026-09-12'),
        ('홍길동', '2026-09-11'),
        ('박영업', '2026-09-09'),
        ('박영업', '2026-09-08'),
        ('박영업', '2026-09-07'),
      ],
      assigneeOf: (row) => row.$1,
      dateOf: (row) => row.$2,
      userName: '김경덕',
    );
    expect(groups.map((e) => e.$1).toList(), ['김경덕', '박영업', '홍길동']);
    expect(groups[1].$2.map((e) => e.$2).toList(), [
      '2026-09-07',
      '2026-09-08',
      '2026-09-09',
    ]);
  });

  test('R2 경로는 시공후·계약완료·체크시트로 나눈다', () {
    expect(
      overdueInstallArchiveKind(
        typeCode: 'TP3',
        stage: '',
        r2Key: 'data/sites/2024/02/13/광양/03_시공후사진/a.jpg',
        originalName: 'a.jpg',
      ),
      OverdueInstallArchiveKind.installAfter,
    );
    expect(
      overdueInstallArchiveKind(
        typeCode: 'TP4',
        stage: '',
        r2Key: 'data/sites/2024/02/13/광양/05_계약완료보고서/b.jpg',
        originalName: 'b.jpg',
      ),
      OverdueInstallArchiveKind.contract,
    );
    expect(
      overdueInstallArchiveKind(
        typeCode: '',
        stage: '05_계약완료보고서',
        r2Key: r'data\sites\2024\02\13\광양\05_계약완료보고서\b.jpg',
        originalName: 'b.jpg',
      ),
      OverdueInstallArchiveKind.contract,
    );
    expect(
      overdueInstallArchiveKind(
        typeCode: 'TP1',
        stage: '',
        r2Key: 'data/sites/2024/02/13/광양/04_체크시트/c.jpg',
        originalName: 'c.jpg',
      ),
      OverdueInstallArchiveKind.checksheet,
    );
    expect(
      overdueInstallArchiveKind(
        typeCode: 'TP2',
        stage: '',
        r2Key: 'data/sites/2024/02/13/광양/02_시공전사진/d.jpg',
        originalName: 'd.jpg',
      ),
      OverdueInstallArchiveKind.other,
    );
  });

  test('달력용 담당자 이름은 중복을 뺀다', () {
    expect(overdueInstallUniqueNames(['김경덕', '김경덕', '홍길동', '']), [
      '김경덕',
      '홍길동',
    ]);
  });

  test('월·주 범위', () {
    expect(overdueInstallInMonth('2026-09-10', DateTime(2026, 9, 18)), isTrue);
    expect(overdueInstallInMonth('2026-08-31', DateTime(2026, 9, 18)), isFalse);
    final wed = DateTime(2026, 9, 16);
    expect(overdueInstallYmd(overdueInstallMondayOf(wed)), '2026-09-14');
    expect(overdueInstallInWeek('2026-09-14', wed), isTrue);
    expect(overdueInstallInWeek('2026-09-20', wed), isTrue);
    expect(overdueInstallInWeek('2026-09-13', wed), isFalse);
  });
}
