import 'package:coad_customer_calls/models/app_user.dart';

/// REST `issue_request.user_id`(bigint)용 숫자 ID 해석.
int? resolveIssueRequestUserId(AppUser? user) {
  final loginId = user?.id.trim() ?? '';
  if (loginId.isEmpty) return null;
  return int.tryParse(loginId);
}
