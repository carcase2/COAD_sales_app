# 출시명

**COAD Customer Calls v1.4.11 - 인앱 업데이트 확인 개선**

## 출시 노트

### 주요 변경 사항
- 설정 화면에 `업데이트 확인` 항목을 추가했습니다.
- 최신 버전일 때도 `최신 버전(v1.4.11)입니다.` 안내를 표시하도록 업데이트 체크 로직을 개선했습니다.
- 앱 버전을 `1.4.11`로 상향하고 Android 배포 빌드 번호(`versionCode`)를 `26`으로 증가시켰습니다.

### 반영 범위
- `lib/services/app_update_service.dart`
- `lib/features/settings/settings_screen.dart`
- `lib/core/constants/app_meta.dart`
- `pubspec.yaml`

### 버전 정보
- 버전: `v1.4.11`
- 빌드 번호(versionCode): `26`
- 배포 대상: Android (Flutter 앱)

### 테스트 포인트
- 앱 실행 중 `설정 > 업데이트 확인` 탭 시 최신 여부 메시지 노출 확인
- 구버전 설치 기기에서 신규 버전 배포 후 인앱 업데이트 감지 확인
