// 고수 홈페이지 문의(gosu_sites) 규칙. coad-gosu-followup `lib/stages.ts`·`lib/region.ts` 와 같게 유지한다.
//
// 흐름: 접수중 → (고수에 방문날짜 입력) 접수완료 / 통화 후 취소 → 접수취소(고수 값 "취소")
// 앱은 접수중 건의 1차·2차… 통화 기록과 접수취소 사유만 남긴다. 고수 사이트에는 쓰지 않는다.

import 'package:coad_customer_calls/models/gosu_site.dart';

const String kGosuSiteReceiving = '접수중';
const String kGosuSiteAccepted = '접수완료';
const String kGosuSiteCanceled = '취소';
const String kGosuSiteCancelStage = '접수취소';

const List<String> kGosuSiteCallResults = [
  '방문일 확정',
  '재통화 약속',
  '취소',
  '부재중',
  '문자/카톡 남김',
];
const Set<String> kGosuSiteConnectedResults = {'방문일 확정', '재통화 약속', '취소'};
const String kGosuSiteVisitConfirmed = '방문일 확정';
const String kGosuSiteCallCancel = '취소';
const String kGosuSiteVisitPrefix = '방문 예정 ';

const List<String> kGosuSiteCancelReasons = [
  '가격 부담',
  '타사 계약/비교',
  '단순 문의·정보 수집',
  '연락 두절',
  '일정 안 맞음',
  '설치 불가 현장',
  '고객 사정(보류)',
  '중복 접수',
  '기타',
];

/// 고수 작업자 화면의 이 문의 (로그인돼 있으면 바로 열린다)
String gosuSiteWorkerUrl(String? estimateId) => estimateId == null
    ? 'https://www.coadmaster.com/login?type=worker'
    : 'https://www.coadmaster.com/mypage/onsite-estimates/$estimateId';

String gosuSiteStatusLabel(String s) =>
    s == kGosuSiteCanceled ? '접수취소' : (s.isEmpty ? '-' : s);

/// 팔로업 result 예: "2차 통화 · 부재중"
String gosuSiteCallResultText(int round, String r) => '$round차 통화 · $r';

class GosuSiteCall {
  const GosuSiteCall(this.round, this.outcome, this.connected);
  final int round;
  final String outcome;
  final bool connected;
}

const Map<String, String> _legacy = {
  '연결·방문일 확정': '방문일 확정',
  '연결·재통화 약속': '재통화 약속',
  '연결·고객 검토중': '재통화 약속',
  '연결·취소 의사': '취소',
};

final RegExp _callRe = RegExp(r'^(\d+)차 통화 · (.+)$');

GosuSiteCall? parseGosuSiteCall(String result) {
  final m = _callRe.firstMatch(result);
  if (m == null) return null;
  final raw = m.group(2)!;
  final outcome = _legacy[raw] ?? raw;
  return GosuSiteCall(
    int.parse(m.group(1)!),
    outcome,
    kGosuSiteConnectedResults.contains(outcome) || raw.startsWith('연결'),
  );
}

/// 다음에 기록할 통화 차수 (1부터)
int nextGosuSiteRound(Iterable<GosuSiteFollowup> followups) {
  var max = 0;
  for (final f in followups) {
    final c = parseGosuSiteCall(f.result);
    if (c != null && c.round > max) max = c.round;
  }
  return max + 1;
}

const Duration _h24 = Duration(hours: 24);

