# 출시명

**COAD Customer Calls v1.4.10 - 업데이트 검증 배포**

## 출시 노트

### 주요 변경 사항
- Play 업데이트 검증을 위해 앱 버전을 `1.4.10`으로 상향했습니다.
- Android 배포 빌드 번호(`versionCode`)를 `25`로 증가시켰습니다.
- 인앱 표시 버전(`kAppVersion`)과 `pubspec.yaml` 버전을 동기화했습니다.

### 반영 범위
- `pubspec.yaml`
- `lib/core/constants/app_meta.dart`

### 버전 정보
- 버전: `v1.4.10`
- 빌드 번호(versionCode): `25`
- 배포 대상: Android (Flutter 앱)

### 확인 목적
- 구버전(예: `1.4.9`) 설치 기기에서 앱 재실행 시 업데이트 감지 여부를 검증합니다.
