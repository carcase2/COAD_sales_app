import 'package:coad_customer_calls/features/home/home_dept.dart';
import 'package:coad_customer_calls/features/customer_support/reception_kind_sheet.dart';
import 'package:coad_customer_calls/models/app_user.dart';
import 'package:flutter_test/flutter_test.dart';

AppUser _user({String? groupName}) => AppUser(
  id: '1',
  name: '테스트',
  role: 'user',
  permissions: const [],
  groupName: groupName,
);

void main() {
  test('자동문의고수 부서는 고수 홈부터', () {
    expect(homeDeptPageIndexForUser(_user(groupName: '자동문의고수')), 2);
  });

  test('고객지원 부서는 고객지원팀 홈부터', () {
    expect(homeDeptPageIndexForUser(_user(groupName: '고객지원')), 1);
    expect(homeDeptPageIndexForUser(_user(groupName: '고객지원팀')), 1);
  });

  test('그 외 부서는 영업부 홈부터', () {
    expect(homeDeptPageIndexForUser(_user(groupName: '영업부')), 0);
    expect(homeDeptPageIndexForUser(_user(groupName: '본사영업')), 0);
    expect(homeDeptPageIndexForUser(null), 0);
  });

  test('홈 부서 페이지는 접수 탭과 같다', () {
    expect(receptionKindForHomeDeptPage(0), ReceptionKind.sales);
    expect(receptionKindForHomeDeptPage(1), ReceptionKind.afterSales);
    expect(receptionKindForHomeDeptPage(2), ReceptionKind.gosu);
    expect(receptionKindForHomeDeptPage(-1), ReceptionKind.sales);
  });
}
