import 'package:coad_customer_calls/data/support_as_visit_team_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('팀원 문자열 파싱·포맷', () {
    expect(parseSupportVisitTeamMembers('김철수, 이영희'), ['김철수', '이영희']);
    expect(parseSupportVisitTeamMembers('김철수·이영희'), ['김철수', '이영희']);
    expect(
      formatSupportVisitTeamMembers(['이영희', '김철수', '이영희', '']),
      '이영희, 김철수',
    );
  });
}
