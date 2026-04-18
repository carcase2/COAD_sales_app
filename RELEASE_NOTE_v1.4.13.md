# 출시명

**COAD Customer Calls v1.4.13 - 인앱 업데이트 재검증 2차**

## 출시 노트

### 주요 변경 사항
- 앱 버전을 `1.4.13`으로 상향했습니다.
- Android 배포 빌드 번호(`versionCode`)를 `28`로 증가시켰습니다.
- 인앱 업데이트 안내 푸시(`app_update`) 처리와 설정의 `업데이트 확인` 동작을 재검증할 수 있도록 배포 버전을 갱신했습니다.

### 반영 범위
- `pubspec.yaml`
- `lib/core/constants/app_meta.dart`
- `lib/services/notification_service.dart`
- `lib/services/app_update_service.dart`
- `supabase/functions/notify-app-update/index.ts`

### 버전 정보
- 버전: `v1.4.13`
- 빌드 번호(versionCode): `28`
- 배포 대상: Android (Flutter 앱)

### 테스트 목적
- 구버전 단말에서 `설정 > 업데이트 확인` 동작 재검증
- 업데이트 안내 푸시 탭 시 업데이트 흐름 진입 확인
