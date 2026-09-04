import 'package:coad_customer_calls/core/constants/gosu_appsheet.dart';
import 'package:coad_customer_calls/models/app_user.dart';

/// 홈 흐름 부서 페이지: 0 영업부, 1 고객지원팀, 2 자동문의고수.
const int kHomeDeptSales = 0;
const int kHomeDeptCustomerSupport = 1;
const int kHomeDeptGosu = 2;

int homeDeptPageIndexForUser(AppUser? user) {
  final group = user?.groupName?.trim() ?? '';
  if (group == kGosuGroupName) return kHomeDeptGosu;
  if (group == '고객지원' || group == '고객지원팀') return kHomeDeptCustomerSupport;
  return kHomeDeptSales;
}
