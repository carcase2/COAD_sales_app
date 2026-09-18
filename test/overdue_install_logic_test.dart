import 'package:coad_customer_calls/features/issuance/overdue_install_logic.dart';
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
