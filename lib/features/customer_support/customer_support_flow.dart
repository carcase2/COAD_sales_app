/// AS 허브에서 이어지는 업무 단계. 데이터 연동 전 화면 골격용.
enum SupportFlowStep {
  siteSearch,
  intake,
  receptionList,
  quote,
  completion,
  collection,
  tax,
  faq,
}

class SupportSiteSample {
  const SupportSiteSample({
    required this.id,
    required this.name,
    required this.address,
    required this.phone,
    required this.assignee,
    required this.revisitCount,
    required this.installCompletedYmd,
    required this.addresses,
    required this.history,
    required this.quotes,
    required this.hasBusinessLicense,
    required this.hasChecksheet,
  });

  final String id;
  final String name;
  final String address;
  final String phone;
  final String assignee;
  final int revisitCount;
  final String? installCompletedYmd;
  final List<String> addresses;
  final List<String> history;
  final List<String> quotes;
  final bool hasBusinessLicense;
  final bool hasChecksheet;
}

/// 흐름 확인용 샘플. 실데이터 연동 시 제거.
const kSupportSampleSites = <SupportSiteSample>[
  SupportSiteSample(
    id: 's1',
    name: '강남 코아드빌딩',
    address: '서울 강남구 테헤란로 12',
    phone: '02-1234-5678',
    assignee: '김지원',
    revisitCount: 3,
    installCompletedYmd: '2025-03-12',
    addresses: ['서울 강남구 테헤란로 12', '서울 강남구 역삼로 88 지하 하역'],
    history: [
      '2026-07-02 모터 소음 A/S · 완료',
      '2026-04-18 센서 오작동 · 완료',
      '2025-11-03 초기 설치 점검 · 완료',
    ],
    quotes: ['2026-04-20 센서 교체 견적', '2025-10-28 슬라트 교체 견적'],
    hasBusinessLicense: true,
    hasChecksheet: true,
  ),
  SupportSiteSample(
    id: 's2',
    name: '수성 한빛아파트 지하',
    address: '대구 수성구 달구벌대로 2400',
    phone: '053-987-6543',
    assignee: '박현장',
    revisitCount: 1,
    installCompletedYmd: '2026-01-20',
    addresses: ['대구 수성구 달구벌대로 2400'],
    history: ['2026-06-11 리모컨 불량 · 진행중'],
    quotes: ['2026-06-11 리모컨·수신기 견적'],
    hasBusinessLicense: false,
    hasChecksheet: true,
  ),
  SupportSiteSample(
    id: 's3',
    name: '인천 송도 물류센터',
    address: '인천 연수구 송도과학로 32',
    phone: '032-555-0101',
    assignee: '이기술',
    revisitCount: 0,
    installCompletedYmd: null,
    addresses: ['인천 연수구 송도과학로 32'],
    history: ['2026-08-15 신규 접수 · 방문 전'],
    quotes: [],
    hasBusinessLicense: true,
    hasChecksheet: false,
  ),
];
