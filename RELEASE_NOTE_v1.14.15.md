# 출시명

**COAD Customer Calls v1.14.15 - 설정 화면 정리**

## 출시 노트

### 주요 변경 사항
- 앱 버전을 `1.14.15`로 상향했습니다.
- Android 배포 빌드 번호(`versionCode`)를 `30`으로 증가시켰습니다.
- 설정 화면에서 불필요한 `연결(BASE_URL)` 섹션을 제거해 `앱 버전`과 `업데이트 확인` 중심으로 단순화했습니다.

### 반영 범위
- `pubspec.yaml`
- `lib/core/constants/app_meta.dart`
- `lib/features/settings/settings_screen.dart`

### 버전 정보
- 버전: `v1.14.15`
- 빌드 번호(versionCode): `30`
- 배포 대상: Android (Flutter 앱)
