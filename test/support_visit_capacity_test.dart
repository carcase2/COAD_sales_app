import 'package:coad_customer_calls/core/utils/support_visit_capacity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('시간 정규화', () {
    expect(normalizeSupportVisitTime('09:00:00'), '09:00');
    expect(normalizeSupportVisitTime('14:00'), '14:00');
    expect(normalizeSupportVisitTime(''), '');
  });

  test('같은 팀·같은 시간만 막힘', () {
    const day = SupportVisitDayBookings(
      timesByTeamId: {
        'a': {'09:00', '11:00'},
      },
      totalCount: 2,
    );
    expect(
      supportVisitTeamTimeFree(teamId: 'a', time: '09:00', bookings: day),
      isFalse,
    );
    expect(
      supportVisitTeamTimeFree(teamId: 'a', time: '10:00', bookings: day),
      isTrue,
    );
    expect(
      supportVisitTeamTimeFree(teamId: 'b', time: '09:00', bookings: day),
      isTrue,
    );
    expect(
      supportVisitFreeTimesForTeam(teamId: 'a', bookings: day),
      isNot(contains('09:00')),
    );
    expect(
      supportVisitFreeTimesForTeam(teamId: 'a', bookings: day),
      contains('10:00'),
    );
  });

  test('본인 현재 슬롯은 선택 가능·표시는 잡힌 상태', () {
    const day = SupportVisitDayBookings(
      timesByTeamId: {
        'a': {'09:00'},
      },
      totalCount: 1,
    );
    expect(
      supportVisitSlotBlockedForPick(
        bookings: day,
        ymd: '2026-09-10',
        teamId: 'a',
        time: '09:00',
        ownVisitDate: '2026-09-10',
        ownVisitTeamId: 'a',
        ownVisitTime: '09:00',
      ),
      isFalse,
    );
    expect(
      supportVisitSlotBlockedForPick(
        bookings: day,
        ymd: '2026-09-10',
        teamId: 'a',
        time: '09:00',
        ownVisitDate: '2026-09-10',
        ownVisitTeamId: 'a',
        ownVisitTime: '11:00',
      ),
      isTrue,
    );
    expect(
      supportVisitFreeTimesForTeam(
        teamId: 'a',
        bookings: day,
        ymd: '2026-09-10',
        ownVisitDate: '2026-09-10',
        ownVisitTeamId: 'a',
        ownVisitTime: '09:00',
      ),
      contains('09:00'),
    );
  });

  test('날짜 선택: 남는 시간이 있으면 가능', () {
    expect(
      supportVisitDaySelectable(
        bookings: const SupportVisitDayBookings(
          timesByTeamId: {
            'a': {'09:00'},
          },
          totalCount: 1,
        ),
        activeTeamCount: 1,
        activeTeamIds: const ['a'],
      ),
      isTrue,
    );
    expect(
      supportVisitDaySelectable(
        bookings: SupportVisitDayBookings(
          timesByTeamId: {
            'a': {...kSupportVisitTimeSlots},
          },
          totalCount: kSupportVisitTimeSlots.length,
        ),
        activeTeamCount: 1,
        activeTeamIds: const ['a'],
      ),
      isFalse,
    );
  });

  test('가장 빠른 가능일', () {
    expect(
      earliestOpenVisitYmdWithTeams(
        fromYmd: '2026-08-20',
        bookingsByYmd: {
          '2026-08-20': SupportVisitDayBookings(
            timesByTeamId: {
              'a': {...kSupportVisitTimeSlots},
              'b': {...kSupportVisitTimeSlots},
            },
            totalCount: kSupportVisitTimeSlots.length * 2,
          ),
          '2026-08-21': const SupportVisitDayBookings(
            timesByTeamId: {
              'a': {'09:00'},
            },
            totalCount: 1,
          ),
        },
        activeTeamCount: 2,
        activeTeamIds: const ['a', 'b'],
      ),
      '2026-08-21',
    );
  });

  test('legacy 용량', () {
    expect(supportVisitCapacityFromTeams(2), 2);
    expect(supportVisitDaySlotCapacity(2), 18);
    expect(
      supportVisitDayCapacity(branch: '본사', hqTeams: 2, branchTeams: 1),
      2,
    );
  });
}
