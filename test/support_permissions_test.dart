import 'package:coad_customer_calls/core/utils/support_permissions.dart';
import 'package:coad_customer_calls/models/app_user.dart';
import 'package:flutter_test/flutter_test.dart';

AppUser _user({
  String role = 'user',
  String? groupName,
  List<String> permissions = const [],
}) => AppUser(
  id: '1',
  name: '테스트',
  role: role,
  permissions: permissions,
  groupName: groupName,
);

void main() {
  test('canAccessCustomerSupport — 관리자·support 권한·고객지원 그룹', () {
    expect(canAccessCustomerSupport(_user(role: 'admin')), isTrue);
    expect(canAccessCustomerSupport(_user(groupName: '관리자')), isTrue);
    expect(canAccessCustomerSupport(_user(permissions: ['all'])), isTrue);
    expect(canAccessCustomerSupport(_user(permissions: ['support'])), isTrue);
    expect(canAccessCustomerSupport(_user(groupName: '고객지원')), isTrue);
    expect(canAccessCustomerSupport(_user(groupName: '고객지원팀')), isTrue);
    expect(canAccessCustomerSupport(_user(groupName: ' 고객지원팀 ')), isTrue);
  });

  test('canAccessCustomerSupport — 그 외 거부', () {
    expect(canAccessCustomerSupport(null), isFalse);
    expect(canAccessCustomerSupport(_user()), isFalse);
    expect(canAccessCustomerSupport(_user(groupName: '본사영업')), isFalse);
    expect(
      canAccessCustomerSupport(_user(permissions: ['sales_calls'])),
      isFalse,
    );
    expect(canAccessCustomerSupport(_user(groupName: '대구지사장')), isFalse);
  });
}
