import 'package:coad_customer_calls/models/app_user.dart';

/// 본사일반 / 대구지사 일정 — 동일 UI·로직, 테이블·권한만 다름.
enum ScheduleBranch {
  /// 본사일반 (`sales_schedule` / `schedule_slots`)
  headOffice,

  /// 대구지사 (`sales_schedule_daegu` / `schedule_slots_daegu`)
  daegu,
}

extension ScheduleBranchX on ScheduleBranch {
  String get title => switch (this) {
        ScheduleBranch.headOffice => '본사일반',
        ScheduleBranch.daegu => '대구지사',
      };

  String get scheduleTable => switch (this) {
        ScheduleBranch.headOffice => 'sales_schedule',
        ScheduleBranch.daegu => 'sales_schedule_daegu',
      };

  String get slotsTable => switch (this) {
        ScheduleBranch.headOffice => 'schedule_slots',
        ScheduleBranch.daegu => 'schedule_slots_daegu',
      };

  /// 알림·통계용 sourceTab (COAD_home 과 동일).
  String get sourceTab => switch (this) {
        ScheduleBranch.headOffice => 'general_schedule',
        ScheduleBranch.daegu => 'daegu_schedule',
      };

  /// 앱 사용량 집계 키.
  String get usageTabKey => switch (this) {
        ScheduleBranch.headOffice => 'general_schedule',
        ScheduleBranch.daegu => 'daegu_schedule',
      };

  /// 메뉴·탭 표시 허용 그룹.
  List<String> get allowedGroupNames => switch (this) {
        ScheduleBranch.headOffice => const ['본사영업', '관리자'],
        ScheduleBranch.daegu => const ['대구지사장', '관리자'],
      };

  String get accessDeniedMessage => switch (this) {
        ScheduleBranch.headOffice =>
          '본사일반은 본사 영업·관리자만 이용할 수 있습니다.',
        ScheduleBranch.daegu =>
          '대구지사 일정은 대구지사장·관리자, 또는 영업 대구 지사장만 이용할 수 있습니다.',
      };

  /// FCM Edge Function 이름. null 이면 푸시 생략.
  String? get notifyFunctionName => switch (this) {
        ScheduleBranch.headOffice => 'notify-general-schedule',
        ScheduleBranch.daegu => 'notify-daegu-schedule',
      };

  /// FCM data type / action (탭 시 화면 이동).
  String get fcmType => switch (this) {
        ScheduleBranch.headOffice => 'general_schedule',
        ScheduleBranch.daegu => 'daegu_schedule',
      };

  String get fcmOpenAction => switch (this) {
        ScheduleBranch.headOffice => 'open_general_schedule',
        ScheduleBranch.daegu => 'open_daegu_schedule',
      };

  /// `models` JSON 컬럼 지원 여부.
  /// 대구지사 테이블에는 아직 models 컬럼이 없어 door_types·model_name 만 사용.
  bool get supportsModels => switch (this) {
        ScheduleBranch.headOffice => true,
        ScheduleBranch.daegu => false,
      };

  bool canAccess(AppUser user) {
    if (this == ScheduleBranch.headOffice && user.isHqSales) {
      return true;
    }
    if (this == ScheduleBranch.daegu && user.isSalesDaeguBranchManager) {
      return true;
    }
    final group = user.groupName?.trim();
    if (group == null || group.isEmpty) return false;
    return allowedGroupNames.contains(group);
  }
}
