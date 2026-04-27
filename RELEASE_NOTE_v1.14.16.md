# 출시명

**COAD Customer Calls v1.14.16 - 견적/홈 UX 및 인증 안정화**

## 출시 노트

### 주요 변경 사항
- 앱 버전을 `1.14.16`으로 상향하고 Android 빌드 번호(`versionCode`)를 `31`로 반영했습니다.
- 견적기 단계 이동 UX를 개선하고 단계별 시각 구분을 강화했습니다.
- 홈 화면에 `오늘 미통화 담당자별`/`오늘 팔로우 담당자별` 현황을 추가해 담당자 단위 진입을 빠르게 했습니다.
- 푸시 진입 후 홈 데이터 갱신, 로그아웃 후 자동 재로그인, 권한 판정 이슈를 보완했습니다.

### 반영 범위
- `pubspec.yaml`
- `lib/core/constants/app_meta.dart`
- `lib/features/quoter/quoter_screen.dart`
- `lib/features/home/home_hub_screen.dart`
- `lib/features/home/home_providers.dart`
- `lib/features/main/main_tab_screen.dart`
- `lib/services/notification_service.dart`
- `lib/data/auth_repository.dart`
- `lib/core/utils/call_permissions.dart`

### 버전 정보
- 버전: `v1.14.16`
- 빌드 번호(versionCode): `31`
- 배포 대상: Android (Flutter 앱)
