# 출시명

**COAD Customer Calls v1.14.18 - 재배포 빌드**

## 출시 노트

### 주요 변경 사항
- 앱 버전을 `1.14.18`로 상향했습니다.
- Android 배포 빌드 번호(`versionCode`)를 `33`으로 올려 새 배포 슬롯을 확보했습니다.
- 푸시 알림 탭 진입 시 내비게이터 지연 상황에서 payload가 유실되지 않도록 보완했습니다.
- 홈의 `오늘 팔로우` 담당자 선택 로딩 실패 시 사용자 안내를 추가하고, 집계 기준(상위 1000건)을 명시했습니다.

### 반영 범위
- `pubspec.yaml`
- `lib/core/constants/app_meta.dart`
- `lib/services/notification_service.dart`
- `lib/features/home/home_hub_screen.dart`

### 버전 정보
- 버전: `v1.14.18`
- 빌드 번호(versionCode): `33`
- 배포 대상: Android (Flutter 앱)
