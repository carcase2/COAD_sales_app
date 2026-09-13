import 'package:coad_customer_calls/core/utils/schedule_branch.dart';
import 'package:coad_customer_calls/core/utils/schedule_permissions.dart';
import 'package:coad_customer_calls/models/app_user.dart';
import 'package:flutter_test/flutter_test.dart';

AppUser _user({
  String? groupName,
  String role = 'user',
  String? title,
  String? branchName,
}) =>
    AppUser(
      id: '1',
      name: '테스트',
      role: role,
      permissions: const [],
      groupName: groupName,
      title: title,
      branchName: branchName,
    );

void main() {
  test('canAccessGeneralSchedule — 본사영업·관리자만 허용', () {
    expect(canAccessGeneralSchedule(_user(groupName: '본사영업')), isTrue);
    expect(canAccessGeneralSchedule(_user(groupName: '관리자')), isTrue);
    expect(canAccessGeneralSchedule(_user(groupName: ' 본사영업 ')), isTrue);
  });

  test('canAccessGeneralSchedule — 영업+본사 허용, 지사 영업 지사장은 거부', () {
    expect(
      canAccessGeneralSchedule(
        _user(groupName: '영업', title: '팀원', branchName: '본사'),
      ),
      isTrue,
    );
    expect(
      canAccessGeneralSchedule(
        _user(groupName: '영업', title: '지사장', branchName: '대구지사'),
      ),
      isFalse,
    );
    expect(
      canAccessGeneralSchedule(
        _user(groupName: '영업', title: '지사장', branchName: '대전지사'),
      ),
      isFalse,
    );
    expect(
      canAccessGeneralSchedule(_user(groupName: '영업', title: '팀원')),
      isFalse,
    );
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
    expect(canAccessGeneralSchedule(_user(groupName: '대구지사장')), isFalse);
  });

  test('canAccessDaeguSchedule — 대구지사장·관리자만 허용', () {
    expect(canAccessDaeguSchedule(_user(groupName: '대구지사장')), isTrue);
    expect(canAccessDaeguSchedule(_user(groupName: '관리자')), isTrue);
    expect(canAccessDaeguSchedule(_user(groupName: ' 대구지사장 ')), isTrue);
  });

  test('canAccessDaeguSchedule — 영업+대구+지사장 허용', () {
    expect(
      canAccessDaeguSchedule(
        _user(groupName: '영업', title: '지사장', branchName: '대구지사'),
      ),
      isTrue,
    );
    expect(
      canAccessDaeguSchedule(
        _user(groupName: '영업', title: '지사장', branchName: '대구'),
      ),
      isTrue,
    );
    expect(
      canAccessDaeguSchedule(
        _user(groupName: '영업', title: '팀원', branchName: '대구지사'),
      ),
      isFalse,
    );
    expect(
      canAccessDaeguSchedule(
        _user(groupName: '영업', title: '지사장', branchName: '본사'),
      ),
      isFalse,
    );
  });

  test('canAccessDaeguSchedule — 그 외 그룹 거부', () {
    expect(canAccessDaeguSchedule(_user(groupName: '본사영업')), isFalse);
    expect(canAccessDaeguSchedule(_user(groupName: '대구지사')), isFalse);
    expect(canAccessDaeguSchedule(_user(groupName: null)), isFalse);
    expect(
      canAccessDaeguSchedule(
        AppUser(
          id: '1',
          name: 'x',
          role: 'admin',
          permissions: const ['daegu_schedule', 'all'],
          groupName: '영업1팀',
        ),
      ),
      isFalse,
    );
  });

  test('ScheduleBranch titles and tables', () {
    expect(ScheduleBranch.headOffice.title, '본사일반');
    expect(ScheduleBranch.daegu.title, '대구지사');
    expect(ScheduleBranch.headOffice.scheduleTable, 'sales_schedule');
    expect(ScheduleBranch.daegu.scheduleTable, 'sales_schedule_daegu');
    expect(ScheduleBranch.daegu.slotsTable, 'schedule_slots_daegu');
  });
}
