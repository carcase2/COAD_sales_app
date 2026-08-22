import 'package:coad_customer_calls/core/utils/mail_permissions.dart';
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
  test('canAccessMail — 관리자·mail·all', () {
    expect(canAccessMail(_user(role: 'admin')), isTrue);
    expect(canAccessMail(_user(groupName: '관리자')), isTrue);
    expect(canAccessMail(_user(permissions: ['all'])), isTrue);
    expect(canAccessMail(_user(permissions: ['mail'])), isTrue);
  });

  test('canAccessMail — 그 외 거부', () {
    expect(canAccessMail(null), isFalse);
    expect(canAccessMail(_user()), isFalse);
    expect(canAccessMail(_user(permissions: ['sales_calls'])), isFalse);
    expect(canAccessMail(_user(groupName: '본사영업')), isFalse);
  });

  test('groupHasMailPermission', () {
    expect(groupHasMailPermission(['mail']), isTrue);
    expect(groupHasMailPermission(['all', 'estimator']), isTrue);
    expect(groupHasMailPermission(['sales_calls']), isFalse);
    expect(groupHasMailPermission(const []), isFalse);
  });
}
