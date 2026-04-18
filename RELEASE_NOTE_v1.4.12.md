# 출시명

**COAD Customer Calls v1.4.12 - 인앱 업데이트 재검증 배포**

## 출시 노트

### 주요 변경 사항
- 인앱 업데이트 재검증을 위해 앱 버전을 `1.4.12`로 상향했습니다.
- Android 배포 빌드 번호(`versionCode`)를 `27`로 증가시켰습니다.
- 인앱 표시 버전(`kAppVersion`)과 `pubspec.yaml` 버전을 동기화했습니다.

### 반영 범위
- `pubspec.yaml`
- `lib/core/constants/app_meta.dart`

### 버전 정보
- 버전: `v1.4.12`
- 빌드 번호(versionCode): `27`
- 배포 대상: Android (Flutter 앱)

### 테스트 목적
- 구버전(예: `1.4.11`) 단말에서 앱 실행 중 `설정 > 업데이트 확인` 탭으로 업데이트 감지/안내 동작을 검증합니다.
