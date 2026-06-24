import 'package:coad_customer_calls/core/utils/schedule_permissions.dart';
import 'package:coad_customer_calls/models/app_user.dart';
import 'package:flutter_test/flutter_test.dart';

AppUser _user({String? groupName, String role = 'user'}) => AppUser(
      id: '1',
      name: '테스트',
      role: role,
      permissions: const [],
      groupName: groupName,
    );

void main() {
  test('canAccessGeneralSchedule — 본사영업·관리자만 허용', () {
    expect(canAccessGeneralSchedule(_user(groupName: '본사영업')), isTrue);
    expect(canAccessGeneralSchedule(_user(groupName: '관리자')), isTrue);
    expect(canAccessGeneralSchedule(_user(groupName: ' 본사영업 ')), isTrue);
  });

  test('canAccessGeneralSchedule — 그 외 그룹·권한 거부', () {
    expect(canAccessGeneralSchedule(_user(groupName: '지점영업')), isFalse);
    expect(canAccessGeneralSchedule(_user(groupName: null)), isFalse);
    expect(canAccessGeneralSchedule(_user()), isFalse);
    expect(
      canAccessGeneralSchedule(
        _user(groupName: '본사영업', role: 'admin'),
      ),
      isTrue,
    );
    expect(
      canAccessGeneralSchedule(
        AppUser(
          id: '1',
          name: 'x',
          role: 'admin',
          permissions: const ['main', 'all'],
          groupName: '영업1팀',
        ),
      ),
      isFalse,
    );
  });
}