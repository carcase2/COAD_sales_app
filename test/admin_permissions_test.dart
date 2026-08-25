import 'package:coad_customer_calls/core/utils/admin_permissions.dart';
import 'package:coad_customer_calls/models/app_user.dart';
import 'package:flutter_test/flutter_test.dart';

AppUser _user({
  String role = 'user',
  String? groupName,
  List<String> permissions = const [],
}) =>
    AppUser(
      id: '1',
      name: '테스트',
      role: role,
      permissions: permissions,
      groupName: groupName,
    );

void main() {
  test('isAppAdmin — role admin', () {
    expect(isAppAdmin(_user(role: 'admin')), isTrue);
    expect(isAppAdmin(_user(role: 'Admin')), isTrue);
  });

  test('isAppAdmin — 관리자 그룹', () {
    expect(isAppAdmin(_user(groupName: '관리자')), isTrue);
  });

  test('isAppAdmin — all 권한', () {
    expect(isAppAdmin(_user(permissions: ['all'])), isTrue);
  });

  test('isAppAdmin — 일반 사용자', () {
    expect(isAppAdmin(_user()), isFalse);
    expect(isAppAdmin(_user(groupName: '본사영업')), isFalse);
    expect(isAppAdmin(null), isFalse);
  });

  test('isAdminGroup — 관리자 그룹만', () {
    expect(isAdminGroup(_user(groupName: '관리자')), isTrue);
    expect(isAdminGroup(_user(role: 'admin')), isFalse);
    expect(isAdminGroup(_user(permissions: ['all'])), isFalse);
    expect(isAdminGroup(_user(groupName: '본사영업')), isFalse);
    expect(isAdminGroup(null), isFalse);
  });
}
