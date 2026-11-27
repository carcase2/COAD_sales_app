import 'package:coad_customer_calls/core/utils/gosu_site_rules.dart';
import 'package:coad_customer_calls/models/gosu_site.dart';
import 'package:flutter_test/flutter_test.dart';

GosuSite site({
  String status = kGosuSiteReceiving,
  required DateTime received,
  DateTime? lastAt,
  String? lastResult,
  String? nextAt,
  String? address,
}) => GosuSite(
  gosuId: 'g1',
  receivedAt: received,
  workerStatus: status,
  lastFollowupAt: lastAt,
  lastResult: lastResult,
  lastNextActionAt: nextAt,
  address: address,
);

GosuSiteFollowup f(String result) => GosuSiteFollowup(
  id: result,
  gosuId: 'g1',
  stage: kGosuSiteReceiving,
  result: result,
  author: 'a',
  createdAt: DateTime.utc(2026, 11, 26),
);

void main() {
  final now = DateTime.utc(2026, 11, 26, 3); // 11/26 12:00 KST

  test('parse call result and legacy labels', () {
    final c = parseGosuSiteCall('2차 통화 · 부재중')!;
    expect(c.round, 2);
    expect(c.outcome, '부재중');
    expect(c.connected, isFalse);
    final legacy = parseGosuSiteCall('1차 통화 · 연결·고객 검토중')!;
    expect(legacy.outcome, '재통화 약속');
    expect(legacy.connected, isTrue);
    expect(parseGosuSiteCall('가격 부담'), isNull);
  });

  test('next round counts only call records', () {
    expect(nextGosuSiteRound([]), 1);
    expect(
      nextGosuSiteRound([f('1차 통화 · 부재중'), f('2차 통화 · 재통화 약속'), f('기타')]),
      3,
    );
  });

  group('stale reason', () {
    test('no call within 24h is fine, after 24h is stale', () {
      expect(
        gosuSiteStaleReason(
          site(received: now.subtract(const Duration(hours: 5))),
          now: now,
        ),
        isNull,
      );
      expect(
        gosuSiteStaleReason(
          site(received: now.subtract(const Duration(hours: 30))),
          now: now,
        ),
        '접수 후 24시간 넘게 1차 통화 기록 없음',
      );
    });

    test('overdue next call date', () {
      final s = site(
        received: now.subtract(const Duration(days: 5)),
        lastAt: now.subtract(const Duration(days: 3)),
        lastResult: '1차 통화 · 재통화 약속',
        nextAt: '2026-11-25',
      );
      expect(gosuSiteStaleReason(s, now: now), '2차 통화 예정일(2026-11-25) 지남');
      final ok = site(
        received: now.subtract(const Duration(days: 5)),
        lastAt: now.subtract(const Duration(days: 3)),
        lastResult: '1차 통화 · 재통화 약속',
        nextAt: '2026-11-26', // 오늘 — 아직 아님
      );
      expect(gosuSiteStaleReason(ok, now: now), isNull);
    });

    test('visit confirmed but still 접수중 after a day', () {
      final s = site(
        received: now.subtract(const Duration(days: 3)),
        lastAt: now.subtract(const Duration(hours: 30)),
        lastResult: '1차 통화 · 방문일 확정',
        nextAt: '2026-11-30',
      );
      expect(gosuSiteStaleReason(s, now: now), contains('고수에 주소·방문일 미등록'));
    });

    test('non-receiving status is never stale', () {
      expect(
        gosuSiteStaleReason(
          site(
            status: kGosuSiteCanceled,
            received: now.subtract(const Duration(days: 9)),
          ),
          now: now,
        ),
        isNull,
      );
    });
  });

  test('region from address', () {
    expect(
      gosuSiteRegion(
        site(received: now, address: '경기도 수원시 영통구 광교로 1'),
      ),
      '경기 수원시',
    );
    expect(gosuSiteRegion(site(received: now)), '-');
  });

  test('response order: 접수중 → 접수완료(이후 단계 포함) → 취소, 최신 먼저', () {
    GosuSite at(String id, String status, int hour) => GosuSite(
      gosuId: id,
      receivedAt: DateTime.utc(2026, 11, 26, hour),
      workerStatus: status,
    );
    final sorted = sortGosuSitesForResponse([
      at('a', '접수완료', 5),
      at('b', kGosuSiteCanceled, 6),
      at('c', kGosuSiteReceiving, 1),
      at('d', '체크시트 미제출', 4),
      at('e', kGosuSiteReceiving, 3),
    ]);
    expect(sorted.map((s) => s.gosuId), ['e', 'c', 'a', 'd', 'b']);
    expect(gosuSiteBucket(at('x', '계약대기', 1)), GosuSiteBucket.accepted);
  });
}
