# 출시명

**COAD Customer Calls v1.4.9 - 알림 딥링크·배포**

## 출시 노트

### 주요 개선 사항
- 푸시 알림을 탭했을 때 **해당 접수의 통화 상세 화면**으로 이동하도록 FCM 처리를 정리했습니다. (`getInitialMessage`를 초기화 시점에 읽고, 로그인 후 메인에서 소비)
- `call_id` 등 데이터 키를 정규화하고, 네비게이터 준비까지 재시도합니다.
- 앱 버전을 **`1.4.9`**로 올리고 빌드 번호를 **`23`**으로 맞췄습니다. (`kAppVersion` / `pubspec.yaml` 동기화)

### 사용자 체감 효과
- 새 접수 알림을 눌렀을 때 미통화 목록 등이 아니라 **해당 건 상세**로 바로 들어갈 수 있습니다.

### 반영 범위
- `lib/services/notification_service.dart`
- `lib/core/constants/app_meta.dart`
- `pubspec.yaml`

### 버전 정보
- 버전: `v1.4.9`
- 빌드 번호(versionCode): `24` (Play는 한 번 쓴 번호를 재사용할 수 없어, 재업로드 시마다 +1)
- 주요 커밋:
  - `0022cba` (`Release v1.4.9: 알림 탭 시 통화 상세로 이동하도록 FCM 처리 개선`)
- 배포 대상: Android (Flutter 앱)

---

## 업데이트가 스토어/앱에 안 보일 때 (운영 체크)

1. **Play Console**  
   새 `app-release.aab`를 **프로덕션(또는 테스트 트랙)**에 올리고 **출시가 완료**되어야 기기의 Play 스토어에 새 버전이 노출됩니다. 심사·단계적 출시 중이면 사용자에게는 아직 안 보일 수 있습니다.

2. **인앱 업데이트(`in_app_update`)**  
   Google Play API는 **스토어에 동일 서명의 새 버전이 배포된 뒤**에야 `updateAvailable`을 반환하는 경우가 많습니다. 배포 직후에는 캐시 때문에 몇 시간 걸릴 수 있습니다.

3. **Supabase `app_update_policy`** (선택 업데이트 안내 다이얼로그)  
   앱은 `app_update_policy`의 `latest_version`·`min_version`과 `kAppVersion`을 비교합니다. 인앱에서 “업데이트 권장”을 띄우려면 DB에 **최신 행**의 `latest_version`을 **`1.4.9`**(또는 그 이상)로 맞춰 주세요. 행이 없거나 버전 문자열이 비어 있으면 정책 기반 다이얼로그는 나오지 않을 수 있습니다.
