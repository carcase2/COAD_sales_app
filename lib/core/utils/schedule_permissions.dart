import 'package:coad_customer_calls/core/utils/schedule_branch.dart';
import 'package:coad_customer_calls/models/app_user.dart';

/// 본사일반 메뉴 — 본사영업·관리자, 또는 영업+본사.
const kGeneralScheduleAllowedGroupNames = ['본사영업', '관리자'];

/// 대구지사 일정 메뉴 — 대구지사장·관리자, 또는 영업+대구+지사장.
const kDaeguScheduleAllowedGroupNames = ['대구지사장', '관리자'];

/// 본사일반 화면·메뉴에 표시하는 테스트 안내.
/// 본사일반 베타 표시(하단 탭 등). 빈 문자열이면 배지 숨김.
const kGeneralScheduleTestLabel = '';

/// 대구지사 베타 표시. 빈 문자열이면 배지 숨김.
const kDaeguScheduleTestLabel = '';

bool canAccessGeneralSchedule(AppUser user) =>
    ScheduleBranch.headOffice.canAccess(user);

bool canAccessDaeguSchedule(AppUser user) =>
    ScheduleBranch.daegu.canAccess(user);

bool canAccessScheduleBranch(AppUser user, ScheduleBranch branch) =>
    branch.canAccess(user);
