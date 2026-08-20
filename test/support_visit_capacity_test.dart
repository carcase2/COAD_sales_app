import 'package:coad_customer_calls/core/utils/support_visit_capacity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('본사는 본사 팀 수, 지사는 지사 팀 수', () {
    expect(
      supportVisitDayCapacity(branch: '본사', hqTeams: 2, branchTeams: 1),
      2,
    );
    expect(
      supportVisitDayCapacity(branch: '대구', hqTeams: 2, branchTeams: 1),
      1,
    );
    expect(
      supportVisitDayCapacity(branch: '전남', hqTeams: 3, branchTeams: 2),
      2,
    );
  });

  test('예약이 팀 수보다 적으면 가능', () {
    expect(supportVisitDayOpen(booked: 0, capacity: 2), isTrue);
    expect(supportVisitDayOpen(booked: 1, capacity: 2), isTrue);
    expect(supportVisitDayOpen(booked: 2, capacity: 2), isFalse);
    expect(supportVisitDayOpen(booked: 1, capacity: 1), isFalse);
  });

  test('가장 빠른 가능일을 고른다', () {
    expect(
      earliestOpenVisitYmd(
        fromYmd: '2026-08-20',
        bookedByYmd: const {'2026-08-20': 2, '2026-08-21': 2, '2026-08-22': 1},
        capacity: 2,
      ),
      '2026-08-22',
    );
    expect(
      earliestOpenVisitYmd(
        fromYmd: '2026-08-20',
        bookedByYmd: const {},
        capacity: 1,
      ),
      '2026-08-20',
    );
  });
}