/// 접수중 건이 늦어진 이유. 없으면 null.
String? gosuSiteStaleReason(GosuSite s, {DateTime? now}) {
  if (s.workerStatus != kGosuSiteReceiving) return null;
  final t = (now ?? DateTime.now()).toUtc();
  final last = s.lastFollowupAt;
  if (last == null) {
    return t.difference(s.receivedAt) > _h24
        ? '접수 후 24시간 넘게 1차 통화 기록 없음'
        : null;
  }
  final call = s.lastResult == null ? null : parseGosuSiteCall(s.lastResult!);
  final since = t.difference(last);

  if (call?.outcome == kGosuSiteVisitConfirmed && since > _h24) {
    return '방문일 확정했는데 고수에 주소·방문일 미등록(접수중 그대로)';
  }
  if (call?.outcome == kGosuSiteCallCancel && since > _h24) {
    return '통화에서 취소 — 고수에서 접수취소 처리 필요';
  }
  final next = s.lastNextActionAt;
  if (next != null && next.length >= 10) {
    // 예정일 한국시간 23:59:59 를 넘기면 지연
    final due = DateTime.parse('${next.substring(0, 10)}T23:59:59+09:00');
    if (t.isAfter(due)) {
      return '${call != null ? '${call.round + 1}차 ' : ''}통화 예정일(${next.substring(0, 10)}) 지남';
    }
    return null;
  }
  if (call != null && !call.connected) {
    return since > _h24
        ? '${call.round}차 통화 ${call.outcome} 후 24시간 넘게 재통화 없음'
        : null;
  }
  if (call?.outcome == kGosuSiteCallCancel ||
      call?.outcome == kGosuSiteVisitConfirmed) {
    return null;
  }
  return since > const Duration(hours: 72) ? '3일간 통화 기록 없음' : null;
}

const Map<String, String> _sido = {
  '서울특별시': '서울',
  '부산광역시': '부산',
  '대구광역시': '대구',
  '인천광역시': '인천',
  '광주광역시': '광주',
  '대전광역시': '대전',
  '울산광역시': '울산',
  '세종특별자치시': '세종',
  '경기도': '경기',
  '강원도': '강원',
  '강원특별자치도': '강원',
  '충청북도': '충북',
  '충청남도': '충남',
  '전라북도': '전북',
  '전북특별자치도': '전북',
  '전라남도': '전남',
  '경상북도': '경북',
  '경상남도': '경남',
  '제주도': '제주',
  '제주특별자치도': '제주',
};

/// 목록 표시용 지역 (예: "경기 수원시"). 고수 area 가 대부분 비어 있어 주소 앞부분으로 구한다.
String gosuSiteRegion(GosuSite s) {
  final parts = (s.area ?? s.address ?? '')
      .trim()
      .split(RegExp(r'\s+'))
      .where((e) => e.isNotEmpty)
      .toList();
  if (parts.isEmpty) return '-';
  return [
    _sido[parts[0]] ?? parts[0],
    if (parts.length > 1) parts[1],
  ].join(' ');
}

/// 대응 기준 묶음. 접수중 = 아직 통화로 방문일을 못 잡음(대응 필요),
/// 접수완료 = 고수에 방문일 입력 이후 단계 전부(체크시트·견적·계약 포함), 취소 = 접수취소.
enum GosuSiteBucket { receiving, accepted, canceled }

GosuSiteBucket gosuSiteBucket(GosuSite s) => switch (s.workerStatus) {
  kGosuSiteReceiving => GosuSiteBucket.receiving,
  kGosuSiteCanceled => GosuSiteBucket.canceled,
  _ => GosuSiteBucket.accepted,
};

String gosuSiteBucketLabel(GosuSiteBucket b) => switch (b) {
  GosuSiteBucket.receiving => '접수중',
  GosuSiteBucket.accepted => '접수완료',
  GosuSiteBucket.canceled => '접수취소',
};

/// 접수중 → 접수완료 → 취소 순, 같은 묶음은 최근 접수가 위.
List<GosuSite> sortGosuSitesForResponse(Iterable<GosuSite> sites) {
  final list = sites.toList();
  list.sort((a, b) {
    final c = gosuSiteBucket(a).index.compareTo(gosuSiteBucket(b).index);
    return c != 0 ? c : b.receivedAt.compareTo(a.receivedAt);
  });
  return list;
}
