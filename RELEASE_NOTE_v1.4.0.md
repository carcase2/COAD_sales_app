# 출시명

**COAD Customer Calls v1.4.0 - 발급요청 고도화 & 홈/상담 UX 개선**

## 출시 노트

### 주요 개선 사항
- 신규 `발급요청` 탭을 추가하고, 세금계산서/이행증권 대기 건을 도메인별로 조회할 수 있도록 구현했습니다.
- `발행요청` 등록 플로우를 추가해 세금계산서와 이행증권을 앱에서 직접 등록/업로드할 수 있도록 확장했습니다.
- 발급요청 UI를 전면 개선해 카드 가독성, 배지 표현, 색상 일관성을 강화하고 overflow 이슈를 수정했습니다.
- 발행요청 등록 화면을 카드형 섹션 구조로 재정리하고, 입력창 인지성(테두리/포커스/가이드 문구)을 향상했습니다.
- 금액 입력란(세금 총액/이행 계약금액)에 세 자리 구분(천 단위 콤마) 자동 포맷을 적용했습니다.
- 세금 `항목 구분`과 이행 `증권 종류`를 버튼형 선택 UI로 변경해 선택성과 시인성을 높였습니다.
- 홈 화면 `금일 접수/금일 미통화` 진입 동선을 직접 목록 화면으로 개선하고, 목록 타이틀/캐시 필터 동작을 정합화했습니다.
- 통화 상세 화면에 `작성자` 정보를 추가해 이력 확인 편의성을 강화했습니다.

### 사용자 체감 효과
- 발급 대기 건 파악 및 등록 속도 향상
- 입력 실수 감소(폼 가독성/선택 UI 개선)
- 홈 대시보드에서 원하는 목록으로 즉시 이동
- 모바일 화면에서 텍스트 잘림/overflow 감소

### 반영 범위
- `lib/features/issuance/issuance_request_provider.dart`
- `lib/features/issuance/issuance_request_screen.dart`
- `lib/features/issuance/issuance_request_create_screen.dart`
- `lib/features/main/main_tab_screen.dart`
- `lib/features/home/home_hub_screen.dart`
- `lib/features/home/home_screen.dart`
- `lib/features/sales_calls/sales_call_list_screen.dart`
- `lib/features/sales_calls/sales_call_detail_screen.dart`
- `lib/core/constants/app_meta.dart`
- `pubspec.yaml`
- `ISSUANCE_REQUEST_TAB_PROMPT.md`

### 버전 정보
- 버전: `v1.4.0`
- 빌드 번호: `16`
- 커밋: `8710388`
- 배포 대상: Android (Flutter 앱)
