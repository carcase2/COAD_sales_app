# 출시명

**COAD Customer Calls v1.14.19 - 발급요청/상담이력 UX 및 알림 보강**

## 출시 노트

### 주요 변경 사항
- 앱 버전을 `1.14.19`로 상향했습니다.
- Android 배포 빌드 번호(`versionCode`)를 `34`로 올렸습니다.
- 발급요청 화면에서 대기/완료 상태 분리, 카드 가독성 및 필터 UX를 개선했습니다.
- 새 통화 등록 시 알림 경로를 보강해 푸시 전달 안정성을 높였습니다.
- 통화 상세의 상담이력 날짜 표기와 예정일 대비 계산 로직을 정교화했습니다.

### 반영 범위
- `pubspec.yaml`
- `lib/core/constants/app_meta.dart`
- `lib/features/issuance/issuance_request_provider.dart`
- `lib/features/issuance/issuance_request_screen.dart`
- `lib/features/main/main_tab_screen.dart`
- `lib/features/sales_calls/sales_call_create_screen.dart`
- `lib/features/sales_calls/sales_call_detail_screen.dart`
- `lib/services/notification_service.dart`

### 버전 정보
- 버전: `v1.14.19`
- 빌드 번호(versionCode): `34`
- 배포 대상: Android (Flutter 앱)
